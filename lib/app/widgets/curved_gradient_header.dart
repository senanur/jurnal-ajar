import 'package:flutter/material.dart';
import 'package:jurnal_mengajar/app/color.dart';

/// Curved primary→secondary gradient hero sitting behind a header (usually a
/// [WeekDateStrip]) and a search field, with the rest of the page scrolling
/// below on the plain background. Shared by every admin list page that uses
/// a date filter (Jadwal Mengajar, Jurnal Mengajar) so they stay visually
/// identical.
class CurvedGradientListBody extends StatelessWidget {
  const CurvedGradientListBody({
    super.key,
    required this.header,
    this.searchField,
    required this.child,
    this.heroHeight = 230,
  });

  final Widget header;
  final Widget? searchField;
  final Widget child;
  final double heroHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: heroHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [MainColor.primaryColor, MainColor.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: header),
            if (searchField != null) ...[
              const SizedBox(height: 16),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: searchField),
            ],
            const SizedBox(height: 16),
            Expanded(child: child),
          ],
        ),
      ],
    );
  }
}
