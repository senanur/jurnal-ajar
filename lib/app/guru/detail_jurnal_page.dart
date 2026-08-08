import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/guru/guru_activity.dart';
import 'package:jurnal_mengajar/app/guru/guru_widgets.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only "Detail Jurnal" screen for an approved journal
/// (design/prompt/019_detail_jurnal.md §2.1): photo gallery, materi, catatan,
/// attendance recap, and the per-student absence list with a WA-status
/// placeholder.
class DetailJurnalPage extends StatefulWidget {
  const DetailJurnalPage({super.key, required this.jurnalId});

  final int jurnalId;

  @override
  State<DetailJurnalPage> createState() => _DetailJurnalPageState();
}

class _AbsenEntry {
  _AbsenEntry({required this.nama, required this.word, required this.color});
  final String nama;
  final String word; // Sakit / Izin / Alpha
  final Color color;
}

class _DetailJurnalPageState extends State<DetailJurnalPage> {
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLoading = true;

  String _guruNama = '';
  String _kelas = '-';
  String _mapel = '-';
  String _tanggalLabel = '';
  String _timeRange = '-';
  String _materi = '';
  String _catatan = '';
  List<String> _photoUrls = [];

  int _sakit = 0;
  int _izin = 0;
  int _alpha = 0;
  final List<_AbsenEntry> _absenList = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await _supabase
          .from('jurnal_harian')
          .select(
            'materi, catatan, tanggal, '
            'jadwal_mengajar(guru_id, kelas_id, mata_pelajaran_id, jam_ids, '
            'profiles(nama_lengkap), '
            'master_kelas(nama_kelas), '
            'master_mata_pelajaran(nama_mata_pelajaran))',
          )
          .eq('id', widget.jurnalId)
          .single();

      final jadwal = row['jadwal_mengajar'] as Map<String, dynamic>?;
      final profile = jadwal?['profiles'] as Map<String, dynamic>?;
      final kelas = jadwal?['master_kelas'] as Map<String, dynamic>?;
      final mapel = jadwal?['master_mata_pelajaran'] as Map<String, dynamic>?;

      final namaGuru = (profile?['nama_lengkap'] as String?)?.trim();
      _guruNama = (namaGuru == null || namaGuru.isEmpty) ? 'Guru' : namaGuru;
      _kelas = (kelas?['nama_kelas'] as String?) ?? '-';
      _mapel = (mapel?['nama_mata_pelajaran'] as String?) ?? '-';
      _materi = (row['materi'] as String?) ?? '';
      _catatan = (row['catatan'] as String?) ?? '';

      final tanggalRaw = row['tanggal'];
      final tanggal = tanggalRaw is DateTime
          ? tanggalRaw
          : DateTime.tryParse((tanggalRaw as String?) ?? '');
      if (tanggal != null) _tanggalLabel = formatDateLong(tanggal);

      // Time range from the jadwal's jam_ids -> master_jam.
      final jamIds = <int>[];
      final jamRaw = jadwal?['jam_ids'];
      if (jamRaw is List) {
        for (final v in jamRaw) {
          final p = asInt(v);
          if (p != null) jamIds.add(p);
        }
      }
      if (jamIds.isNotEmpty) {
        final jamRows = await _supabase
            .from('master_jam')
            .select('jam_ke, waktu_reguler')
            .inFilter('jam_ke', jamIds) as List;
        final jamInfo = jamRows.map((r) {
          final m = r as Map<String, dynamic>;
          return JamInfo(jamKe: asInt(m['jam_ke']) ?? 0, waktu: (m['waktu_reguler'] as String?) ?? '');
        }).toList();
        _timeRange = timeRangeFromJam(jamInfo);
      }

      _photoUrls = await loadJurnalFotoUrls(_supabase, widget.jurnalId);

      final presensiRows = await _supabase
          .from('presensi_siswa')
          .select('status, master_siswa(nama_siswa)')
          .eq('jurnal_id', widget.jurnalId) as List;
      for (final r in presensiRows) {
        final p = r as Map<String, dynamic>;
        final raw = ((p['status'] as String?) ?? '').toLowerCase();
        final siswa = p['master_siswa'] as Map<String, dynamic>?;
        final nama = (siswa?['nama_siswa'] as String?) ?? 'Siswa';

        String? word;
        Color? color;
        if (raw.contains('sakit')) {
          word = 'Sakit';
          color = Colors.orange.shade600;
          _sakit++;
        } else if (raw.contains('izin')) {
          word = 'Izin';
          color = MainColor.secondaryColor;
          _izin++;
        } else if (raw.contains('alpha') || raw.contains('alfa')) {
          word = 'Alpha';
          color = Colors.red.shade400;
          _alpha++;
        }
        if (word == null || color == null) continue;
        _absenList.add(_AbsenEntry(nama: nama, word: word, color: color));
      }
    } catch (error) {
      showMasterDataError('Gagal memuat detail jurnal', error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(title: 'Detail Jurnal', onBack: () => Get.back()),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ApprovedBanner(),
                    const SizedBox(height: 20),
                    JurnalFotoGallery(urls: _photoUrls),
                    const SizedBox(height: 20),
                    Text(
                      _guruNama,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_kelas | $_mapel',
                      style: TextStyle(
                        fontSize: 13,
                        color: MainColor.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DateTimeRow(tanggal: _tanggalLabel, waktu: _timeRange),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    _label('Materi Pembelajaran:'),
                    _value(_materi.isEmpty ? '-' : _materi),
                    const SizedBox(height: 14),
                    _label('Catatan Guru:'),
                    _value(_catatan.isEmpty ? '-' : _catatan),
                    const SizedBox(height: 18),
                    _RekapAbsensi(sakit: _sakit, izin: _izin, alpha: _alpha),
                    const SizedBox(height: 18),
                    _label('Daftar Siswa Tidak Hadir:'),
                    const SizedBox(height: 8),
                    if (_absenList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Semua siswa hadir.',
                            style: TextStyle(fontSize: 13, color: Colors.black45)),
                      )
                    else
                      for (final a in _absenList) _AbsenCard(entry: a),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87));

  Widget _value(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: const TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.4)),
      );
}

class _ApprovedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Sudah diverifikasi oleh Admin',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({required this.tanggal, required this.waktu});

  final String tanggal;
  final String waktu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 16, color: MainColor.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(tanggal,
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: MainColor.primaryColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(waktu,
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RekapAbsensi extends StatelessWidget {
  const _RekapAbsensi({required this.sakit, required this.izin, required this.alpha});

  final int sakit;
  final int izin;
  final int alpha;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rekap Absensi (S, I, A)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
        const SizedBox(height: 10),
        Row(
          children: [
            _Pill(label: 'Sakit: $sakit', color: Colors.orange.shade600),
            const SizedBox(width: 8),
            _Pill(label: 'Izin: $izin', color: MainColor.secondaryColor),
            const SizedBox(width: 8),
            _Pill(label: 'Alpha: $alpha', color: Colors.red.shade400),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }
}

class _AbsenCard extends StatelessWidget {
  const _AbsenCard({required this.entry});

  final _AbsenEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(entry.nama,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              Text(
                entry.word,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: entry.color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Notifikasi Orang Tua:',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black45)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.cancel_outlined, size: 15, color: Colors.black38),
              const SizedBox(width: 4),
              const Text('WA Tidak Terkirim',
                  style:
                      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }
}
