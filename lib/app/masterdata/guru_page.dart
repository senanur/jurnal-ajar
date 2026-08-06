import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:jurnal_mengajar/app/widgets/week_date_strip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuruItem {
  GuruItem({
    required this.id,
    required this.nama,
    required this.jabatan,
    required this.fotoUrl,
    required this.email,
    required this.noTelp,
    required this.alamat,
  });

  final String id;
  final String nama;
  final String jabatan;
  final String fotoUrl;
  final String email;
  final String noTelp;
  final String alamat;

  factory GuruItem.fromRow(Map<String, dynamic> row) => GuruItem(
        id: row['id'] as String,
        nama: (row['nama_lengkap'] as String?)?.trim().isNotEmpty == true
            ? row['nama_lengkap'] as String
            : 'Guru',
        jabatan: (row['jabatan'] as String?) ?? '',
        fotoUrl: (row['foto_url'] as String?) ?? '',
        email: (row['email'] as String?) ?? '',
        noTelp: (row['no_telp'] as String?) ?? '',
        alamat: (row['alamat'] as String?) ?? '',
      );
}

class GuruListController extends GetxController {
  SupabaseClient get _supabase => Supabase.instance.client;

  final RxList<GuruItem> items = <GuruItem>[].obs;
  final RxBool isLoading = true.obs;
  final TextEditingController searchController = TextEditingController();
  final RxString query = ''.obs;

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

  List<GuruItem> get filtered {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) {
      return e.nama.toLowerCase().contains(q) || e.jabatan.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> fetchItems() async {
    isLoading.value = true;
    try {
      final rows = await _supabase
          .from('profiles')
          .select('id, nama_lengkap, jabatan, foto_url, email, no_telp, alamat')
          .eq('role', 'guru')
          .order('nama_lengkap', ascending: true) as List;
      items.value =
          rows.map((r) => GuruItem.fromRow(r as Map<String, dynamic>)).toList();
    } catch (error) {
      showMasterDataError('Gagal memuat data guru', error);
    } finally {
      isLoading.value = false;
    }
  }
}

class GuruListPage extends StatefulWidget {
  const GuruListPage({super.key});

  @override
  State<GuruListPage> createState() => _GuruListPageState();
}

class _GuruListPageState extends State<GuruListPage> {
  final GuruListController controller = Get.put(GuruListController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: 'Guru',
        onBack: () => Get.offAllNamed(Routes.dashboardAdmin),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              MasterDataSearchField(controller: controller.searchController),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = controller.filtered;
                  if (list.isEmpty) {
                    return const MasterDataEmptyState(message: 'Belum ada data guru.');
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final filled = index.isEven;
                      return MasterDataEntrance(
                        delay: Duration(milliseconds: 30 * index),
                        child: MasterDataListTile(
                          leading: _Avatar(url: item.fotoUrl, filled: filled, size: 44),
                          title: item.nama,
                          subtitle: item.jabatan.isEmpty ? 'Guru Pengajar' : item.jabatan,
                          filled: filled,
                          onTap: () => Get.to(() => GuruDetailPage(guru: item)),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.filled, this.size = 44});

  final String url;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = filled ? Colors.white : MainColor.primaryColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (filled ? Colors.white : MainColor.primaryColor).withValues(alpha: 0.18),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Icon(Icons.person_rounded, color: iconColor, size: size * 0.55)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.person_rounded, color: iconColor, size: size * 0.55),
            ),
    );
  }
}

// --- Detail page -----------------------------------------------------------

class JamInfo {
  JamInfo({required this.jamKe, required this.waktu});
  final int jamKe;
  final String waktu;
}

class GuruJadwalItem {
  GuruJadwalItem({
    required this.id,
    required this.timeRange,
    required this.kelas,
    required this.pelajaran,
    required this.sudahDiisi,
  });

  final int id;
  final String timeRange;
  final String kelas;
  final String pelajaran;
  final bool sudahDiisi;
}

class GuruJurnalItem {
  GuruJurnalItem({
    required this.jurnalId,
    required this.kelas,
    required this.pelajaran,
    required this.status,
    required this.sakit,
    required this.izin,
    required this.alpha,
  });

  final int jurnalId;
  final String kelas;
  final String pelajaran;
  final String status;
  final int sakit;
  final int izin;
  final int alpha;

  GuruJurnalItem copyWith({int? sakit, int? izin, int? alpha}) => GuruJurnalItem(
        jurnalId: jurnalId,
        kelas: kelas,
        pelajaran: pelajaran,
        status: status,
        sakit: sakit ?? this.sakit,
        izin: izin ?? this.izin,
        alpha: alpha ?? this.alpha,
      );
}

/// First jam's start time to last jam's end time, e.g. "07.15-08.45".
String _timeRangeFromJam(List<JamInfo> jamInfos) {
  if (jamInfos.isEmpty) return '-';
  final sorted = [...jamInfos]..sort((a, b) => a.jamKe.compareTo(b.jamKe));
  final start = sorted.first.waktu.split('-').first.trim();
  final end = sorted.last.waktu.split('-').last.trim();
  return '$start-$end';
}

class GuruDetailController extends GetxController {
  GuruDetailController({required this.guru});

  final GuruItem guru;
  SupabaseClient get _supabase => Supabase.instance.client;

  final Rx<DateTime> selectedDate = dateOnly(DateTime.now()).obs;
  final RxInt weekDirection = 0.obs;
  final RxBool isLoading = true.obs;
  final RxList<GuruJadwalItem> jadwalList = <GuruJadwalItem>[].obs;
  final RxList<GuruJurnalItem> jurnalList = <GuruJurnalItem>[].obs;

  List<DateTime> get weekDays => weekDaysFor(selectedDate.value);

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  void previousWeek() {
    weekDirection.value = -1;
    selectedDate.value = selectedDate.value.subtract(const Duration(days: 7));
    _load();
  }

  void nextWeek() {
    weekDirection.value = 1;
    selectedDate.value = selectedDate.value.add(const Duration(days: 7));
    _load();
  }

  void selectDate(DateTime date) {
    if (isSameDay(date, selectedDate.value)) return;
    selectedDate.value = date;
    _load();
  }

  Future<void> _load() async {
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

      var jadwalQuery = _supabase
          .from('jadwal_mengajar')
          .select('id, kelas_id, mata_pelajaran_id, jam_ids')
          .eq('guru_id', guru.id)
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
        final rows = await _supabase
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
        final rows = await _supabase
            .from('master_mata_pelajaran')
            .select('id, nama_mata_pelajaran')
            .inFilter('id', mapelIds.toList()) as List;
        for (final r in rows) {
          final row = r as Map<String, dynamic>;
          mapelMap[asInt(row['id'])!] = (row['nama_mata_pelajaran'] as String?) ?? '-';
        }
      }

      // jadwal_mengajar.jam_ids stores master_jam.jam_ke (1..10), not
      // master_jam.id — confirmed against real data (existing jam_ids like
      // "1" have no matching master_jam.id, since those start at 4).
      final jamMap = <int, JamInfo>{};
      if (jamIds.isNotEmpty) {
        final rows = await _supabase
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

      final jurnalRows = await _supabase
          .from('jurnal_harian')
          .select('id, jadwal_id, jadwal_ids, status')
          .eq('tanggal', dateStr) as List;

      final answeredJadwalIds = <int>{};
      for (final r in jurnalRows) {
        final row = r as Map<String, dynamic>;
        final jid = asInt(row['jadwal_id']);
        if (jid != null) answeredJadwalIds.add(jid);
        final arr = row['jadwal_ids'];
        if (arr is List) {
          for (final v in arr) {
            final p = asInt(v);
            if (p != null) answeredJadwalIds.add(p);
          }
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
        jadwalItems.add(GuruJadwalItem(
          id: id,
          timeRange: _timeRangeFromJam(jamInfos),
          kelas: kelasMap[kelasId] ?? '-',
          pelajaran: mapelMap[mapelId] ?? '-',
          sudahDiisi: answeredJadwalIds.contains(id),
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
        final presensiRows = await _supabase
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

      jadwalList.value = jadwalItems;
      jurnalList.value = jurnalItems;
    } catch (error) {
      showMasterDataError('Gagal memuat aktivitas guru', error);
    } finally {
      isLoading.value = false;
    }
  }
}

class GuruDetailPage extends StatefulWidget {
  const GuruDetailPage({super.key, required this.guru});

  final GuruItem guru;

  @override
  State<GuruDetailPage> createState() => _GuruDetailPageState();
}

class _GuruDetailPageState extends State<GuruDetailPage> {
  late final GuruDetailController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      GuruDetailController(guru: widget.guru),
      tag: widget.guru.id,
    );
  }

  @override
  void dispose() {
    Get.delete<GuruDetailController>(tag: widget.guru.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guru = widget.guru;
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(title: 'Detail Guru', onBack: () => Get.back()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _Avatar(url: guru.fotoUrl, filled: false, size: 96)),
              const SizedBox(height: 14),
              Text(
                guru.nama,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                guru.jabatan.isEmpty ? 'Guru Pengajar' : guru.jabatan,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              if (guru.noTelp.isNotEmpty)
                _ContactRow(icon: Icons.call_rounded, text: guru.noTelp),
              if (guru.email.isNotEmpty)
                _ContactRow(icon: Icons.mail_outline_rounded, text: guru.email),
              if (guru.alamat.isNotEmpty)
                _ContactRow(icon: Icons.location_on_outlined, text: guru.alamat),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
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
              const SizedBox(height: 20),
              Text(
                'Jadwal Mengajar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: MainColor.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                if (controller.isLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final list = controller.jadwalList;
                if (list.isEmpty) {
                  return const MasterDataEmptyState(message: 'Tidak ada jadwal mengajar.');
                }
                return Column(
                  children: [
                    for (final item in list)
                      MasterDataListTile(
                        title: '${item.timeRange}   ${item.kelas}',
                        subtitle: item.pelajaran,
                        filled: !item.sudahDiisi,
                        showChevron: false,
                      ),
                  ],
                );
              }),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Text(
                'Jurnal Mengajar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: MainColor.primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                if (controller.isLoading.value) {
                  return const SizedBox.shrink();
                }
                final list = controller.jurnalList;
                if (list.isEmpty) {
                  return const MasterDataEmptyState(message: 'Belum ada jurnal mengajar.');
                }
                return Column(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      MasterDataListTile(
                        title: list[i].kelas,
                        subtitle: list[i].pelajaran,
                        filled: i.isEven,
                        showChevron: false,
                        trailingWidget: _JurnalTrailing(item: list[i], filled: i.isEven),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MainColor.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13.5, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

class _JurnalTrailing extends StatelessWidget {
  const _JurnalTrailing({required this.item, required this.filled});

  final GuruJurnalItem item;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color textColor = filled ? Colors.white.withValues(alpha: 0.9) : MainColor.primaryColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'S:${item.sakit} I:${item.izin} A:${item.alpha}',
          style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        _statusIcon(item.status),
      ],
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22);
      case 'rejected':
        return Icon(Icons.cancel_rounded, color: Colors.red.shade300, size: 22);
      default:
        return Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade300, size: 20);
    }
  }
}
