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

/// Full, uncapped list of the signed-in guru's already-filled jurnal entries
/// for a selected date (design/prompt/017_jurnal_guru.md). Reuses
/// [DashboardGuruController] directly via [Get.put] so the already-registered
/// instance is reused (and the selected date carries over) when the dashboard
/// is still alive underneath — the same reasoning as [JadwalGuruPage].
class JurnalGuruPage extends StatefulWidget {
  const JurnalGuruPage({super.key});

  @override
  State<JurnalGuruPage> createState() => _JurnalGuruPageState();
}

class _JurnalGuruPageState extends State<JurnalGuruPage> {
  final DashboardGuruController controller = Get.put(DashboardGuruController());

  void _openDetail(GuruJurnalItem jurnal) {
    final jadwal = controller.jadwalList.where((j) => j.id == jurnal.jadwalId).firstOrNull;
    if (jadwal != null) {
      openJadwalDetail(context, jadwal, onRefresh: controller.refreshActivity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      drawer: GuruDrawer(currentRoute: Routes.guruJurnal),
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
                  'Jurnal Mengajar',
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
                  final list = controller.jurnalList;
                  if (list.isEmpty) {
                    return const MasterDataEmptyState(
                      message: 'Belum ada jurnal mengajar pada tanggal ini.',
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < list.length; i++)
                        MasterDataEntrance(
                          delay: Duration(milliseconds: 40 * i),
                          child: JurnalCard(
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
