import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/widgets/drawer_widgets.dart';

/// Sidebar for the guru role, styled to match [AdminDrawer] exactly (shared
/// logo header, [DrawerItem], [DrawerLogoutItem]). Dashboard, Jadwal
/// Mengajar, Jurnal Mengajar, and Tentang Aplikasi are built — Statistik
/// shows the shared "coming soon" snackbar until a later prompt builds it
/// (see design/prompt/014_guru.md §2.1/§10, design/prompt/015_jadwal_guru.md).
class GuruDrawer extends StatelessWidget {
  const GuruDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  static const _builtRoutes = {Routes.dashboardGuru, Routes.guruJadwal, Routes.guruJurnal};

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
                    route: Routes.dashboardGuru,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.dashboardGuru, label: 'Dashboard'),
                  ),
                  DrawerItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Jadwal Mengajar',
                    route: Routes.guruJadwal,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.guruJadwal, label: 'Jadwal Mengajar'),
                  ),
                  DrawerItem(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Jurnal Mengajar',
                    route: Routes.guruJurnal,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.guruJurnal, label: 'Jurnal Mengajar'),
                  ),
                  DrawerItem(
                    icon: Icons.insert_chart_outlined_rounded,
                    label: 'Statistik',
                    route: Routes.guruStatistik,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(context, route: Routes.guruStatistik, label: 'Statistik'),
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
