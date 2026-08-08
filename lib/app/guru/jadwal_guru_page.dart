import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/dashboard_guru.dart';
import 'package:jurnal_mengajar/app/guru/guru_activity.dart';
import 'package:jurnal_mengajar/app/guru/guru_widgets.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/widgets/curved_gradient_header.dart';
import 'package:jurnal_mengajar/app/widgets/dashboard_shared.dart';
import 'package:jurnal_mengajar/app/widgets/guru_drawer.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:jurnal_mengajar/app/widgets/week_date_strip.dart';

/// Full, uncapped Jadwal Mengajar list for the signed-in guru
/// (design/prompt/015_jadwal_guru.md). Reuses [DashboardGuruController]
/// directly (§10/§11.3 of that doc) rather than a near-duplicate controller —
/// GetX's `Get.put` returns the already-registered instance when the
/// dashboard is still alive underneath, so the selected date carries over.
class JadwalGuruPage extends StatefulWidget {
  const JadwalGuruPage({super.key});

  @override
  State<JadwalGuruPage> createState() => _JadwalGuruPageState();
}

class _JadwalGuruPageState extends State<JadwalGuruPage> {
  final DashboardGuruController controller = Get.put(DashboardGuruController());

  Future<void> _openDetail(GuruJadwalItem jadwal) =>
      openJadwalDetail(context, jadwal, onRefresh: controller.refreshActivity);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      drawer: GuruDrawer(currentRoute: Routes.guruJadwal),
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
                  if (controller.isLoadingActivity.value) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final list = controller.jadwalList;
                  if (list.isEmpty) {
                    return const MasterDataEmptyState(
                      message: 'Tidak ada jadwal mengajar pada tanggal ini.',
                    );
                  }
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
