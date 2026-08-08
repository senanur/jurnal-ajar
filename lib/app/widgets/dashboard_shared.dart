import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';

/// Profile-avatar action shared by both dashboards (admin & guru).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.person_rounded, color: Colors.white, size: 24)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.person_rounded, color: Colors.white, size: 24),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                );
              },
            ),
    );
  }
}

class _AppBarSkeleton extends StatelessWidget {
  const _AppBarSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bar(140, 14),
        const SizedBox(height: 6),
        bar(90, 11),
      ],
    );
  }
}

/// AppBar content (nama+jabatan title column + profile avatar action) shared
/// verbatim by both dashboards so they can never drift apart. The leading
/// hamburger is injected automatically by the Scaffold's drawer.
class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({
    super.key,
    required this.namaLengkap,
    required this.jabatan,
    required this.fotoUrl,
    required this.isLoadingProfile,
  });

  final RxString namaLengkap;
  final RxString jabatan;
  final RxString fotoUrl;
  final RxBool isLoadingProfile;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: MainColor.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Obx(() {
        if (isLoadingProfile.value) {
          return const _AppBarSkeleton();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              namaLengkap.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            if (jabatan.value.isNotEmpty)
              Text(
                jabatan.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
          ],
        );
      }),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Obx(() => UserAvatar(url: fotoUrl.value)),
        ),
      ],
    );
  }
}
