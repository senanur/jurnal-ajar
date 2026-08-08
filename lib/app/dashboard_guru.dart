import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/guru/guru_activity.dart';
import 'package:jurnal_mengajar/app/guru/guru_widgets.dart';
import 'package:jurnal_mengajar/app/guru/jadwal_guru_page.dart';
import 'package:jurnal_mengajar/app/guru/jurnal_guru_page.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/curved_gradient_header.dart';
import 'package:jurnal_mengajar/app/widgets/dashboard_shared.dart';
import 'package:jurnal_mengajar/app/widgets/guru_drawer.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:jurnal_mengajar/app/widgets/week_date_strip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardGuruController extends GetxController {
  SupabaseClient get _supabase => Supabase.instance.client;

  final Rx<DateTime> selectedDate = dateOnly(DateTime.now()).obs;
  final RxInt weekDirection = 0.obs;

  final RxBool isLoadingProfile = true.obs;
  final RxBool isLoadingActivity = true.obs;

  final RxString namaLengkap = 'Guru'.obs;
  final RxString jabatan = ''.obs;
  final RxString fotoUrl = ''.obs;

  final RxList<GuruJadwalItem> jadwalList = <GuruJadwalItem>[].obs;
  final RxList<GuruJurnalItem> jurnalList = <GuruJurnalItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadProfile();
    _loadActivity();
  }

  List<DateTime> get weekDays => weekDaysFor(selectedDate.value);

  void previousWeek() {
    weekDirection.value = -1;
    selectedDate.value = selectedDate.value.subtract(const Duration(days: 7));
    _loadActivity();
  }

  void nextWeek() {
    weekDirection.value = 1;
    selectedDate.value = selectedDate.value.add(const Duration(days: 7));
    _loadActivity();
  }

  void selectDate(DateTime date) {
    if (isSameDay(date, selectedDate.value)) return;
    selectedDate.value = date;
    _loadActivity();
  }

  Future<void> refreshActivity() => _loadActivity();

  Future<void> _loadProfile() async {
    isLoadingProfile.value = true;
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final row = await _supabase
          .from('profiles')
          .select('nama_lengkap, jabatan, foto_url')
          .eq('id', userId)
          .maybeSingle();
      final nama = (row?['nama_lengkap'] as String?)?.trim();
      namaLengkap.value = (nama == null || nama.isEmpty) ? 'Guru' : nama;
      jabatan.value = (row?['jabatan'] as String?)?.trim() ?? '';
      fotoUrl.value = (row?['foto_url'] as String?)?.trim() ?? '';
    } catch (_) {
      // Header falls back to defaults; not worth blocking the dashboard.
    } finally {
      isLoadingProfile.value = false;
    }
  }

  Future<void> _loadActivity() async {
    isLoadingActivity.value = true;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      isLoadingActivity.value = false;
      return;
    }
    try {
      final activity = await loadGuruActivity(
        supabase: _supabase,
        guruId: userId,
        date: selectedDate.value,
      );
      jadwalList.value = activity.jadwalList;
      jurnalList.value = activity.jurnalList;
    } catch (error) {
      showMasterDataError('Gagal memuat aktivitas mengajar', error);
    } finally {
      isLoadingActivity.value = false;
    }
  }
}

/// Dashboard preview cap (design/prompt/014_guru.md §4.10): each listview
/// shows at most this many cards here; the rest is only reachable via
/// "Semua".
const int _kDashboardListPreviewCap = 2;

class DashboardGuru extends StatefulWidget {
  const DashboardGuru({super.key});

  @override
  State<DashboardGuru> createState() => _DashboardGuruState();
}

class _DashboardGuruState extends State<DashboardGuru> {
  final DashboardGuruController controller = Get.put(DashboardGuruController());

  Future<void> _openDetail(GuruJadwalItem jadwal) =>
      openJadwalDetail(context, jadwal, onRefresh: controller.refreshActivity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      drawer: GuruDrawer(currentRoute: Routes.dashboardGuru),
      appBar: DashboardAppBar(
        namaLengkap: controller.namaLengkap,
        jabatan: controller.jabatan,
        fotoUrl: controller.fotoUrl,
        isLoadingProfile: controller.isLoadingProfile,
      ),
      body: SafeArea(
        top: false,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(
                  title: 'Jadwal Mengajar',
                  onSemua: () => Get.to(() => const JadwalGuruPage()),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  if (controller.isLoadingActivity.value) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final full = controller.jadwalList;
                  if (full.isEmpty) {
                    return const MasterDataEmptyState(
                      message: 'Tidak ada jadwal mengajar pada tanggal ini.',
                    );
                  }
                  final list = full.take(_kDashboardListPreviewCap).toList();
                  return Column(
                    children: [
                      for (var i = 0; i < list.length; i++)
                        MasterDataEntrance(
                          delay: Duration(milliseconds: 40 * i),
                          child: JadwalCard(
                            item: list[i],
                            onTap: () => _openDetail(list[i]),
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Jurnal Mengajar',
                  onSemua: () => Get.to(() => const JurnalGuruPage()),
                ),
                const SizedBox(height: 12),
                Obx(() {
                  if (controller.isLoadingActivity.value) {
                    return const SizedBox.shrink();
                  }
                  final full = controller.jurnalList;
                  if (full.isEmpty) {
                    return const MasterDataEmptyState(
                      message: 'Belum ada jurnal mengajar.',
                    );
                  }
                  final list = full.take(_kDashboardListPreviewCap).toList();
                  return Column(
                    children: [
                      for (var i = 0; i < list.length; i++)
                        MasterDataEntrance(
                          delay: Duration(milliseconds: 40 * i),
                          child: Builder(
                            builder: (context) {
                              final jurnal = list[i];
                              final jadwal = controller.jadwalList
                                  .where((j) => j.id == jurnal.jadwalId)
                                  .firstOrNull;
                              return JurnalCard(
                                item: jurnal,
                                onTap: () {
                                  if (jadwal != null) _openDetail(jadwal);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSemua});

  final String title;
  final VoidCallback onSemua;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: MainColor.primaryColor,
          ),
        ),
        TextButton(
          onPressed: onSemua,
          style: TextButton.styleFrom(
            foregroundColor: MainColor.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Semua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
