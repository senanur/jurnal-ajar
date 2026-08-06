import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/masterdata/siswa_page.dart' show KelasOption;
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:jurnal_mengajar/app/widgets/week_date_strip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PelajaranOption {
  PelajaranOption({required this.id, required this.nama});
  final int id;
  final String nama;
}

class GuruOption {
  GuruOption({required this.id, required this.nama, required this.jabatan});
  final String id;
  final String nama;
  final String jabatan;
}

class JadwalListItem {
  JadwalListItem({
    required this.id,
    required this.guruId,
    required this.guruNama,
    required this.guruFoto,
    required this.mapelId,
    required this.mapelNama,
    required this.kelasId,
    required this.kelasNama,
    required this.jamKeList,
    required this.timeRange,
    required this.sudahDiisiJurnal,
  });

  final int id;
  final String guruId;
  final String guruNama;
  final String guruFoto;
  final int mapelId;
  final String mapelNama;
  final int kelasId;
  final String kelasNama;
  final List<int> jamKeList;
  final String timeRange;
  final bool sudahDiisiJurnal;
}

class JadwalListController extends GetxController {
  SupabaseClient get _supabase => Supabase.instance.client;

  final Rx<DateTime> selectedDate = dateOnly(DateTime.now()).obs;
  final RxInt weekDirection = 0.obs;
  final RxBool isLoading = true.obs;
  final RxList<JadwalListItem> items = <JadwalListItem>[].obs;
  final TextEditingController searchController = TextEditingController();
  final RxString query = ''.obs;

  final Map<int, String> _jamWaktu = {};

  List<DateTime> get weekDays => weekDaysFor(selectedDate.value);

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() => query.value = searchController.text);
    _loadJamWaktu().then((_) => fetchItems());
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  List<JadwalListItem> get filtered {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) {
      final haystack =
          '${e.guruNama} ${e.mapelNama} ${e.kelasNama} jam ${e.jamKeList.join(" ")}'
              .toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  void previousWeek() {
    weekDirection.value = -1;
    selectedDate.value = selectedDate.value.subtract(const Duration(days: 7));
    fetchItems();
  }

  void nextWeek() {
    weekDirection.value = 1;
    selectedDate.value = selectedDate.value.add(const Duration(days: 7));
    fetchItems();
  }

  void selectDate(DateTime date) {
    if (isSameDay(date, selectedDate.value)) return;
    selectedDate.value = date;
    fetchItems();
  }

  Future<void> _loadJamWaktu() async {
    try {
      final rows =
          await _supabase.from('master_jam').select('jam_ke, waktu_reguler') as List;
      for (final r in rows) {
        final row = r as Map<String, dynamic>;
        final jamKe = asInt(row['jam_ke']);
        if (jamKe != null) {
          _jamWaktu[jamKe] = (row['waktu_reguler'] as String?) ?? '';
        }
      }
    } catch (_) {
      // Falls back to '-' time ranges below; not worth blocking the list.
    }
  }

  String _timeRangeFor(List<int> jamKeList) {
    if (jamKeList.isEmpty) return '-';
    final start = _jamWaktu[jamKeList.first]?.split('-').first.trim();
    final end = _jamWaktu[jamKeList.last]?.split('-').last.trim();
    if (start == null || end == null || start.isEmpty || end.isEmpty) return '-';
    return '$start-$end';
  }

  Future<void> fetchItems() async {
    isLoading.value = true;
    final date = selectedDate.value;
    final dateStr = formatDateIso(date);
    final weekday = date.weekday;

    try {
      final periode = await _supabase
          .from('master_periode')
          .select('id')
          .eq('is_active', true)
          .maybeSingle();
      final periodeId = asInt(periode?['id']);

      var q = _supabase
          .from('jadwal_mengajar')
          .select(
            'id, guru_id, kelas_id, mata_pelajaran_id, jam_ids, '
            'profiles(nama_lengkap, foto_url), '
            'master_kelas(nama_kelas), '
            'master_mata_pelajaran(nama_mata_pelajaran)',
          )
          .eq('is_active', true)
          .or('and(tanggal.is.null,hari.eq.$weekday),tanggal.eq.$dateStr');
      if (periodeId != null) {
        q = q.eq('periode_id', periodeId);
      }
      final rows = await q as List;

      final jurnalRows = await _supabase
          .from('jurnal_harian')
          .select('jadwal_id, jadwal_ids')
          .eq('tanggal', dateStr) as List;
      final answered = <int>{};
      for (final r in jurnalRows) {
        final row = r as Map<String, dynamic>;
        final jid = asInt(row['jadwal_id']);
        if (jid != null) answered.add(jid);
        final arr = row['jadwal_ids'];
        if (arr is List) {
          for (final v in arr) {
            final p = asInt(v);
            if (p != null) answered.add(p);
          }
        }
      }

      final list = <JadwalListItem>[];
      for (final r in rows) {
        final row = r as Map<String, dynamic>;
        final id = asInt(row['id']);
        if (id == null) continue;
        final profile = row['profiles'] as Map<String, dynamic>?;
        final kelas = row['master_kelas'] as Map<String, dynamic>?;
        final mapel = row['master_mata_pelajaran'] as Map<String, dynamic>?;
        final jamRaw = row['jam_ids'];
        final jamList = <int>[];
        if (jamRaw is List) {
          for (final v in jamRaw) {
            final p = asInt(v);
            if (p != null) jamList.add(p);
          }
        }
        jamList.sort();

        final namaGuru = (profile?['nama_lengkap'] as String?)?.trim();
        list.add(JadwalListItem(
          id: id,
          guruId: row['guru_id'] as String? ?? '',
          guruNama: (namaGuru == null || namaGuru.isEmpty) ? 'Guru' : namaGuru,
          guruFoto: (profile?['foto_url'] as String?) ?? '',
          mapelId: asInt(row['mata_pelajaran_id']) ?? 0,
          mapelNama: (mapel?['nama_mata_pelajaran'] as String?) ?? '-',
          kelasId: asInt(row['kelas_id']) ?? 0,
          kelasNama: (kelas?['nama_kelas'] as String?) ?? '-',
          jamKeList: jamList,
          timeRange: _timeRangeFor(jamList),
          sudahDiisiJurnal: answered.contains(id),
        ));
      }

      list.sort((a, b) {
        final aj = a.jamKeList.isEmpty ? 999 : a.jamKeList.first;
        final bj = b.jamKeList.isEmpty ? 999 : b.jamKeList.first;
        final cmp = aj.compareTo(bj);
        if (cmp != 0) return cmp;
        return a.guruNama.compareTo(b.guruNama);
      });

      items.value = list;
    } catch (error) {
      showMasterDataError('Gagal memuat jadwal mengajar', error);
    } finally {
      isLoading.value = false;
    }
  }
}

class JadwalListPage extends StatefulWidget {
  const JadwalListPage({super.key});

  @override
  State<JadwalListPage> createState() => _JadwalListPageState();
}

class _JadwalListPageState extends State<JadwalListPage> {
  final JadwalListController controller = Get.put(JadwalListController());

  Future<void> _openForm({int? jadwalId}) async {
    final changed = await Get.to<bool>(
      () => JadwalFormPage(jadwalId: jadwalId, initialDate: controller.selectedDate.value),
    );
    if (changed == true) controller.fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: 'Jadwal Mengajar',
        onBack: () => Get.offAllNamed(Routes.dashboardAdmin),
        onAdd: () => _openForm(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Obx(
                () => WeekDateStrip(
                  weekDays: controller.weekDays,
                  selectedDate: controller.selectedDate.value,
                  weekDirection: controller.weekDirection.value,
                  onPrevious: controller.previousWeek,
                  onNext: controller.nextWeek,
                  onSelectDate: controller.selectDate,
                ),
              ),
              const SizedBox(height: 16),
              MasterDataSearchField(
                controller: controller.searchController,
                hint: 'Cari Guru, Mapel, Kelas atau Jam',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = controller.filtered;
                  if (list.isEmpty) {
                    return const MasterDataEmptyState(
                      message: 'Tidak ada jadwal mengajar pada tanggal ini.',
                    );
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return MasterDataEntrance(
                        delay: Duration(milliseconds: 30 * index),
                        child: _JadwalTile(
                          item: item,
                          onTap: () => _openForm(jadwalId: item.id),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JadwalTile extends StatelessWidget {
  const _JadwalTile({required this.item, required this.onTap});

  final JadwalListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = !item.sudahDiisiJurnal;
    final bg = filled ? MainColor.primaryColor : MainColor.fourthColor.withValues(alpha: 0.5);
    final fg = filled ? Colors.white : MainColor.primaryColor;
    final fgSub = filled
        ? Colors.white.withValues(alpha: 0.85)
        : MainColor.primaryColor.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniAvatar(url: item.guruFoto, filled: filled),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.guruNama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.mapelNama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: fgSub),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.kelasNama} (Jam ${item.jamKeList.join(", ")})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: fgSub,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.timeRange,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  item.sudahDiisiJurnal ? Icons.check_circle_rounded : Icons.more_horiz_rounded,
                  color: item.sudahDiisiJurnal ? Colors.greenAccent.shade400 : fg.withValues(alpha: 0.85),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({required this.url, required this.filled});

  final String url;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = filled ? Colors.white : MainColor.primaryColor;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (filled ? Colors.white : MainColor.primaryColor).withValues(alpha: 0.18),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.person_rounded, color: iconColor, size: 22)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.person_rounded, color: iconColor, size: 22),
            ),
    );
  }
}

// --- Form (add/edit) --------------------------------------------------------

class JadwalFormPage extends StatefulWidget {
  const JadwalFormPage({super.key, this.jadwalId, required this.initialDate});

  final int? jadwalId;
  final DateTime initialDate;

  @override
  State<JadwalFormPage> createState() => _JadwalFormPageState();
}

class _JadwalFormPageState extends State<JadwalFormPage> {
  SupabaseClient get _supabase => Supabase.instance.client;

  bool get _isEdit => widget.jadwalId != null;

  bool _isLoadingMeta = true;
  bool _isLocked = false;
  final RxBool _isSaving = false.obs;

  int? _periodeId;
  String _periodeNama = 'Memuat...';

  late DateTime _tanggal;
  List<int> _allJamKe = [];
  final Map<int, String> _jamWaktu = {};

  List<KelasOption> _kelasOptions = [];
  List<PelajaranOption> _pelajaranOptions = [];
  List<GuruOption> _guruOptions = [];

  KelasOption? _kelas;
  PelajaranOption? _pelajaran;
  GuruOption? _guru;
  bool _aktif = true;
  bool _jadwalRutin = false;
  final Set<int> _selectedJamKe = {};
  Set<int> _occupiedJamKe = {};

  @override
  void initState() {
    super.initState();
    _tanggal = dateOnly(widget.initialDate);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _isLoadingMeta = true);
    try {
      final periode = await _supabase
          .from('master_periode')
          .select('id, nama_periode')
          .eq('is_active', true)
          .maybeSingle();
      _periodeId = asInt(periode?['id']);
      _periodeNama = (periode?['nama_periode'] as String?) ?? 'Tidak ada periode aktif';

      final kelasRows = await _supabase
          .from('master_kelas')
          .select('id, nama_kelas')
          .order('nama_kelas') as List;
      _kelasOptions = kelasRows.map((r) {
        final row = r as Map<String, dynamic>;
        return KelasOption(id: asInt(row['id'])!, nama: (row['nama_kelas'] as String?) ?? '');
      }).toList();

      final mapelRows = await _supabase
          .from('master_mata_pelajaran')
          .select('id, nama_mata_pelajaran')
          .order('nama_mata_pelajaran') as List;
      _pelajaranOptions = mapelRows.map((r) {
        final row = r as Map<String, dynamic>;
        return PelajaranOption(
          id: asInt(row['id'])!,
          nama: (row['nama_mata_pelajaran'] as String?) ?? '',
        );
      }).toList();

      final guruRows = await _supabase
          .from('profiles')
          .select('id, nama_lengkap, jabatan')
          .eq('role', 'guru')
          .order('nama_lengkap') as List;
      _guruOptions = guruRows.map((r) {
        final row = r as Map<String, dynamic>;
        final nama = (row['nama_lengkap'] as String?)?.trim();
        return GuruOption(
          id: row['id'] as String,
          nama: (nama == null || nama.isEmpty) ? 'Guru' : nama,
          jabatan: (row['jabatan'] as String?) ?? '',
        );
      }).toList();

      final jamRows = await _supabase
          .from('master_jam')
          .select('jam_ke, waktu_reguler')
          .order('jam_ke') as List;
      _allJamKe = [];
      for (final r in jamRows) {
        final row = r as Map<String, dynamic>;
        final jamKe = asInt(row['jam_ke']);
        if (jamKe == null) continue;
        _allJamKe.add(jamKe);
        _jamWaktu[jamKe] = (row['waktu_reguler'] as String?) ?? '';
      }

      if (_isEdit) {
        final row = await _supabase
            .from('jadwal_mengajar')
            .select('kelas_id, mata_pelajaran_id, guru_id, jam_ids, is_active')
            .eq('id', widget.jadwalId!)
            .single();

        final kelasId = asInt(row['kelas_id']);
        final mapelId = asInt(row['mata_pelajaran_id']);
        final guruId = row['guru_id'] as String?;
        _kelas = _kelasOptions.where((k) => k.id == kelasId).firstOrNull;
        _pelajaran = _pelajaranOptions.where((p) => p.id == mapelId).firstOrNull;
        _guru = _guruOptions.where((g) => g.id == guruId).firstOrNull;
        _aktif = (row['is_active'] as bool?) ?? true;
        final jamRaw = row['jam_ids'];
        if (jamRaw is List) {
          for (final v in jamRaw) {
            final p = asInt(v);
            if (p != null) _selectedJamKe.add(p);
          }
        }

        await _checkLocked();
      }

      await _recomputeOccupied();
    } catch (error) {
      showMasterDataError('Gagal memuat data jadwal', error);
    } finally {
      if (mounted) setState(() => _isLoadingMeta = false);
    }
  }

  /// A jadwal is locked once its teacher has already submitted (or the admin
  /// has already processed) a jurnal for this specific date — at that point
  /// it records real history and must not be edited or deleted.
  Future<void> _checkLocked() async {
    final dateStr = formatDateIso(_tanggal);
    final rows = await _supabase
        .from('jurnal_harian')
        .select('jadwal_id, jadwal_ids')
        .eq('tanggal', dateStr) as List;
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      final ids = <int>{};
      final primary = asInt(row['jadwal_id']);
      if (primary != null) ids.add(primary);
      final arr = row['jadwal_ids'];
      if (arr is List) {
        for (final v in arr) {
          final p = asInt(v);
          if (p != null) ids.add(p);
        }
      }
      if (ids.contains(widget.jadwalId)) {
        _isLocked = true;
        return;
      }
    }
  }

  Future<void> _recomputeOccupied() async {
    if (_kelas == null || _periodeId == null) {
      setState(() => _occupiedJamKe = {});
      return;
    }
    final dateStr = formatDateIso(_tanggal);
    final weekday = _tanggal.weekday;
    try {
      final rows = await _supabase
          .from('jadwal_mengajar')
          .select('id, jam_ids')
          .eq('is_active', true)
          .eq('periode_id', _periodeId!)
          .eq('kelas_id', _kelas!.id)
          .or('and(tanggal.is.null,hari.eq.$weekday),tanggal.eq.$dateStr') as List;
      final occ = <int>{};
      for (final r in rows) {
        final row = r as Map<String, dynamic>;
        final rowId = asInt(row['id']);
        if (_isEdit && rowId == widget.jadwalId) continue;
        final arr = row['jam_ids'];
        if (arr is List) {
          for (final v in arr) {
            final p = asInt(v);
            if (p != null) occ.add(p);
          }
        }
      }
      if (mounted) setState(() => _occupiedJamKe = occ);
    } catch (error) {
      showMasterDataError('Gagal memeriksa bentrok jadwal', error);
    }
  }

  Future<void> _pickTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() => _tanggal = dateOnly(picked));
    _recomputeOccupied();
  }

  void _toggleJam(int jamKe) {
    if (_isLocked) return;
    if (_occupiedJamKe.contains(jamKe) && !_selectedJamKe.contains(jamKe)) return;
    setState(() {
      if (_selectedJamKe.contains(jamKe)) {
        _selectedJamKe.remove(jamKe);
      } else {
        _selectedJamKe.add(jamKe);
      }
    });
  }

  Future<void> _save() async {
    if (_kelas == null) {
      showMasterDataError('Data belum lengkap', 'Kelas wajib dipilih');
      return;
    }
    if (_pelajaran == null) {
      showMasterDataError('Data belum lengkap', 'Pelajaran wajib dipilih');
      return;
    }
    if (_guru == null) {
      showMasterDataError('Data belum lengkap', 'Guru wajib dipilih');
      return;
    }
    if (_selectedJamKe.isEmpty) {
      showMasterDataError('Data belum lengkap', 'Pilih minimal satu jam ke');
      return;
    }
    if (_periodeId == null) {
      showMasterDataError(
        'Tidak ada periode aktif',
        'Aktifkan periode tahun ajaran terlebih dahulu di menu Periode.',
      );
      return;
    }

    _isSaving.value = true;
    try {
      final jamIds = _selectedJamKe.toList()..sort();
      if (_isEdit) {
        await _supabase.from('jadwal_mengajar').update({
          'mata_pelajaran_id': _pelajaran!.id,
          'guru_id': _guru!.id,
          'jam_ids': jamIds,
          'is_active': _aktif,
        }).eq('id', widget.jadwalId!);
      } else {
        await _supabase.from('jadwal_mengajar').insert({
          'periode_id': _periodeId,
          'tanggal': _jadwalRutin ? null : formatDateIso(_tanggal),
          'hari': _tanggal.weekday,
          'kelas_id': _kelas!.id,
          'mata_pelajaran_id': _pelajaran!.id,
          'guru_id': _guru!.id,
          'jam_ids': jamIds,
          'is_active': _aktif,
        });
      }
      showMasterDataSuccess('Jadwal mengajar tersimpan.');
      Get.back(result: true);
    } catch (error) {
      showMasterDataError('Gagal menyimpan jadwal', error);
    } finally {
      _isSaving.value = false;
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus jadwal mengajar?'),
        content: const Text('Jadwal ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _isSaving.value = true;
    try {
      await _supabase.from('jadwal_mengajar').delete().eq('id', widget.jadwalId!);
      showMasterDataSuccess('Jadwal mengajar dihapus.');
      Get.back(result: true);
    } catch (error) {
      showMasterDataError('Gagal menghapus jadwal', error);
    } finally {
      _isSaving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: _isEdit ? 'Edit Jadwal Mengajar' : 'Tambah Jadwal Mengajar',
        onBack: () => Get.back(),
        onDelete: (_isEdit && !_isLocked && !_isLoadingMeta) ? _confirmDelete : null,
      ),
      body: SafeArea(
        child: _isLoadingMeta
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isLocked) ...[
                      _buildLockedBanner(),
                      const SizedBox(height: 20),
                    ],
                    _lockedField('Periode', _periodeNama),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTanggalField()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildKelasField()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Jam Ke',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    _buildJamPicker(),
                    const SizedBox(height: 20),
                    MasterDataDropdown<PelajaranOption>(
                      label: 'Pelajaran',
                      value: _pelajaran,
                      items: _pelajaranOptions,
                      itemLabel: (p) => p.nama,
                      hint: 'Pilih Pelajaran',
                      onChanged: _isLocked ? null : (v) => setState(() => _pelajaran = v),
                    ),
                    const SizedBox(height: 20),
                    MasterDataDropdown<GuruOption>(
                      label: 'Guru',
                      value: _guru,
                      items: _guruOptions,
                      itemLabel: (g) => g.nama,
                      hint: 'Pilih Guru',
                      onChanged: _isLocked ? null : (v) => setState(() => _guru = v),
                    ),
                    const SizedBox(height: 20),
                    MasterDataCheckboxRow(
                      label: 'Aktif',
                      value: _aktif,
                      onChanged: _isLocked ? (_) {} : (v) => setState(() => _aktif = v),
                    ),
                    if (!_isEdit) ...[
                      const SizedBox(height: 20),
                      _buildJadwalRutinToggle(),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: (_isLoadingMeta || _isLocked)
          ? null
          : Obx(() => MasterDataSaveBar(isSaving: _isSaving.value, onSave: _save)),
    );
  }

  Widget _buildLockedBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Colors.red.shade400, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Jurnal untuk jadwal ini sudah diisi oleh guru, sehingga jadwal tidak dapat diubah atau dihapus lagi.',
              style: TextStyle(fontSize: 12.5, color: Colors.red.shade700, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockedField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.black45),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.black26),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTanggalField() {
    if (_isEdit) {
      return _lockedField('Tanggal', formatDateLong(_tanggal));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tanggal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickTanggal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(color: masterDataFieldFill, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatDateLong(_tanggal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
                Icon(Icons.calendar_today_rounded, size: 16, color: MainColor.primaryColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKelasField() {
    if (_isEdit) {
      return _lockedField('Kelas', _kelas?.nama ?? '-');
    }
    return MasterDataDropdown<KelasOption>(
      label: 'Kelas',
      value: _kelas,
      items: _kelasOptions,
      itemLabel: (k) => k.nama,
      hint: 'Pilih Kelas',
      onChanged: (v) {
        setState(() => _kelas = v);
        _recomputeOccupied();
      },
    );
  }

  Widget _buildJamPicker() {
    if (_allJamKe.isEmpty) {
      return const Text(
        'Belum ada data jam pelajaran.',
        style: TextStyle(fontSize: 13, color: Colors.black45),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final jamKe in _allJamKe)
          _JamChip(
            jamKe: jamKe,
            selected: _selectedJamKe.contains(jamKe),
            occupied: _occupiedJamKe.contains(jamKe) && !_selectedJamKe.contains(jamKe),
            locked: _isLocked,
            onTap: () => _toggleJam(jamKe),
          ),
      ],
    );
  }

  Widget _buildJadwalRutinToggle() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MainColor.fourthColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.repeat_rounded, color: MainColor.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buat Jadwal Rutin',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Otomatis berulang setiap minggu di hari yang sama selama periode '
                  '"$_periodeNama" berjalan. Jika nonaktif, jadwal hanya dibuat untuk '
                  'tanggal yang dipilih.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ],
            ),
          ),
          Switch(
            value: _jadwalRutin,
            activeThumbColor: MainColor.primaryColor,
            onChanged: (v) => setState(() => _jadwalRutin = v),
          ),
        ],
      ),
    );
  }
}

class _JamChip extends StatelessWidget {
  const _JamChip({
    required this.jamKe,
    required this.selected,
    required this.occupied,
    required this.locked,
    required this.onTap,
  });

  final int jamKe;
  final bool selected;
  final bool occupied;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool disabled = occupied || locked;
    late final Color bg;
    late final Color fg;
    late final Color border;
    if (selected) {
      bg = MainColor.primaryColor;
      fg = Colors.white;
      border = MainColor.primaryColor;
    } else if (disabled) {
      bg = Colors.black.withValues(alpha: 0.05);
      fg = Colors.black26;
      border = Colors.black12;
    } else {
      bg = MainColor.fourthColor.withValues(alpha: 0.28);
      fg = MainColor.primaryColor;
      border = MainColor.fourthColor;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: disabled ? null : onTap,
        child: Container(
          width: 52,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: selected
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 13, color: fg),
                    const SizedBox(width: 2),
                    Text('$jamKe', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                )
              : Text('$jamKe', style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ),
    );
  }
}
