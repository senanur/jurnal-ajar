import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/guru/guru_activity.dart';
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
    try {
      final activity =
          await loadGuruActivity(supabase: _supabase, guruId: guru.id, date: selectedDate.value);
      jadwalList.value = activity.jadwalList;
      jurnalList.value = activity.jurnalList;
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
