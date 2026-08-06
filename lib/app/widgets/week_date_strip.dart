import 'package:flutter/material.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';

/// Sun-Sat week strip with month/year header and prev/next navigation.
/// Shared by the admin dashboard and the guru detail page so both look and
/// animate identically. Stateless by design: the caller owns the selected
/// date and wraps this in `Obx` (or `setState`) to react to changes.
class WeekDateStrip extends StatelessWidget {
  const WeekDateStrip({
    super.key,
    required this.weekDays,
    required this.selectedDate,
    required this.weekDirection,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectDate,
  });

  final List<DateTime> weekDays;
  final DateTime selectedDate;
  final int weekDirection; // -1 prev, 1 next, drives the slide direction
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDate;

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
              _NavArrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
              AnimatedSwitcher(
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
                  monthYearLabel(weekDays),
                  key: ValueKey(monthYearLabel(weekDays)),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: MainColor.primaryColor,
                  ),
                ),
              ),
              _NavArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
            ],
          ),
          const SizedBox(height: 12),
          ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(weekDirection >= 0 ? 1 : -1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Row(
                key: ValueKey(weekDays.first),
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: _DayCell(
                        date: weekDays[i],
                        label: dayLabelsShort[i],
                        selected: isSameDay(weekDays[i], selectedDate),
                        onTap: () => onSelectDate(weekDays[i]),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = isSameDay(date, dateOnly(DateTime.now()));
    return GestureDetector(
      onTap: onTap,
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
  }
}
