import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A single master_jam entry: `jam_ke` (1..10) plus its `waktu_reguler`.
class JamInfo {
  JamInfo({required this.jamKe, required this.waktu});
  final int jamKe;
  final String waktu;
}

/// A guru's jadwal_mengajar row effective on a given date, plus the resolved
/// state of any journal covering it (needed to render the detail popup from
/// either the Jadwal or Jurnal listview).
class GuruJadwalItem {
  GuruJadwalItem({
    required this.id,
    required this.timeRange,
    required this.jamKeList,
    required this.kelas,
    required this.kelasId,
    required this.pelajaran,
    required this.tanggal,
    required this.sudahDiisi,
    this.jurnalStatus,
    this.jurnalId,
  });

  final int id;
  final String timeRange;
  final List<int> jamKeList;
  final String kelas;
  final int kelasId;
  final String pelajaran;

  /// The date this jadwal is effective on (the selected date being viewed).
  final DateTime tanggal;

  /// True if *any* jurnal_harian row references this jadwal for the date.
  final bool sudahDiisi;

  /// Status of the journal covering this jadwal (pending/approved/rejected),
  /// or null if there is none yet.
  final String? jurnalStatus;

  /// Id of that covering journal row, if any.
  final int? jurnalId;
}

/// One jurnal_harian row belonging to the guru, along with the parent jadwal's
/// info it renders alongside (and the jadwal id it chains back to).
class GuruJurnalItem {
  GuruJurnalItem({
    required this.jurnalId,
    required this.jadwalId,
    required this.kelas,
    required this.pelajaran,
    required this.status,
    required this.sakit,
    required this.izin,
    required this.alpha,
  });

  final int jurnalId;
  final int jadwalId;
  final String kelas;
  final String pelajaran;
  final String status;
  final int sakit;
  final int izin;
  final int alpha;

  GuruJurnalItem copyWith({int? sakit, int? izin, int? alpha}) => GuruJurnalItem(
      jurnalId: jurnalId,
      jadwalId: jadwalId,
      kelas: kelas,
      pelajaran: pelajaran,
      status: status,
      sakit: sakit ?? this.sakit,
      izin: izin ?? this.izin,
      alpha: alpha ?? this.alpha,
    );
}

/// Result of [loadGuruActivity]: the jadwal/jurnal lists plus a by-id lookup
/// over the jadwal list (used to render the shared detail popup from either
/// listview).
class GuruActivity {
  GuruActivity({
    required this.jadwalList,
    required this.jurnalList,
    required this.jadwalById,
  });

  final List<GuruJadwalItem> jadwalList;
  final List<GuruJurnalItem> jurnalList;
  final Map<int, GuruJadwalItem> jadwalById;
}

/// First jam's start time to last jam's end time, e.g. "07.15-08.45".
String timeRangeFromJam(List<JamInfo> jamInfos) {
  if (jamInfos.isEmpty) return '-';
  final sorted = [...jamInfos]..sort((a, b) => a.jamKe.compareTo(b.jamKe));
  final start = sorted.first.waktu.split('-').first.trim();
  final end = sorted.last.waktu.split('-').last.trim();
  return '$start-$end';
}

/// Fetches one guru's own jadwal + jurnal activity for `date`. Shared by the
/// admin's GuruDetailController and the guru's own Dashboard, scoped to the
/// same `guruId` each time (admin passes the picked guru, dashboard passes
/// `auth.currentUser.id`).
Future<GuruActivity> loadGuruActivity({
  required SupabaseClient supabase,
  required String guruId,
  required DateTime date,
}) async {
  final dateStr = formatDateIso(date);
  final weekday = date.weekday;

  final periode = await supabase
      .from('master_periode')
      .select('id')
      .eq('is_active', true)
      .maybeSingle();
  final periodeId = asInt(periode?['id']);

  var jadwalQuery = supabase
      .from('jadwal_mengajar')
      .select('id, kelas_id, mata_pelajaran_id, jam_ids')
      .eq('guru_id', guruId)
      .eq('is_active', true)
      .or('and(tanggal.is.null,hari.eq.$weekday),tanggal.eq.$dateStr');
  if (periodeId != null) {
    jadwalQuery = jadwalQuery.eq('periode_id', periodeId);
  }
  final jadwalRows = await jadwalQuery as List;

  final kelasIds = <int>{};
  final mapelIds = <int>{};
  final jamIds = <int>{};
  for (final r in jadwalRows) {
    final row = r as Map<String, dynamic>;
    final k = asInt(row['kelas_id']);
    if (k != null) kelasIds.add(k);
    final m = asInt(row['mata_pelajaran_id']);
    if (m != null) mapelIds.add(m);
    final ji = row['jam_ids'];
    if (ji is List) {
      for (final v in ji) {
        final p = asInt(v);
        if (p != null) jamIds.add(p);
      }
    }
  }

  final kelasMap = <int, String>{};
  if (kelasIds.isNotEmpty) {
    final rows = await supabase
        .from('master_kelas')
        .select('id, nama_kelas')
        .inFilter('id', kelasIds.toList()) as List;
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      kelasMap[asInt(row['id'])!] = (row['nama_kelas'] as String?) ?? '-';
    }
  }

  final mapelMap = <int, String>{};
  if (mapelIds.isNotEmpty) {
    final rows = await supabase
        .from('master_mata_pelajaran')
        .select('id, nama_mata_pelajaran')
        .inFilter('id', mapelIds.toList()) as List;
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      mapelMap[asInt(row['id'])!] = (row['nama_mata_pelajaran'] as String?) ?? '-';
    }
  }

  // jadwal_mengajar.jam_ids stores master_jam.jam_ke (1..10), not master_jam.id.
  final jamMap = <int, JamInfo>{};
  if (jamIds.isNotEmpty) {
    final rows = await supabase
        .from('master_jam')
        .select('jam_ke, waktu_reguler')
        .inFilter('jam_ke', jamIds.toList()) as List;
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      final jamKe = asInt(row['jam_ke']);
      if (jamKe == null) continue;
      jamMap[jamKe] = JamInfo(
        jamKe: jamKe,
        waktu: (row['waktu_reguler'] as String?) ?? '',
      );
    }
  }

  final jurnalRows = await supabase
      .from('jurnal_harian')
      .select('id, jadwal_id, jadwal_ids, status')
      .eq('tanggal', dateStr) as List;

  // Map each covered jadwal id to the first journal that covers it.
  final jurnalByJadwal = <int, ({int jurnalId, String status})>{};
  for (final r in jurnalRows) {
    final row = r as Map<String, dynamic>;
    final jid = asInt(row['id']);
    if (jid == null) continue;
    final status = (row['status'] as String?) ?? 'pending';
    final covered = <int>{};
    final primary = asInt(row['jadwal_id']);
    if (primary != null) covered.add(primary);
    final arr = row['jadwal_ids'];
    if (arr is List) {
      for (final v in arr) {
        final p = asInt(v);
        if (p != null) covered.add(p);
      }
    }
    for (final id in covered) {
      jurnalByJadwal.putIfAbsent(id, () => (jurnalId: jid, status: status));
    }
  }

  final jadwalItems = <GuruJadwalItem>[];
  for (final r in jadwalRows) {
    final row = r as Map<String, dynamic>;
    final id = asInt(row['id']);
    if (id == null) continue;
    final kelasId = asInt(row['kelas_id']);
    final mapelId = asInt(row['mata_pelajaran_id']);
    final jiRaw = row['jam_ids'];
    final ids = <int>[];
    if (jiRaw is List) {
      for (final v in jiRaw) {
        final p = asInt(v);
        if (p != null) ids.add(p);
      }
    }
    final jamInfos = ids.map((i) => jamMap[i]).whereType<JamInfo>().toList();
    final ref = jurnalByJadwal[id];
    jadwalItems.add(GuruJadwalItem(
      id: id,
      timeRange: timeRangeFromJam(jamInfos),
      jamKeList: ids..sort(),
      kelas: kelasMap[kelasId] ?? '-',
      kelasId: kelasId ?? 0,
      pelajaran: mapelMap[mapelId] ?? '-',
      tanggal: date,
      sudahDiisi: ref != null,
      jurnalStatus: ref?.status,
      jurnalId: ref?.jurnalId,
    ));
  }
  jadwalItems.sort((a, b) => a.timeRange.compareTo(b.timeRange));
  final jadwalById = {for (final j in jadwalItems) j.id: j};

  final seenJurnal = <int>{};
  final jurnalItems = <GuruJurnalItem>[];
  for (final r in jurnalRows) {
    final row = r as Map<String, dynamic>;
    final jid = asInt(row['id']);
    if (jid == null || seenJurnal.contains(jid)) continue;

    final coveredIds = <int>{};
    final primary = asInt(row['jadwal_id']);
    if (primary != null) coveredIds.add(primary);
    final arr = row['jadwal_ids'];
    if (arr is List) {
      for (final v in arr) {
        final p = asInt(v);
        if (p != null) coveredIds.add(p);
      }
    }

    GuruJadwalItem? matched;
    for (final id in coveredIds) {
      final candidate = jadwalById[id];
      if (candidate != null) {
        matched = candidate;
        break;
      }
    }
    if (matched == null) continue; // not this guru's journal entry

    seenJurnal.add(jid);
    jurnalItems.add(GuruJurnalItem(
      jurnalId: jid,
      jadwalId: matched.id,
      kelas: matched.kelas,
      pelajaran: matched.pelajaran,
      status: (row['status'] as String?) ?? 'pending',
      sakit: 0,
      izin: 0,
      alpha: 0,
    ));
  }

  if (jurnalItems.isNotEmpty) {
    final jids = jurnalItems.map((e) => e.jurnalId).toList();
    final presensiRows = await supabase
        .from('presensi_siswa')
        .select('jurnal_id, status')
        .inFilter('jurnal_id', jids) as List;
    final counts = <int, Map<String, int>>{};
    for (final r in presensiRows) {
      final row = r as Map<String, dynamic>;
      final jid = asInt(row['jurnal_id']);
      if (jid == null) continue;
      final status = ((row['status'] as String?) ?? '').toLowerCase();
      final bucket = counts.putIfAbsent(jid, () => {'s': 0, 'i': 0, 'a': 0});
      if (status.startsWith('sakit')) {
        bucket['s'] = bucket['s']! + 1;
      } else if (status.startsWith('izin')) {
        bucket['i'] = bucket['i']! + 1;
      } else if (status.startsWith('alpha') || status.startsWith('alfa')) {
        bucket['a'] = bucket['a']! + 1;
      }
    }
    for (var i = 0; i < jurnalItems.length; i++) {
      final c = counts[jurnalItems[i].jurnalId];
      if (c != null) {
        jurnalItems[i] =
            jurnalItems[i].copyWith(sakit: c['s'], izin: c['i'], alpha: c['a']);
      }
    }
  }

  return GuruActivity(
    jadwalList: jadwalItems,
    jurnalList: jurnalItems,
    jadwalById: jadwalById,
  );
}
