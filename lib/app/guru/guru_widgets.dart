import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/guru/detail_jurnal_page.dart';
import 'package:jurnal_mengajar/app/guru/guru_activity.dart';
import 'package:jurnal_mengajar/app/guru/jurnal_form_page.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What the shared detail popup should offer for a jadwal. Shared by
/// Dashboard Guru and Halaman Jadwal Mengajar (design/prompt/015_jadwal_guru.md
/// §11.2) so the two screens can never resolve popup state differently.
enum JournalAction { isi, edit, none }

JournalAction actionFor(GuruJadwalItem jadwal) {
  switch (jadwal.jurnalStatus) {
    case null:
      return JournalAction.isi;
    case 'approved':
      return JournalAction.none;
    case 'pending' || 'rejected':
      return JournalAction.edit;
    default:
      // Safety net: any unknown status is treated as a fresh entry.
      return JournalAction.isi;
  }
}

/// §4.9 anti-cheat gate: true once the class's first jam has started.
bool isJadwalTimeReached(GuruJadwalItem jadwal) {
  final parts = jadwal.timeRange.split('-');
  if (parts.length != 2) return true; // no parseable start → don't block
  final startRaw = parts.first.trim();
  final hm = startRaw.split('.');
  if (hm.length != 2) return true;
  final hh = int.tryParse(hm[0]);
  final mm = int.tryParse(hm[1]);
  if (hh == null || mm == null) return true;
  final d = jadwal.tanggal;
  final threshold = DateTime(d.year, d.month, d.day, hh, mm);
  final now = DateTime.now();
  return now.isAfter(threshold) || now.isAtSameMomentAs(threshold);
}

void showWaktuBelumTiba(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Waktu Belum Tiba'),
      content: const Text('Anda belum bisa mengisi jurnal. Waktu pelaksanaan jadwal kelas belum tiba.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          style: TextButton.styleFrom(foregroundColor: MainColor.primaryColor),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Opens the shared jadwal/jurnal detail popup for [jadwal] and, depending on
/// what the guru taps, runs the §4.9 gate and/or navigates to the
/// [JurnalFormPage] stub. [onRefresh] re-runs after returning from the form so
/// the caller's list reflects any change. Shared by Dashboard Guru and
/// Halaman Jadwal Mengajar (design/prompt/015_jadwal_guru.md §11.2).
Future<void> openJadwalDetail(
  BuildContext context,
  GuruJadwalItem jadwal, {
  required VoidCallback onRefresh,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => JadwalJurnalDetailSheet(jadwal: jadwal, action: actionFor(jadwal)),
  );
  if (action == null || !context.mounted) return;

  if (action == 'detail') {
    // Approved jurnal: open the read-only Detail Jurnal screen.
    final jurnalId = jadwal.jurnalId;
    if (jurnalId != null) {
      await Get.to(() => DetailJurnalPage(jurnalId: jurnalId));
    }
    return;
  }

  if (action == 'edit') {
    await _openForm(context, jadwal, jurnalId: jadwal.jurnalId, onRefresh: onRefresh);
    return;
  }
  // action == 'isi'
  if (isJadwalTimeReached(jadwal)) {
    await _openForm(context, jadwal, onRefresh: onRefresh);
  } else if (context.mounted) {
    showWaktuBelumTiba(context);
  }
}

Future<void> _openForm(
  BuildContext context,
  GuruJadwalItem jadwal, {
  int? jurnalId,
  required VoidCallback onRefresh,
}) async {
  await Get.to(() => JurnalFormPage(jadwal: jadwal, jurnalId: jurnalId));
  onRefresh();
}

/// Two-state jadwal card (design/prompt/014_guru.md §4.3/§4.5), shared by
/// Dashboard Guru and Halaman Jadwal Mengajar.
class JadwalCard extends StatelessWidget {
  const JadwalCard({super.key, required this.item, required this.onTap});

  final GuruJadwalItem item;
  final VoidCallback onTap;

  String get _jamLabel {
    final j = item.jamKeList;
    if (j.isEmpty) return '-';
    return j.length == 1 ? 'Jam ke ${j.first}' : 'Jam ke ${j.join('-')}';
  }

  @override
  Widget build(BuildContext context) {
    final filled = !item.sudahDiisi;
    final bg = filled ? MainColor.primaryColor : MainColor.fourthColor.withValues(alpha: 0.5);
    final fg = filled ? Colors.white : MainColor.primaryColor;
    final fgSub = filled ? Colors.white.withValues(alpha: 0.85) : MainColor.primaryColor.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.pelajaran,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.kelas,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: fgSub),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: fgSub),
                          const SizedBox(width: 4),
                          Text(
                            _jamLabel,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fgSub),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.timeRange,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  item.sudahDiisi ? Icons.check_circle_rounded : Icons.more_horiz_rounded,
                  color: item.sudahDiisi ? Colors.greenAccent.shade400 : fg.withValues(alpha: 0.85),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three-state status-colored journal card (design/prompt/014_guru.md
/// §4.4/§4.6: pending → primary-filled + hourglass, approved → green tint +
/// check-circle, rejected → orange tint + cancel), shared by Dashboard Guru
/// and Halaman Jurnal Mengajar (design/prompt/017_jurnal_guru.md §11.2).
class JurnalCard extends StatelessWidget {
  const JurnalCard({super.key, required this.item, required this.onTap});

  final GuruJurnalItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final Color fgSub;
    late final Color badgeBg;
    late final Color badgeFg;
    late final String badgeText;

    switch (item.status) {
      case 'approved':
        bg = Colors.green.withValues(alpha: 0.08);
        fg = Colors.black87;
        fgSub = Colors.black54;
        badgeBg = Colors.green.withValues(alpha: 0.18);
        badgeFg = Colors.green.shade700;
        badgeText = 'APPROVED';
      case 'rejected':
        bg = Colors.orange.withValues(alpha: 0.12);
        fg = Colors.black87;
        fgSub = Colors.black54;
        badgeBg = Colors.orange.withValues(alpha: 0.22);
        badgeFg = Colors.orange.shade800;
        badgeText = 'REJECTED';
      default:
        bg = MainColor.primaryColor;
        fg = Colors.white;
        fgSub = Colors.white.withValues(alpha: 0.85);
        badgeBg = Colors.white.withValues(alpha: 0.25);
        badgeFg = Colors.white;
        badgeText = 'PENDING';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.kelas,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.pelajaran,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: fgSub),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ketidakhadiran - S:${item.sakit} I:${item.izin} A:${item.alpha}',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fgSub),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: badgeFg,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _statusIcon(item.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22);
      case 'rejected':
        return Icon(Icons.cancel_rounded, color: Colors.red.shade400, size: 22);
      default:
        return Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade300, size: 20);
    }
  }
}

/// Shared three-state (Isi Jurnal / Edit Jurnal / read-only) detail popup
/// (design/prompt/014_guru.md §2.3/§4.8), shared by Dashboard Guru and
/// Halaman Jadwal Mengajar.
class JadwalJurnalDetailSheet extends StatelessWidget {
  const JadwalJurnalDetailSheet({super.key, required this.jadwal, required this.action});

  final GuruJadwalItem jadwal;
  final JournalAction action;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.5,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      jadwal.pelajaran,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      jadwal.kelas,
                      style: TextStyle(
                        fontSize: 13,
                        color: MainColor.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    GuruInfoRow(label: 'Tanggal', value: formatDateLong(jadwal.tanggal)),
                    const SizedBox(height: 10),
                    GuruInfoRow(label: 'Jam', value: '${jadwal.timeRange}  (Jam ke ${jadwal.jamKeList.join('-')})'),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    Text(
                      _statusText(),
                      style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: switch (action) {
                JournalAction.none => GuruActionButton(
                    label: 'Lihat Detail',
                    onPressed: () => Navigator.of(context).pop('detail'),
                  ),
                JournalAction.isi => GuruActionButton(
                    label: 'Isi Jurnal',
                    onPressed: () => Navigator.of(context).pop('isi'),
                  ),
                JournalAction.edit => GuruActionButton(
                    label: 'Edit Jurnal',
                    onPressed: () => Navigator.of(context).pop('edit'),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  String _statusText() {
    switch (action) {
      case JournalAction.isi:
        return 'Jurnal dari jadwal ini belum diisi.';
      case JournalAction.edit:
        return 'Jurnal dari jadwal ini sudah diisi. Anda masih dapat memperbaiki sebelum diperiksa oleh admin.';
      case JournalAction.none:
        return 'Jurnal sudah diisi dan divalidasi oleh admin.';
    }
  }
}

class GuruInfoRow extends StatelessWidget {
  const GuruInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black54),
          ),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.4)),
        ),
      ],
    );
  }
}

class GuruActionButton extends StatelessWidget {
  const GuruActionButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MainColor.primaryColor,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reads `jurnal_foto` URLs for a journal, ascending by id (insertion order).
Future<List<String>> loadJurnalFotoUrls(SupabaseClient supabase, int jurnalId) async {
  final rows = await supabase
      .from('jurnal_foto')
      .select('url')
      .eq('jurnal_id', jurnalId)
      .order('id') as List;
  return rows.map((r) => ((r as Map<String, dynamic>)['url'] as String?) ?? '').toList();
}

/// Horizontal swipeable photo gallery with a page-dot indicator
/// (design/prompt/019_detail_jurnal.md §11.2). Shared by the guru Detail Jurnal
/// screen and the admin's JurnalDetailSheet photo section.
class JurnalFotoGallery extends StatefulWidget {
  const JurnalFotoGallery({super.key, required this.urls});

  final List<String> urls;

  @override
  State<JurnalFotoGallery> createState() => _JurnalFotoGalleryState();
}

class _JurnalFotoGalleryState extends State<JurnalFotoGallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(color: const Color(0xFFF0F3F8), borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: Colors.black26, size: 36),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) => Image.network(
                widget.urls[index],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFF0F3F8),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.black26, size: 36),
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFF0F3F8),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2.4),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.urls.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == _page ? 18 : 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _page ? MainColor.primaryColor : Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}