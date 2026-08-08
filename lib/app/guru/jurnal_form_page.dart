import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/guru/guru_activity.dart';
import 'package:jurnal_mengajar/app/guru/jurnal_form_data.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Real "Isi Jurnal" / "Edit Jurnal" form (design/prompt/018_isi_jurnal.md),
/// replacing the 014_guru.md placeholder stub. The guru fills in materi,
/// per-student attendance (H/S/I/A), catatan, and camera photos for the tapped
/// jadwal, then submits — INSERT for a fresh entry or UPDATE+reset for a
/// rejected/pending resubmission.
class JurnalFormPage extends StatefulWidget {
  const JurnalFormPage({super.key, required this.jadwal, this.jurnalId});

  final GuruJadwalItem jadwal;
  final int? jurnalId;

  @override
  State<JurnalFormPage> createState() => _JurnalFormPageState();
}

class _JurnalFormPageState extends State<JurnalFormPage> {
  SupabaseClient get _supabase => Supabase.instance.client;

  bool get _isEdit => widget.jurnalId != null;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _materiController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController(text: '-');

  bool _isLoading = true;
  bool _isSaving = false;

  List<SiswaItem> _roster = [];
  final Map<int, String> _attendance = {}; // siswaId -> H/S/I/A
  List<JurnalPhotoDraft> _photos = [];
  final Set<int> _initialPhotoIds = {};

  bool _isRejected = false;
  String _catatanAdmin = '';

  String get _jamLabel {
    final j = widget.jadwal.jamKeList;
    if (j.isEmpty) return '-';
    return j.length == 1 ? 'Jam ${j.first}' : 'Jam ${j.join(', ')}';
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _materiController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _isLoading = true);
    try {
      final roster = await loadKelasSiswa(_supabase, widget.jadwal.kelasId);
      for (final s in roster) {
        _attendance[s.id] = 'H';
      }

      if (_isEdit) {
        final draft = await loadExistingJurnal(_supabase, widget.jurnalId!);
        _materiController.text = draft.materi;
        _catatanController.text = draft.catatan.isEmpty ? '-' : draft.catatan;
        for (final entry in draft.absensi.entries) {
          _attendance[entry.key] = entry.value;
        }
        _photos = [...draft.photos];
        _initialPhotoIds.addAll(draft.photos.where((p) => p.dbId != null).map((p) => p.dbId!));
        _isRejected = draft.status == 'rejected';
        _catatanAdmin = draft.catatanAdmin ?? '';
      }

      _roster = roster;
    } catch (error) {
      showMasterDataError('Gagal memuat data jurnal', error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      if (mounted) setState(() => _photos.add(JurnalPhotoDraft.fromBytes(bytes)));
    } catch (error) {
      if (mounted) showMasterDataError('Kamera gagal dibuka', error);
    }
  }

  void _setAttendance(int siswaId, String status) {
    setState(() => _attendance[siswaId] = status);
  }

  void _hadirSemua() {
    setState(() {
      for (final s in _roster) {
        _attendance[s.id] = 'H';
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_photos.length < 3) {
      showMasterDataError('Foto belum lengkap', 'Minimal 3 foto kegiatan wajib dilampirkan.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final nonHadir = <(int, String)>[
        for (final s in _roster)
          if (_attendance[s.id] == 'S')
            (s.id, 'Sakit')
          else if (_attendance[s.id] == 'I')
            (s.id, 'Izin')
          else if (_attendance[s.id] == 'A') (s.id, 'Alpha'),
      ];

      final kept = _photos.where((p) => !p.isNew && p.dbId != null).map((p) => p.dbId!).toSet();
      final removed = _initialPhotoIds.difference(kept).toList();
      final newBytes = _photos.where((p) => p.isNew).map((p) => p.bytes!).toList();

      await submitJurnal(
        supabase: _supabase,
        isEdit: _isEdit,
        jadwalId: widget.jadwal.id,
        tanggal: widget.jadwal.tanggal,
        kelasId: widget.jadwal.kelasId,
        materi: _materiController.text.trim(),
        catatan: _catatanController.text.trim(),
        nonHadir: nonHadir,
        newPhotoBytes: newBytes,
        keptPhotoIds: kept.toList(),
        removedPhotoIds: removed,
        jurnalId: widget.jurnalId,
      );

      // Get.back() before the snackbar: GetX's Get.back() no-ops (just
      // dismisses the snackbar) while a snackbar is open, so calling
      // showMasterDataSuccess() first would silently swallow the navigation.
      Get.back();
      showMasterDataSuccess(_isEdit ? 'Jurnal diperbarui.' : 'Jurnal tersimpan.');
    } catch (error) {
      showMasterDataError('Gagal menyimpan jurnal', error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: _isEdit ? 'Edit Jurnal' : 'Isi Jurnal',
        onBack: () => Get.back(),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isRejected) ...[
                        _RejectedBanner(catatanAdmin: _catatanAdmin),
                        const SizedBox(height: 20),
                      ],
                      _ReadOnlyField(label: 'Tanggal', value: formatDateLong(widget.jadwal.tanggal)),
                      const SizedBox(height: 16),
                      _ReadOnlyField(label: 'Kelas', value: widget.jadwal.kelas),
                      const SizedBox(height: 16),
                      _buildJamSection(),
                      const SizedBox(height: 16),
                      _ReadOnlyField(label: 'Pelajaran', value: widget.jadwal.pelajaran),
                      const SizedBox(height: 20),
                      MasterDataTextField(
                        label: 'Materi',
                        controller: _materiController,
                        hint: 'Tuliskan materi pembelajaran',
                        maxLines: 3,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Materi wajib diisi' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildAbsensiSection(),
                      const SizedBox(height: 20),
                      MasterDataTextField(
                        label: 'Catatan',
                        controller: _catatanController,
                        hint: 'Catatan pembelajaran',
                        maxLines: 5,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Catatan wajib diisi' : null,
                      ),
                      const SizedBox(height: 20),
                      _buildFotoSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Material(
                  color: MainColor.primaryColor,
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _isSaving ? null : _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      // Row (not Center) so this shrink-wraps vertically: Center/Align
                      // claim the full bounded max height Scaffold offers the
                      // bottomNavigationBar slot, which blows this button up to fill
                      // the screen.
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                )
                              : const Text(
                                  'Simpan',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildJamSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Jam Ke', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var jamKe = 1; jamKe <= 10; jamKe++)
              _JamPillReadOnly(
                jamKe: jamKe,
                selected: widget.jadwal.jamKeList.contains(jamKe),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Waktu: ${widget.jadwal.timeRange}   ($_jamLabel)',
          style: const TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildAbsensiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Absensi (H, S, I, A)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
            TextButton(
              onPressed: _hadirSemua,
              style: TextButton.styleFrom(
                foregroundColor: MainColor.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Hadir Semua', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final s in _roster)
          _AbsensiRow(
            nama: s.nama,
            status: _attendance[s.id] ?? 'H',
            onChanged: (v) => _setAttendance(s.id, v),
          ),
      ],
    );
  }

  Widget _buildFotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Kegiatan (Minimal 3 Foto)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (final photo in _photos) _FotoThumb(photo: photo, onRemove: () => _removePhoto(photo)),
            _FotoAddTile(onTap: _capturePhoto),
          ],
        ),
      ],
    );
  }

  void _removePhoto(JurnalPhotoDraft photo) {
    setState(() => _photos.remove(photo));
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: masterDataFieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        ),
      ],
    );
  }
}

class _JamPillReadOnly extends StatelessWidget {
  const _JamPillReadOnly({required this.jamKe, required this.selected});

  final int jamKe;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? MainColor.primaryColor : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? MainColor.primaryColor : Colors.black12),
      ),
      child: Text(
        '$jamKe',
        style: TextStyle(
          color: selected ? Colors.white : Colors.black26,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _AbsensiRow extends StatelessWidget {
  const _AbsensiRow({required this.nama, required this.status, required this.onChanged});

  final String nama;
  final String status;
  final ValueChanged<String> onChanged;

  static const _options = ['H', 'S', 'I', 'A'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(nama, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, color: Colors.black87)),
          ),
          for (final o in _options)
            GestureDetector(
              onTap: () => onChanged(o),
              child: Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(left: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status == o ? MainColor.primaryColor : masterDataFieldFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: status == o ? Colors.white : Colors.black54,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FotoThumb extends StatelessWidget {
  const _FotoThumb({required this.photo, required this.onRemove});

  final JurnalPhotoDraft photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: photo.isNew
              ? Image.memory(photo.bytes!, fit: BoxFit.cover)
              : Image.network(photo.url ?? '', fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: masterDataFieldFill,
                    child: const Icon(Icons.image_not_supported_outlined, color: Colors.black26),
                  )),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _FotoAddTile extends StatelessWidget {
  const _FotoAddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: masterDataFieldFill,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_rounded, color: MainColor.primaryColor, size: 28),
            const SizedBox(height: 6),
            const Text('Ambil Foto',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _RejectedBanner extends StatelessWidget {
  const _RejectedBanner({required this.catatanAdmin});

  final String catatanAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Jurnal ditolak, silahkan diperbarui',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Catatan Admin:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              catatanAdmin.isEmpty ? '-' : catatanAdmin,
              style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
