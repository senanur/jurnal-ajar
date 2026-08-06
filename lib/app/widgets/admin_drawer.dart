import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sidebar shared by every admin page. Only [Routes.dashboardAdmin] has a real
/// destination today; the rest are wired up as menu entries per the approved
/// drawer spec but show a "coming soon" snackbar until their pages exist.
class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  static const _placeholderRoute = '#placeholder';

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
  };

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    route: Routes.dashboardAdmin,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: Routes.dashboardAdmin,
                      label: 'Dashboard',
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Jurnal Mengajar',
                    route: Routes.masterJurnal,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: Routes.masterJurnal,
                      label: 'Jurnal Mengajar',
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Jadwal Mengajar',
                    route: Routes.masterJadwal,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: Routes.masterJadwal,
                      label: 'Jadwal Mengajar',
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Pengaturan',
                    route: _placeholderRoute,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: _placeholderRoute,
                      label: 'Pengaturan',
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Tentang Aplikasi',
                    route: _placeholderRoute,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: _placeholderRoute,
                      label: 'Tentang Aplikasi',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Divider(height: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
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
                  _DrawerItem(
                    icon: Icons.sell_outlined,
                    label: 'Periode',
                    route: Routes.masterPeriode,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: Routes.masterPeriode,
                      label: 'Periode',
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.menu_book_outlined,
                    label: 'Pelajaran',
                    route: Routes.masterPelajaran,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: Routes.masterPelajaran,
                      label: 'Pelajaran',
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.access_time_rounded,
                    label: 'Jam Pelajaran',
                    route: Routes.masterJam,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: Routes.masterJam,
                      label: 'Jam Pelajaran',
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.meeting_room_outlined,
                    label: 'Kelas',
                    route: Routes.masterKelas,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: Routes.masterKelas,
                      label: 'Kelas',
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.school_outlined,
                    label: 'Guru',
                    route: Routes.masterGuru,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: Routes.masterGuru,
                      label: 'Guru',
                    ),
                  ),
                  _DrawerItem(
                    icon: Icons.groups_outlined,
                    label: 'Siswa',
                    route: Routes.masterSiswa,
                    currentRoute: currentRoute,
                    onTap: () => _handleTap(
                      context,
                      route: Routes.masterSiswa,
                      label: 'Siswa',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _DrawerItem(
                icon: Icons.logout_rounded,
                label: 'Keluar',
                route: _placeholderRoute,
                currentRoute: currentRoute,
                iconColor: Colors.red.shade400,
                textColor: Colors.red.shade400,
                onTap: () => _confirmLogout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Row(
        children: [
          Image.asset('assets/image/LogoJr.png', width: 40, fit: BoxFit.contain),
          const SizedBox(width: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
                height: 1.25,
              ),
              children: [
                const TextSpan(text: 'Jurnal\n'),
                TextSpan(
                  text: 'Mengajar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: MainColor.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(
    BuildContext context, {
    required String route,
    required String label,
  }) {
    Navigator.of(context).pop();
    if (route == currentRoute) return;
    if (_builtRoutes.contains(route)) {
      Get.offAllNamed(route);
      return;
    }
    Get.snackbar(
      label,
      'Halaman ini akan segera hadir.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: MainColor.primaryColor,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  void _confirmLogout(BuildContext context) {
    Navigator.of(context).pop();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda perlu login kembali untuk mengakses dashboard.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await Supabase.instance.client.auth.signOut();
              Get.offAllNamed(Routes.login);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  bool get _selected => route == currentRoute;

  @override
  Widget build(BuildContext context) {
    final Color fg = _selected
        ? MainColor.primaryColor
        : (textColor ?? Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _selected
                  ? MainColor.fourthColor.withValues(alpha: 0.45)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: iconColor ?? fg),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: _selected ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                    ),
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
