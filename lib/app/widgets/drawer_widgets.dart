import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/auth_session.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "Coming soon" snackbar shared by every unbuilt drawer item / "Semua" link
/// (admin's unbuilt entries and the guru's Jadwal/Jurnal/Statistik items).
void showComingSoon(String label) {
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

/// Logo header shared by both drawers so they stay pixel-identical.
class DrawerLogoHeader extends StatelessWidget {
  const DrawerLogoHeader({super.key});

  @override
  Widget build(BuildContext context) {
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
}

/// Single sidebar entry shared by both drawers.
class DrawerItem extends StatelessWidget {
  const DrawerItem({
    super.key,
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
    final Color fg = _selected ? MainColor.primaryColor : (textColor ?? Colors.black87);

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
              color: _selected ? MainColor.fourthColor.withValues(alpha: 0.45) : Colors.transparent,
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

/// Shared logout row + confirm dialog, identical across both drawers.
class DrawerLogoutItem extends StatelessWidget {
  const DrawerLogoutItem({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return DrawerItem(
      icon: Icons.logout_rounded,
      label: 'Keluar',
      route: Routes.login,
      currentRoute: currentRoute,
      iconColor: Colors.red.shade400,
      textColor: Colors.red.shade400,
      onTap: () => confirmLogout(context),
    );
  }
}

Future<void> confirmLogout(BuildContext context) {
  Navigator.of(context).pop();
  return showDialog<void>(
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
            await NotificationService.to.deleteDeviceToken();
            await Supabase.instance.client.auth.signOut();
            AuthSession.to.clear();
            Get.offAllNamed(Routes.login);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
          child: const Text('Keluar'),
        ),
      ],
    ),
  );
}
