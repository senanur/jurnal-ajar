import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/guru/guru_widgets.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/curved_gradient_header.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:jurnal_mengajar/app/widgets/week_date_strip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JurnalListItem {
  JurnalListItem({
    required this.id,
    required this.jadwalId,
    required this.guruNama,
    required this.guruFoto,
    required this.kelasNama,
    required this.mapelNama,
    required this.materi,
    required this.catatanGuru,
    required this.status,
    required this.catatanAdmin,
    required this.sakit,
    required this.izin,
    required this.alpha,
  });

  final int id;
  final int jadwalId;
  final String guruNama;
  final String guruFoto;
  final String kelasNama;
  final String mapelNama;
  final String materi;
  final String catatanGuru;
  final String status; // pending | approved | rejected
  final String catatanAdmin;
  final int sakit;
  final int izin;
  final int alpha;
}

class SiswaAbsenItem {
  SiswaAbsenItem({
    required this.nama,
    required this.label,
    required this.color,
    this.waTerkirim = false,
  });
  final String nama;
  final String label; // S / I / A
  final Color color;
  /// No WhatsApp integration exists yet — this always reads false for now.
  /// The widget still renders both label states so the visual is ready for
  /// when that integration lands.
  final bool waTerkirim;
}

class JurnalListController extends GetxController {
  SupabaseClient get _supabase => Supabase.instance.client;

  final Rx<DateTime> selectedDate = dateOnly(DateTime.now()).obs;
  final RxInt weekDirection = 0.obs;
  final RxBool isLoading = true.obs;
  final RxList<JurnalListItem> items = <JurnalListItem>[].obs;
  final TextEditingController searchController = TextEditingController();
  final RxString query = ''.obs;

  List<DateTime> get weekDays => weekDaysFor(selectedDate.value);

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() => query.value = searchController.text);
    fetchItems();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  List<JurnalListItem> get filtered {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) {
      final haystack = '${e.guruNama} ${e.kelasNama} ${e.mapelNama} ${e.materi}'.toLowerCase();
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

  Future<void> fetchItems() async {
    isLoading.value = true;
    final dateStr = formatDateIso(selectedDate.value);

    try {
      final rows = await _supabase
          .from('jurnal_harian')
          .select(
            'id, jadwal_id, materi, catatan, status, catatan_admin, '
            'jadwal_mengajar(guru_id, kelas_id, mata_pelajaran_id, '
            'profiles(nama_lengkap, foto_url), '
            'master_kelas(nama_kelas), '
            'master_mata_pelajaran(nama_mata_pelajaran))',
          )
          .eq('tanggal', dateStr)
          .order('id', ascending: false) as List;

      final rawItems = <Map<String, dynamic>>[];
      final ids = <int>[];
      for (final r in rows) {
        final row = r as Map<String, dynamic>;
        final id = asInt(row['id']);
        if (id == null) continue;
        ids.add(id);
        rawItems.add(row);
      }

      final counts = <int, Map<String, int>>{};
      if (ids.isNotEmpty) {
        final presensiRows = await _supabase
            .from('presensi_siswa')
            .select('jurnal_id, status')
            .inFilter('jurnal_id', ids) as List;
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
      }

      final list = <JurnalListItem>[];
      for (final row in rawItems) {
        final id = asInt(row['id'])!;
        final jadwal = row['jadwal_mengajar'] as Map<String, dynamic>?;
        final profile = jadwal?['profiles'] as Map<String, dynamic>?;
        final kelas = jadwal?['master_kelas'] as Map<String, dynamic>?;
        final mapel = jadwal?['master_mata_pelajaran'] as Map<String, dynamic>?;
        final namaGuru = (profile?['nama_lengkap'] as String?)?.trim();
        final c = counts[id] ?? {'s': 0, 'i': 0, 'a': 0};
        list.add(JurnalListItem(
          id: id,
          jadwalId: asInt(row['jadwal_id']) ?? 0,
          guruNama: (namaGuru == null || namaGuru.isEmpty) ? 'Guru' : namaGuru,
          guruFoto: (profile?['foto_url'] as String?) ?? '',
          kelasNama: (kelas?['nama_kelas'] as String?) ?? '-',
          mapelNama: (mapel?['nama_mata_pelajaran'] as String?) ?? '-',
          materi: (row['materi'] as String?) ?? '',
          catatanGuru: (row['catatan'] as String?) ?? '',
          status: (row['status'] as String?) ?? 'pending',
          catatanAdmin: (row['catatan_admin'] as String?) ?? '',
          sakit: c['s']!,
          izin: c['i']!,
          alpha: c['a']!,
        ));
      }

      items.value = list;
    } catch (error) {
      showMasterDataError('Gagal memuat jurnal mengajar', error);
    } finally {
      isLoading.value = false;
    }
  }
}

class JurnalListPage extends StatefulWidget {
  const JurnalListPage({super.key});

  @override
  State<JurnalListPage> createState() => _JurnalListPageState();
}

class _JurnalListPageState extends State<JurnalListPage> {
  final JurnalListController controller = Get.put(JurnalListController());

  Future<void> _openDetail(JurnalListItem item) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => JurnalDetailSheet(item: item),
    );
    if (changed == true) controller.fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: 'Jurnal Mengajar',
        onBack: () => Get.offAllNamed(Routes.dashboardAdmin),
      ),
      body: SafeArea(
        child: CurvedGradientListBody(
          header: Obx(
            () => WeekDateStrip(
              weekDays: controller.weekDays,
              selectedDate: controller.selectedDate.value,
              weekDirection: controller.weekDirection.value,
              onPrevious: controller.previousWeek,
              onNext: controller.nextWeek,
              onSelectDate: controller.selectDate,
            ),
          ),
          searchField: MasterDataSearchField(
            controller: controller.searchController,
            hint: 'Cari Guru, Materi, Kelas',
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = controller.filtered;
              if (list.isEmpty) {
                return const MasterDataEmptyState(
                  message: 'Belum ada jurnal mengajar pada tanggal ini.',
                );
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  return MasterDataEntrance(
                    delay: Duration(milliseconds: 30 * index),
                    child: _JurnalTile(item: item, onTap: () => _openDetail(item)),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _JurnalTile extends StatelessWidget {
  const _JurnalTile({required this.item, required this.onTap});

  final JurnalListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final Color fgSub;
    late final Color badgeBg;
    late final Color badgeFg;
    late final String badgeText;

    switch (item.status) {
      case 'approved':
        bg = Colors.green.withValues(alpha: 0.08);
        fg = Colors.black87;
        fgSub = Colors.black54;
        badgeBg = Colors.green.withValues(alpha: 0.18);
        badgeFg = Colors.green.shade700;
        badgeText = 'APPROVED';
      case 'rejected':
        bg = Colors.orange.withValues(alpha: 0.12);
        fg = Colors.black87;
        fgSub = Colors.black54;
        badgeBg = Colors.orange.withValues(alpha: 0.22);
        badgeFg = Colors.orange.shade800;
        badgeText = 'REJECTED';
      default:
        bg = MainColor.primaryColor;
        fg = Colors.white;
        fgSub = Colors.white.withValues(alpha: 0.85);
        badgeBg = Colors.white.withValues(alpha: 0.25);
        badgeFg = Colors.white;
        badgeText = 'PENDING';
    }

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
                _MiniAvatar(url: item.guruFoto, filled: item.status == 'pending'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.guruNama,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: badgeFg,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.kelasNama} • ${item.mapelNama}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: fgSub),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ketidakhadiran - S:${item.sakit} I:${item.izin} A:${item.alpha}',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fgSub),
                      ),
                    ],
                  ),
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

// --- Detail sheet ------------------------------------------------------------

class JurnalDetailSheet extends StatefulWidget {
  const JurnalDetailSheet({super.key, required this.item});

  final JurnalListItem item;

  @override
  State<JurnalDetailSheet> createState() => _JurnalDetailSheetState();
}

class _JurnalDetailSheetState extends State<JurnalDetailSheet> {
  SupabaseClient get _supabase => Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;
  List<SiswaAbsenItem> _siswaTidakHadir = [];
  List<String> _fotoUrls = [];
  final TextEditingController _catatanController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await _supabase
          .from('presensi_siswa')
          .select('status, master_siswa(nama_siswa)')
          .eq('jurnal_id', widget.item.id) as List;

      final list = <SiswaAbsenItem>[];
      for (final r in rows) {
        final row = r as Map<String, dynamic>;
        final status = ((row['status'] as String?) ?? '').toLowerCase();
        final siswa = row['master_siswa'] as Map<String, dynamic>?;
        final nama = (siswa?['nama_siswa'] as String?) ?? '-';

        String? label;
        Color? color;
        if (status.startsWith('sakit')) {
          label = 'S';
          color = Colors.orange.shade600;
        } else if (status.startsWith('izin')) {
          label = 'I';
          color = MainColor.secondaryColor;
        } else if (status.startsWith('alpha') || status.startsWith('alfa')) {
          label = 'A';
          color = Colors.red.shade400;
        }
        if (label == null || color == null) continue;
        list.add(SiswaAbsenItem(nama: nama, label: label, color: color));
      }

      if (mounted) {
        setState(() {
          _siswaTidakHadir = list;
          _fotoUrls = <String>[];
        });
      }
      loadJurnalFotoUrls(_supabase, widget.item.id).then((urls) {
        if (mounted) setState(() => _fotoUrls = urls);
      }).catchError((_) {});
    } catch (error) {
      showMasterDataError('Gagal memuat data presensi', error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _isSaving = true);
    try {
      await _supabase.from('jurnal_harian').update({
        'status': 'approved',
        'validated_at': DateTime.now().toIso8601String(),
        'validated_by': _supabase.auth.currentUser?.id,
      }).eq('id', widget.item.id);
      showMasterDataSuccess('Jurnal disetujui.');
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      showMasterDataError('Gagal menyetujui jurnal', error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reject() async {
    final note = _catatanController.text.trim();
    if (note.isEmpty) {
      showMasterDataError(
        'Catatan admin wajib diisi',
        'Tuliskan alasan penolakan agar guru tahu yang perlu diperbaiki.',
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _supabase.from('jurnal_harian').update({
        'status': 'rejected',
        'catatan_admin': note,
        'validated_at': DateTime.now().toIso8601String(),
        'validated_by': _supabase.auth.currentUser?.id,
      }).eq('id', widget.item.id);
      showMasterDataSuccess('Jurnal ditolak.');
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      showMasterDataError('Gagal menolak jurnal', error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          JurnalFotoGallery(urls: _fotoUrls),
                          const SizedBox(height: 16),                          Text(
                            item.guruNama,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.kelasNama} | ${item.mapelNama}',
                            style: TextStyle(
                              fontSize: 13,
                              color: MainColor.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          _label('Materi Pembelajaran:'),
                          _value(item.materi.isEmpty ? '-' : item.materi),
                          const SizedBox(height: 14),
                          _label('Catatan Guru:'),
                          _value(item.catatanGuru.isEmpty ? '-' : item.catatanGuru),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatNumber(label: 'SAKIT', value: item.sakit, color: Colors.orange.shade600),
                              _StatNumber(label: 'IZIN', value: item.izin, color: MainColor.secondaryColor),
                              _StatNumber(label: 'ALPHA', value: item.alpha, color: Colors.red.shade400),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _label('Daftar Siswa Tidak Hadir:'),
                          const SizedBox(height: 8),
                          if (_siswaTidakHadir.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Semua siswa hadir.',
                                style: TextStyle(fontSize: 13, color: Colors.black45),
                              ),
                            )
                          else
                            for (final s in _siswaTidakHadir) _SiswaAbsenRow(item: s),
                          const SizedBox(height: 20),
                          _buildBottomSection(item),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
      );

  Widget _value(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: const TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.4)),
      );

  Widget _buildBottomSection(JurnalListItem item) {
    switch (item.status) {
      case 'approved':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Sudah Disetujui',
                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      case 'rejected':
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cancel_rounded, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ditolak: ${item.catatanAdmin.isEmpty ? "-" : item.catatanAdmin}',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _catatanController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Tambahkan catatan admin (wajib jika ditolak)...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                filled: true,
                fillColor: masterDataFieldFill,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('TOLAK', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('SETUJUI', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }
}

class _StatNumber extends StatelessWidget {
  const _StatNumber({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.85),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _SiswaAbsenRow extends StatelessWidget {
  const _SiswaAbsenRow({required this.item});

  final SiswaAbsenItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nama, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      item.waTerkirim ? Icons.check_circle : Icons.cancel_outlined,
                      size: 12,
                      color: item.waTerkirim ? Colors.green.shade400 : Colors.black38,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.waTerkirim ? 'WA Terkirim' : 'WA Tidak Terkirim',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.waTerkirim ? Colors.green.shade600 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: item.color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Text(
              item.label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: item.color),
            ),
          ),
        ],
      ),
    );
  }
}
