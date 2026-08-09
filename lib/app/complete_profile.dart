import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jurnal_mengajar/app/auth_session.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _uploadAccent = Color(0xFFEAD6C4);
const Color _fieldFill = Color(0xFFF0F3F8);

/// Shown once, right after a first-time Google sign-in, before the caller
/// reaches a dashboard. `handle_new_user()` already inserts a `profiles` row
/// for every new auth user with placeholder/blank defaults (see login.dart's
/// `_routeByRole`), so this page only ever UPDATEs that row — it never
/// inserts one itself.
class CompleteProfileController extends GetxController {
  final namaLengkapController = TextEditingController();
  final jabatanController = TextEditingController();
  final alamatController = TextEditingController();
  final noTelpController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isLoadingInitial = true.obs;

  /// Bytes of a newly picked photo. Null means "keep whatever foto_url is
  /// already on the row" (e.g. the avatar Google supplied at sign-in).
  final Rxn<Uint8List> photoBytes = Rxn<Uint8List>();
  String _existingFotoUrl = '';
  String _role = 'guru';

  SupabaseClient get _supabase => Supabase.instance.client;
  String get existingFotoUrl => _existingFotoUrl;

  @override
  void onInit() {
    super.onInit();
    _loadInitial();
  }

  /// Prefers the profile row handed over via route arguments (login.dart /
  /// splash.dart already fetched it to make the routing decision), falling
  /// back to a fresh select only if this page was reached another way.
  Future<void> _loadInitial() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      Get.offAllNamed(Routes.login);
      return;
    }

    var profile = Get.arguments as Map<String, dynamic>?;
    profile ??=
        await _supabase
            .from('profiles')
            .select('role, nama_lengkap, jabatan, alamat, no_telp, foto_url')
            .eq('id', user.id)
            .maybeSingle();

    _role = (profile?['role'] as String?) ?? 'guru';
    _existingFotoUrl = (profile?['foto_url'] as String?) ?? '';

    final namaLengkap = (profile?['nama_lengkap'] as String?) ?? '';
    final jabatan = (profile?['jabatan'] as String?) ?? '';
    // 'User Baru' / 'Guru Pengajar' are the trigger's own placeholders, not
    // real data the user entered — don't pre-fill the form with them.
    namaLengkapController.text = namaLengkap == 'User Baru' ? '' : namaLengkap;
    jabatanController.text = jabatan == 'Guru Pengajar' ? '' : jabatan;
    alamatController.text = (profile?['alamat'] as String?) ?? '';
    noTelpController.text = (profile?['no_telp'] as String?) ?? '';

    isLoadingInitial.value = false;
  }

  Future<void> pickPhoto(ImageSource source) async {
    try {
      final XFile? shot = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (shot == null) return;
      photoBytes.value = await shot.readAsBytes();
    } catch (error) {
      _showSnack('Gagal mengambil foto', '$error', isError: true);
    }
  }

  String? validateRequired(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label wajib diisi';
    return null;
  }

  String? validateNoTelp(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return 'No Telp wajib diisi';
    if (!GetUtils.isNumericOnly(phone)) return 'No Telp hanya boleh angka';
    if (phone.length < 10) return 'No Telp minimal 10 digit';
    return null;
  }

  Future<void> submit() async {
    if (isLoading.value) return;

    final photo = photoBytes.value;
    if (photo == null && _existingFotoUrl.isEmpty) {
      _showSnack(
        'Foto belum diambil',
        'Silakan ambil atau pilih foto profil terlebih dahulu.',
        isError: true,
      );
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      Get.offAllNamed(Routes.login);
      return;
    }

    isLoading.value = true;
    try {
      var fotoUrl = _existingFotoUrl;
      if (photo != null) {
        final storagePath = '${user.id}/profile.jpg';
        await _supabase.storage
            .from('profiles')
            .uploadBinary(
              storagePath,
              photo,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        fotoUrl = _supabase.storage.from('profiles').getPublicUrl(storagePath);
      }

      await _supabase
          .from('profiles')
          .update({
            'nama_lengkap': namaLengkapController.text.trim(),
            'jabatan': jabatanController.text.trim(),
            'alamat': alamatController.text.trim(),
            'no_telp': noTelpController.text.trim(),
            'foto_url': fotoUrl,
          })
          .eq('id', user.id);

      AuthSession.to.setRole(_role);
      if (_role == 'admin') {
        Get.offAllNamed(Routes.dashboardAdmin);
      } else {
        Get.offAllNamed(Routes.dashboardGuru);
      }
      NotificationService.to.registerDeviceToken();
    } on StorageException catch (error) {
      _showSnack('Upload foto gagal', error.message, isError: true);
    } on PostgrestException catch (error) {
      _showSnack('Gagal menyimpan profil', error.message, isError: true);
    } catch (error) {
      _showSnack('Terjadi kesalahan', '$error', isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> keluar() async {
    await _supabase.auth.signOut();
    AuthSession.to.clear();
    Get.offAllNamed(Routes.login);
  }

  void _showSnack(String title, String message, {bool isError = false}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? Colors.red.shade600 : MainColor.primaryColor,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );
  }

  @override
  void onClose() {
    namaLengkapController.dispose();
    jabatanController.dispose();
    alamatController.dispose();
    noTelpController.dispose();
    super.onClose();
  }
}

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  // Owned by the widget, not the controller: a GlobalKey may only exist in one
  // place in the tree, and the controller is a singleton.
  final _formKey = GlobalKey<FormState>();
  final CompleteProfileController controller = Get.put(
    CompleteProfileController(),
  );

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      controller.submit();
    }
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (sheetContext) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Kamera'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.pickPhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Galeri'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.pickPhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      // No sensible route to fall back to: the setup gate has to be
      // completed (or the user has to explicitly log out) to leave it.
      canPop: false,
      child: Scaffold(
        backgroundColor: MainColor.secondaryColor,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [MainColor.primaryColor, MainColor.secondaryColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Obx(() {
                if (controller.isLoadingInitial.value) {
                  return const CircularProgressIndicator(color: Colors.white);
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Lengkapi Profil',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: MainColor.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sebelum melanjutkan, lengkapi data profil Anda terlebih dahulu.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(child: _buildAvatar()),
                          const SizedBox(height: 16),
                          Center(child: _buildUploadButton(textTheme)),
                          const SizedBox(height: 24),
                          _buildField(
                            controller: controller.namaLengkapController,
                            hint: 'Nama Lengkap',
                            textTheme: textTheme,
                            validator:
                                (v) => controller.validateRequired(
                                  v,
                                  'Nama lengkap',
                                ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            controller: controller.jabatanController,
                            hint: 'Jabatan',
                            textTheme: textTheme,
                            validator:
                                (v) =>
                                    controller.validateRequired(v, 'Jabatan'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            controller: controller.alamatController,
                            hint: 'Alamat',
                            textTheme: textTheme,
                            validator:
                                (v) => controller.validateRequired(v, 'Alamat'),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            controller: controller.noTelpController,
                            hint: 'No Telp',
                            textTheme: textTheme,
                            validator: controller.validateNoTelp,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 24),
                          _buildSubmitButton(textTheme),
                          const SizedBox(height: 16),
                          Center(
                            child: GestureDetector(
                              onTap: controller.keluar,
                              child: Text(
                                'Bukan Anda? Keluar',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: MainColor.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Obx(() {
      final bytes = controller.photoBytes.value;
      final existingUrl = controller.existingFotoUrl;

      Widget child;
      Key key;
      if (bytes != null) {
        key = const ValueKey('new');
        child = Image.memory(bytes, fit: BoxFit.cover, width: 96, height: 96);
      } else if (existingUrl.isNotEmpty) {
        key = const ValueKey('existing');
        child = Image.network(
          existingUrl,
          fit: BoxFit.cover,
          width: 96,
          height: 96,
          errorBuilder:
              (_, _, _) => Icon(
                Icons.person_outline,
                size: 44,
                color: MainColor.primaryColor.withValues(alpha: 0.4),
              ),
        );
      } else {
        key = const ValueKey('placeholder');
        child = Icon(
          Icons.person_outline,
          size: 44,
          color: MainColor.primaryColor.withValues(alpha: 0.4),
        );
      }

      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _fieldFill,
          border: Border.all(
            color:
                (bytes == null && existingUrl.isEmpty)
                    ? _fieldFill
                    : MainColor.thirdColor,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: key, child: child),
        ),
      );
    });
  }

  Widget _buildUploadButton(TextTheme textTheme) {
    return Obx(() {
      final hasPhoto =
          controller.photoBytes.value != null ||
          controller.existingFotoUrl.isNotEmpty;
      return Material(
        color: _uploadAccent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _showPhotoSourceSheet,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 18,
                  color: Colors.brown.shade800,
                ),
                const SizedBox(width: 8),
                Text(
                  hasPhoto ? 'Ganti Foto' : 'Upload Foto',
                  style: textTheme.labelLarge?.copyWith(
                    color: Colors.brown.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required TextTheme textTheme,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: textTheme.bodyMedium?.copyWith(color: Colors.black45),
        filled: true,
        fillColor: _fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
      ),
    );
  }

  Widget _buildSubmitButton(TextTheme textTheme) {
    return Obx(() {
      final isLoading = controller.isLoading.value;
      return Material(
        color: MainColor.primaryColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isLoading ? null : _submit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child:
                  isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                      : Text(
                        'Simpan & Lanjutkan',
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ),
      );
    });
  }
}
