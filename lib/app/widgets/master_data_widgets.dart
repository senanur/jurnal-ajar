import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';

const Color masterDataBackground = Color(0xFFF3F6FB);
const Color masterDataFieldFill = Color(0xFFF0F3F8);

/// Consistent AppBar used by every master-data page (list, add, edit): back
/// control on the left, one optional trailing action (add on lists, delete
/// on edit forms) — never both, so the header never has to vary in shape.
PreferredSizeWidget masterDataAppBar({
  required String title,
  required VoidCallback onBack,
  VoidCallback? onAdd,
  VoidCallback? onDelete,
}) {
  return AppBar(
    backgroundColor: MainColor.primaryColor,
    foregroundColor: Colors.white,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: onBack,
    ),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
    ),
    actions: [
      if (onAdd != null)
        IconButton(
          icon: const Icon(Icons.add_circle_rounded, size: 28),
          onPressed: onAdd,
        ),
      if (onDelete != null)
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: onDelete,
        ),
    ],
  );
}

class MasterDataSearchField extends StatelessWidget {
  const MasterDataSearchField({
    super.key,
    required this.controller,
    this.hint = 'Pencarian',
  });

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        suffixIcon: Icon(Icons.search_rounded, color: MainColor.primaryColor),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: MainColor.primaryColor, width: 1.4),
        ),
      ),
    );
  }
}

/// Single alternating-color row shared by every master-data list (Periode,
/// Kelas, Pelajaran, Jam Pelajaran, Siswa, Guru) so none of them drift apart
/// visually. `filled` alternates primary/soft background per item index.
class MasterDataListTile extends StatelessWidget {
  const MasterDataListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailingChip,
    required this.filled,
    this.onTap,
    this.showChevron = true,
    this.trailingWidget,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? trailingChip;
  final bool filled;
  /// Null makes the row display-only (no ripple, no tap) — used for the
  /// read-only jadwal/jurnal rows on the Guru detail page.
  final VoidCallback? onTap;
  final bool showChevron;
  /// Fully replaces the trailing chip+chevron area when set (e.g. the status
  /// icon + attendance summary on Guru detail's jurnal rows).
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    final Color bg = filled
        ? MainColor.primaryColor
        : MainColor.fourthColor.withValues(alpha: 0.5);
    final Color fg = filled ? Colors.white : MainColor.primaryColor;
    final Color fgSub = filled
        ? Colors.white.withValues(alpha: 0.85)
        : MainColor.primaryColor.withValues(alpha: 0.7);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: fgSub),
                  ),
                ],
              ],
            ),
          ),
          ?trailingWidget,
          if (trailingWidget == null && trailingChip != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (filled ? Colors.white : MainColor.primaryColor)
                    .withValues(alpha: filled ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trailingChip!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (trailingWidget == null && showChevron)
            Icon(Icons.chevron_right_rounded, color: fg),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: onTap == null
            ? content
            : InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onTap,
                child: content,
              ),
      ),
    );
  }
}


/// Staggered fade+slide entrance, reused for every list so items animate in
/// consistently regardless of which master-data entity is showing.
class MasterDataEntrance extends StatefulWidget {
  const MasterDataEntrance({super.key, required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<MasterDataEntrance> createState() => _MasterDataEntranceState();
}

class _MasterDataEntranceState extends State<MasterDataEntrance> {
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
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class MasterDataEmptyState extends StatelessWidget {
  const MasterDataEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black45, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class MasterDataTextField extends StatelessWidget {
  const MasterDataTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
            filled: true,
            fillColor: masterDataFieldFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: MainColor.primaryColor, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class MasterDataDropdown<T> extends StatelessWidget {
  const MasterDataDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hint = 'Pilih',
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  /// Null disables the dropdown (used for the locked-field states on the
  /// Jadwal Mengajar form once its journal has already been filled).
  final ValueChanged<T?>? onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: masterDataFieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<T>(
              initialValue: value,
              isExpanded: true,
              hint: Text(hint, style: const TextStyle(color: Colors.black38, fontSize: 14)),
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: MainColor.primaryColor),
              items: items
                  .map((e) => DropdownMenuItem<T>(
                        value: e,
                        child: Text(itemLabel(e), style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: onChanged,
              validator: (v) => v == null ? 'Wajib dipilih' : null,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MasterDataCheckboxRow extends StatelessWidget {
  const MasterDataCheckboxRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? MainColor.primaryColor : Colors.transparent,
                border: Border.all(color: MainColor.primaryColor, width: 1.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: value
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom "Simpan" bar shared by every add/edit form.
class MasterDataSaveBar extends StatelessWidget {
  const MasterDataSaveBar({
    super.key,
    required this.isSaving,
    required this.onSave,
    this.label = 'Simpan',
  });

  final bool isSaving;
  final VoidCallback onSave;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: MainColor.primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: MainColor.thirdColor,
          borderRadius: BorderRadius.circular(30),
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: isSaving ? null : onSave,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              // Row (not Center) so this shrink-wraps vertically: Center/Align
              // claim the full bounded max height Scaffold offers the
              // bottomNavigationBar slot, which blows this button up to fill
              // the screen. Row only expands on the main (horizontal) axis.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showMasterDataError(String title, Object error) {
  Get.snackbar(
    title,
    '$error',
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: Colors.red.shade600,
    colorText: Colors.white,
    margin: const EdgeInsets.all(16),
  );
}

void showMasterDataSuccess(String message) {
  Get.snackbar(
    'Berhasil',
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: MainColor.primaryColor,
    colorText: Colors.white,
    margin: const EdgeInsets.all(16),
  );
}
