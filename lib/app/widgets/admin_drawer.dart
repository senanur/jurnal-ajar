import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/widgets/drawer_widgets.dart';

/// Sidebar shared by every admin page.
class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  static const _builtRoutes = {
    Routes.dashboardAdmin,
    Routes.masterJadwal,
    Routes.masterJurnal,
    Routes.masterPeriode,
    Routes.masterPelajaran,
    Routes.masterJam,
    Routes.masterKelas,
    Routes.masterGuru,
    Routes.masterSiswa,
    Routes.pengaturan,
  };

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const DrawerLogoHeader(),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  DrawerItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    route: Routes.dashboardAdmin,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.dashboardAdmin, label: 'Dashboard'),
                  ),
                  DrawerItem(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Jurnal Mengajar',
                    route: Routes.masterJurnal,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.masterJurnal, label: 'Jurnal Mengajar'),
                  ),
                  DrawerItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Jadwal Mengajar',
                    route: Routes.masterJadwal,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.masterJadwal, label: 'Jadwal Mengajar'),
                  ),
                  DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Pengaturan',
                    route: Routes.pengaturan,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.pengaturan, label: 'Pengaturan'),
                  ),
                  DrawerItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Tentang Aplikasi',
                    route: Routes.tentang,
                    currentRoute: currentRoute,
                    onTap: () {
                      Navigator.of(context).pop();
                      Get.toNamed(Routes.tentang);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Divider(height: 1),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Text(
                      'MASTER DATA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                  DrawerItem(
                    icon: Icons.sell_outlined,
                    label: 'Periode',
                    route: Routes.masterPeriode,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.masterPeriode, label: 'Periode'),
                  ),
                  DrawerItem(
                    icon: Icons.menu_book_outlined,
                    label: 'Pelajaran',
                    route: Routes.masterPelajaran,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.masterPelajaran, label: 'Pelajaran'),
                  ),
                  DrawerItem(
                    icon: Icons.access_time_rounded,
                    label: 'Jam Pelajaran',
                    route: Routes.masterJam,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.masterJam, label: 'Jam Pelajaran'),
                  ),
                  DrawerItem(
                    icon: Icons.meeting_room_outlined,
                    label: 'Kelas',
                    route: Routes.masterKelas,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.masterKelas, label: 'Kelas'),
                  ),
                  DrawerItem(
                    icon: Icons.school_outlined,
                    label: 'Guru',
                    route: Routes.masterGuru,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.masterGuru, label: 'Guru'),
                  ),
                  DrawerItem(
                    icon: Icons.groups_outlined,
                    label: 'Siswa',
                    route: Routes.masterSiswa,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.masterSiswa, label: 'Siswa'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DrawerLogoutItem(currentRoute: currentRoute),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, {required String route, required String label}) {
    Navigator.of(context).pop();
    if (route == currentRoute) return;
    if (_builtRoutes.contains(route)) {
      Get.offAllNamed(route);
      return;
    }
    showComingSoon(label);
  }
}
