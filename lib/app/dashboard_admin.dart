import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/widgets/admin_drawer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const List<String> _dayLabels = ['min', 'sen', 'sel', 'rab', 'kam', 'jum', 'sab'];
const List<String> _monthNames = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Sunday that starts the week containing [date]. DateTime.weekday runs
/// Mon=1..Sun=7, so Sunday needs `% 7` to land on 0 instead of 7.
DateTime _startOfWeek(DateTime date) {
  final daysFromSunday = date.weekday % 7;
  return _dateOnly(date).subtract(Duration(days: daysFromSunday));
}

String _formatDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

class DashboardAdminController extends GetxController {
  SupabaseClient get _supabase => Supabase.instance.client;

  final Rx<DateTime> selectedDate = _dateOnly(DateTime.now()).obs;
  final RxInt weekDirection = 0.obs; // -1 prev, 1 next, drives slide animation

  final RxBool isLoadingProfile = true.obs;
  final RxBool isLoadingStats = true.obs;

  final RxString namaLengkap = 'Admin'.obs;
  final RxString jabatan = ''.obs;
  final RxString fotoUrl = ''.obs;

  final RxInt totalJadwal = 0.obs;
  final RxInt totalJurnalApproved = 0.obs;
  final RxInt totalApproval = 0.obs;
  final RxInt totalBelumInput = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _loadProfile();
    _loadStats();
  }

  List<DateTime> get weekDays {
    final start = _startOfWeek(selectedDate.value);
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  /// Month/year shown above the week strip, taken from the week's Thursday
  /// (index 4) so a week straddling two months resolves the same way ISO
  /// week numbering does.
  String get headerLabel {
    final anchor = weekDays[4];
    return '${_monthNames[anchor.month - 1]} ${anchor.year}';
  }

  void previousWeek() {
    weekDirection.value = -1;
    selectedDate.value = selectedDate.value.subtract(const Duration(days: 7));
    _loadStats();
  }

  void nextWeek() {
    weekDirection.value = 1;
    selectedDate.value = selectedDate.value.add(const Duration(days: 7));
    _loadStats();
  }

  void selectDate(DateTime date) {
    if (_isSameDay(date, selectedDate.value)) return;
    selectedDate.value = date;
    _loadStats();
  }

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
      namaLengkap.value = (nama == null || nama.isEmpty) ? 'Admin' : nama;
      jabatan.value = (row?['jabatan'] as String?)?.trim() ?? '';
      fotoUrl.value = (row?['foto_url'] as String?)?.trim() ?? '';
    } catch (_) {
      // Header falls back to defaults; not worth blocking the dashboard.
    } finally {
      isLoadingProfile.value = false;
    }
  }

  Future<void> _loadStats() async {
    isLoadingStats.value = true;
    final date = selectedDate.value;
    final dateStr = _formatDate(date);
    final weekday = date.weekday; // matches jadwal_mengajar.hari (1=Senin..7=Minggu)

    try {
      final periode = await _supabase
          .from('master_periode')
          .select('id')
          .eq('is_active', true)
          .maybeSingle();
      final periodeId = _asInt(periode?['id']);

      var jadwalQuery = _supabase
          .from('jadwal_mengajar')
          .select('id, guru_id')
          .eq('is_active', true)
          .or('and(tanggal.is.null,hari.eq.$weekday),tanggal.eq.$dateStr');
      if (periodeId != null) {
        jadwalQuery = jadwalQuery.eq('periode_id', periodeId);
      }
      final jadwalRows = await jadwalQuery as List;

      final guruIdsToday = <String>{};
      final jadwalGuruById = <int, String>{};
      for (final row in jadwalRows) {
        final id = _asInt(row['id']);
        final guruId = row['guru_id'] as String?;
        if (id != null && guruId != null) {
          guruIdsToday.add(guruId);
          jadwalGuruById[id] = guruId;
        }
      }

      final jurnalRows = await _supabase
          .from('jurnal_harian')
          .select('status, jadwal_id, jadwal_ids')
          .eq('tanggal', dateStr) as List;

      var approved = 0;
      var pending = 0;
      final guruSudahInput = <String>{};
      for (final row in jurnalRows) {
        switch (row['status'] as String?) {
          case 'approved':
            approved++;
          case 'pending':
            pending++;
        }

        final coveredJadwalIds = <int>{};
        final jadwalId = _asInt(row['jadwal_id']);
        if (jadwalId != null) coveredJadwalIds.add(jadwalId);
        final jadwalIds = row['jadwal_ids'];
        if (jadwalIds is List) {
          for (final v in jadwalIds) {
            final parsed = _asInt(v);
            if (parsed != null) coveredJadwalIds.add(parsed);
          }
        }
        for (final id in coveredJadwalIds) {
          final guruId = jadwalGuruById[id];
          if (guruId != null) guruSudahInput.add(guruId);
        }
      }

      totalJadwal.value = jadwalRows.length;
      totalJurnalApproved.value = approved;
      totalApproval.value = pending;
      totalBelumInput.value = guruIdsToday.difference(guruSudahInput).length;
    } catch (error) {
      Get.snackbar(
        'Gagal memuat data dashboard',
        '$error',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isLoadingStats.value = false;
    }
  }
}

class DashboardAdmin extends StatefulWidget {
  const DashboardAdmin({super.key});

  @override
  State<DashboardAdmin> createState() => _DashboardAdminState();
}

class _DashboardAdminState extends State<DashboardAdmin> {
  final DashboardAdminController controller = Get.put(DashboardAdminController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      drawer: const AdminDrawer(currentRoute: Routes.dashboardAdmin),
      appBar: _buildAppBar(context),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WeekSelector(controller: controller),
              const SizedBox(height: 24),
              _StatGrid(controller: controller),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: MainColor.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Obx(() {
        if (controller.isLoadingProfile.value) {
          return const _AppBarSkeleton();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.namaLengkap.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (controller.jabatan.value.isNotEmpty)
              Text(
                controller.jabatan.value,
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
          child: Obx(() => _UserAvatar(url: controller.fotoUrl.value)),
        ),
      ],
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

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.url});

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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({required this.controller});

  final DashboardAdminController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavArrow(icon: Icons.chevron_left_rounded, onTap: controller.previousWeek),
              Obx(
                () => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    controller.headerLabel,
                    key: ValueKey(controller.headerLabel),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MainColor.primaryColor,
                    ),
                  ),
                ),
              ),
              _NavArrow(icon: Icons.chevron_right_rounded, onTap: controller.nextWeek),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final days = controller.weekDays;
            final direction = controller.weekDirection.value;
            return ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(direction >= 0 ? 1 : -1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Row(
                  key: ValueKey(days.first),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 7; i++)
                      _DayCell(
                        date: days[i],
                        label: _dayLabels[i],
                        controller: controller,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MainColor.fourthColor.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: MainColor.primaryColor, size: 22),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.label,
    required this.controller,
  });

  final DateTime date;
  final String label;
  final DashboardAdminController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = _isSameDay(date, controller.selectedDate.value);
      final today = _isSameDay(date, _dateOnly(DateTime.now()));
      return GestureDetector(
        onTap: () => controller.selectDate(date),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? MainColor.primaryColor : Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? MainColor.primaryColor : Colors.transparent,
                shape: BoxShape.circle,
                border: (!selected && today)
                    ? Border.all(color: MainColor.thirdColor, width: 1.6)
                    : null,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _StatGrid extends StatefulWidget {
  const _StatGrid({required this.controller});

  final DashboardAdminController controller;

  @override
  State<_StatGrid> createState() => _StatGridState();
}

class _StatGridState extends State<_StatGrid> {
  @override
  Widget build(BuildContext context) {
    final cards = <_StatCardData>[
      _StatCardData(
        label: 'Jadwal',
        icon: Icons.calendar_today_rounded,
        value: widget.controller.totalJadwal,
        gradient: [MainColor.primaryColor, MainColor.secondaryColor],
      ),
      _StatCardData(
        label: 'Jurnal',
        icon: Icons.fact_check_rounded,
        value: widget.controller.totalJurnalApproved,
        gradient: [MainColor.secondaryColor, MainColor.thirdColor],
      ),
      _StatCardData(
        label: 'Approval',
        icon: Icons.hourglass_top_rounded,
        value: widget.controller.totalApproval,
        gradient: [
          Color.lerp(MainColor.thirdColor, MainColor.primaryColor, 0.35)!,
          MainColor.secondaryColor,
        ],
      ),
      _StatCardData(
        label: 'Belum Input',
        icon: Icons.person_off_rounded,
        value: widget.controller.totalBelumInput,
        gradient: [
          Color.lerp(MainColor.primaryColor, Colors.black, 0.22)!,
          Color.lerp(MainColor.secondaryColor, Colors.black, 0.1)!,
        ],
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        return _AnimatedEntrance(
          delay: Duration(milliseconds: 90 * index),
          child: _StatCard(
            data: cards[index],
            isLoading: widget.controller.isLoadingStats,
          ),
        );
      },
    );
  }
}

class _StatCardData {
  const _StatCardData({
    required this.label,
    required this.icon,
    required this.value,
    required this.gradient,
  });

  final String label;
  final IconData icon;
  final RxInt value;
  final List<Color> gradient;
}

class _AnimatedEntrance extends StatefulWidget {
  const _AnimatedEntrance({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.15),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data, required this.isLoading});

  final _StatCardData data;
  final RxBool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: data.gradient.last.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(data.icon, color: Colors.white.withValues(alpha: 0.9), size: 22),
          Obx(() {
            if (isLoading.value) {
              return const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              );
            }
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Text(
                '${data.value.value}',
                key: ValueKey(data.value.value),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            );
          }),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}
