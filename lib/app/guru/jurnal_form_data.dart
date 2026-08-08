import 'dart:typed_data';

import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A student in the jadwal's roster (from `master_siswa`, filtered by the
/// jadwal's `kelas_id`), used to render the per-student H/S/I/A picker.
class SiswaItem {
  SiswaItem({required this.id, required this.nama});
  final int id;
  final String nama;
}

/// A photo attached to the journal. Either newly captured (holds [bytes], to
/// be uploaded on save) or an already-saved row being kept (holds [dbId] and
/// [url], untouched on save).
class JurnalPhotoDraft {
  JurnalPhotoDraft._({this.bytes, this.dbId, this.url});

  factory JurnalPhotoDraft.fromBytes(Uint8List bytes) =>
      JurnalPhotoDraft._(bytes: bytes);

  factory JurnalPhotoDraft.fromExisting({required int id, required String url}) =>
      JurnalPhotoDraft._(dbId: id, url: url);

  final Uint8List? bytes;
  final int? dbId;
  final String? url;

  bool get isNew => bytes != null;
}

/// The pre-filled state of an existing (pending/rejected) jurnal being edited.
class JurnalDraft {
  JurnalDraft({
    required this.materi,
    required this.catatan,
    required this.status,
    this.catatanAdmin,
    required this.absensi,
    required this.photos,
  });

  final String materi;
  final String catatan;
  final String status;
  final String? catatanAdmin;

  /// siswaId -> one of 'H'/'S'/'I'/'A'.
  final Map<int, String> absensi;

  final List<JurnalPhotoDraft> photos;
}

/// Reads the attendance roster for [kelasId].
Future<List<SiswaItem>> loadKelasSiswa(SupabaseClient supabase, int kelasId) async {
  final rows = await supabase
      .from('master_siswa')
      .select('id, nama_siswa')
      .eq('kelas_id', kelasId)
      .order('nama_siswa') as List;
  return rows
      .map((r) {
        final row = r as Map<String, dynamic>;
        return SiswaItem(
          id: asInt(row['id']) ?? 0,
          nama: (row['nama_siswa'] as String?)?.trim().isNotEmpty == true
              ? row['nama_siswa'] as String
              : 'Siswa',
        );
      })
      .toList();
}

/// Loads an existing jurnal's saved state to pre-fill the edit form.
Future<JurnalDraft> loadExistingJurnal(SupabaseClient supabase, int jurnalId) async {
  final row = await supabase
      .from('jurnal_harian')
      .select('materi, catatan, status, catatan_admin')
      .eq('id', jurnalId)
      .single();

  final absensi = <int, String>{};
  final presensiRows = await supabase
      .from('presensi_siswa')
      .select('siswa_id, status')
      .eq('jurnal_id', jurnalId) as List;
  for (final r in presensiRows) {
    final p = r as Map<String, dynamic>;
    final sid = asInt(p['siswa_id']);
    if (sid == null) continue;
    final raw = ((p['status'] as String?) ?? '').toLowerCase();
    if (raw.contains('sakit')) {
      absensi[sid] = 'S';
    } else if (raw.contains('izin')) {
      absensi[sid] = 'I';
    } else if (raw.contains('alpha') || raw.contains('alfa')) {
      absensi[sid] = 'A';
    }
  }

  final fotoRows = await supabase
      .from('jurnal_foto')
      .select('id, url')
      .eq('jurnal_id', jurnalId) as List;
  final photos = fotoRows.map((r) {
    final f = r as Map<String, dynamic>;
    return JurnalPhotoDraft.fromExisting(
      id: asInt(f['id']) ?? 0,
      url: (f['url'] as String?) ?? '',
    );
  }).toList();

  return JurnalDraft(
    materi: (row['materi'] as String?) ?? '',
    catatan: (row['catatan'] as String?) ?? '',
    status: (row['status'] as String?) ?? 'pending',
    catatanAdmin: row['catatan_admin'] as String?,
    absensi: absensi,
    photos: photos,
  );
}

/// Resolves the journal deadline (days) from `pengaturan_aplikasi`
/// (`batas_input_jurnal`, default 3).
Future<int> _batasInputJurnal(SupabaseClient supabase) async {
  final settings = await supabase
      .from('pengaturan_aplikasi')
      .select('batas_input_jurnal')
      .eq('id', 1)
      .maybeSingle();
  return asInt(settings?['batas_input_jurnal']) ?? 3;
}

/// Writes the journal (INSERT for a fresh entry, UPDATE+reset for an edit),
/// uploading new photos and reconciling presensi/jurnal_foto rows.
///
/// [nonHadir] carries each absent student as `(siswaId, status)` where status
/// is one of 'Sakit'/'Izin'/'Alpha' (words, matching the read-side prefix rule).
Future<void> submitJurnal({
  required SupabaseClient supabase,
  required bool isEdit,
  required int jadwalId,
  required DateTime tanggal,
  required int kelasId,
  required String materi,
  required String catatan,
  required List<(int, String)> nonHadir,
  required List<Uint8List> newPhotoBytes,
  required List<int> keptPhotoIds,
  required List<int> removedPhotoIds,
  int? jurnalId,
}) async {
  // §4.5: is_telat is a soft flag only — never blocks submission.
  final batas = await _batasInputJurnal(supabase);
  final isTelat = DateTime.now().difference(tanggal).inDays > batas;

  final tanggalStr = formatDateIso(tanggal);

  int resolvedJurnalId;
  if (isEdit) {
    resolvedJurnalId = jurnalId!;
    await supabase.from('jurnal_harian').update({
      'tanggal': tanggalStr,
      'materi': materi,
      'catatan': catatan,
      'status': 'pending',
      'catatan_admin': null,
      'validated_at': null,
      'validated_by': null,
      'is_telat': isTelat,
    }).eq('id', resolvedJurnalId);
  } else {
    final inserted = await supabase
        .from('jurnal_harian')
        .insert({
          'jadwal_id': jadwalId,
          'tanggal': tanggalStr,
          'materi': materi,
          'catatan': catatan,
          'status': 'pending',
          'is_telat': isTelat,
        })
        .select() as List;
    resolvedJurnalId = asInt(inserted.first['id'])!;
  }

  // Presensi: delete all existing rows for this jurnal, then re-insert the
  // current non-hadir set (simplest correct reconciliation).
  await supabase.from('presensi_siswa').delete().eq('jurnal_id', resolvedJurnalId);
  if (nonHadir.isNotEmpty) {
    await supabase.from('presensi_siswa').insert([
      for (final (sid, status) in nonHadir) {
        'jurnal_id': resolvedJurnalId,
        'siswa_id': sid,
        'status': status,
        'kelas_id': kelasId,
      },
    ]);
  }

  // Jurnal foto: delete explicitly-removed rows, keep untouched ones, upload
  // and insert newly captured photos.
  if (removedPhotoIds.isNotEmpty) {
    await supabase
        .from('jurnal_foto')
        .delete()
        .eq('jurnal_id', resolvedJurnalId)
        .inFilter('id', removedPhotoIds);
  }
  for (var i = 0; i < newPhotoBytes.length; i++) {
    final bytes = newPhotoBytes[i];
    final path = '$resolvedJurnalId/${DateTime.now().microsecondsSinceEpoch}-$i.jpg';
    await supabase.storage.from('foto').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    final url = supabase.storage.from('foto').getPublicUrl(path);
    await supabase.from('jurnal_foto').insert({'jurnal_id': resolvedJurnalId, 'url': url});
  }
}
