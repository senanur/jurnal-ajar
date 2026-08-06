import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Warm accent behind "Upload Foto" in the frame_03 mockup. Kept local rather
/// than added to MainColor so the shared palette stays as authored.
const Color _uploadAccent = Color(0xFFEAD6C4);
const Color _fieldFill = Color(0xFFF0F3F8);

class RegisterController extends GetxController {
  final namaLengkapController = TextEditingController();
  final jabatanController = TextEditingController();
  final alamatController = TextEditingController();
  final noTelpController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final konfirmasiPasswordController = TextEditingController();

  final RxBool obscurePassword = true.obs;
  final RxBool obscureKonfirmasi = true.obs;
  final RxBool isLoading = false.obs;

  /// Bytes of the selfie. Held as bytes so the same value feeds both the
  /// preview and the upload without touching dart:io.
  final Rxn<Uint8List> photoBytes = Rxn<Uint8List>();

  SupabaseClient get _supabase => Supabase.instance.client;

  void togglePassword() => obscurePassword.toggle();
  void toggleKonfirmasi() => obscureKonfirmasi.toggle();

  /// Camera only, front lens. There is deliberately no gallery source here —
  /// the photo must be a selfie taken at registration time.
  Future<void> ambilSelfie() async {
    try {
      final XFile? shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (shot == null) return;
      photoBytes.value = await shot.readAsBytes();
    } catch (error) {
      _showSnack('Kamera gagal dibuka', '$error', isError: true);
    }
  }

  String? validateRequired(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label wajib diisi';
    return null;
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email wajib diisi';
    if (!GetUtils.isEmail(email)) return 'Format email tidak valid';
    return null;
  }

  String? validateNoTelp(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return 'No Telp wajib diisi';
    if (!GetUtils.isNumericOnly(phone)) return 'No Telp hanya boleh angka';
    if (phone.length < 10) return 'No Telp minimal 10 digit';
    return null;
  }

  String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password wajib diisi';
    if (password.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  String? validateKonfirmasi(String? value) {
    if ((value ?? '').isEmpty) return 'Konfirmasi password wajib diisi';
    if (value != passwordController.text) return 'Password tidak cocok';
    return null;
  }

  /// Signs up, then uploads the selfie. Upload has to come second: the storage
  /// policies on both buckets grant INSERT to `authenticated` only, so there is
  /// no anonymous upload path to use before the account exists.
  Future<void> register() async {
    if (isLoading.value) return;

    final photo = photoBytes.value;
    if (photo == null) {
      _showSnack(
        'Foto belum diambil',
        'Silakan ambil foto selfie terlebih dahulu.',
        isError: true,
      );
      return;
    }

    isLoading.value = true;
    try {
      final response = await _supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text,
        data: {
          'full_name': namaLengkapController.text.trim(),
          'jabatan': jabatanController.text.trim(),
          'alamat': alamatController.text.trim(),
          'no_telp': noTelpController.text.trim(),
          'role': 'guru',
        },
      );

      final user = response.user;
      if (user == null) {
        _showSnack(
          'Registrasi gagal',
          'Akun tidak dapat dibuat.',
          isError: true,
        );
        return;
      }

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

      final fotoUrl = _supabase.storage
          .from('profiles')
          .getPublicUrl(storagePath);
      await _supabase
          .from('profiles')
          .update({'foto_url': fotoUrl})
          .eq('id', user.id);

      // End on the login screen rather than dropping straight into a dashboard,
      // so the account is entered deliberately once.
      await _supabase.auth.signOut();
      _showSnack('Registrasi berhasil', 'Silakan login dengan akun Anda.');
      Get.offAllNamed(Routes.login);
    } on AuthException catch (error) {
      _showSnack('Registrasi gagal', error.message, isError: true);
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
    emailController.dispose();
    passwordController.dispose();
    konfirmasiPasswordController.dispose();
    super.onClose();
  }
}

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  // Owned by the widget: a GlobalKey may only appear once in the tree, and the
  // GetX controller is a singleton shared across every mounted Register.
  final _formKey = GlobalKey<FormState>();
  final RegisterController controller = Get.put(RegisterController());

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      controller.register();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
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
            child: SingleChildScrollView(
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
                      Center(
                        child: Image.asset(
                          'assets/image/LogoJr.png',
                          width: 160,
                          fit: BoxFit.contain,
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
                        validator: (v) =>
                            controller.validateRequired(v, 'Nama lengkap'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: controller.jabatanController,
                        hint: 'Jabatan',
                        textTheme: textTheme,
                        validator: (v) =>
                            controller.validateRequired(v, 'Jabatan'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: controller.alamatController,
                        hint: 'Alamat',
                        textTheme: textTheme,
                        validator: (v) =>
                            controller.validateRequired(v, 'Alamat'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: controller.noTelpController,
                        hint: 'No Telp',
                        textTheme: textTheme,
                        validator: controller.validateNoTelp,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: controller.emailController,
                        hint: 'Email',
                        textTheme: textTheme,
                        validator: controller.validateEmail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => _buildField(
                          controller: controller.passwordController,
                          hint: 'Password',
                          textTheme: textTheme,
                          validator: controller.validatePassword,
                          obscureText: controller.obscurePassword.value,
                          suffixIcon: _buildEye(
                            isObscured: controller.obscurePassword.value,
                            onPressed: controller.togglePassword,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => _buildField(
                          controller: controller.konfirmasiPasswordController,
                          hint: 'Konfirmasi Password',
                          textTheme: textTheme,
                          validator: controller.validateKonfirmasi,
                          obscureText: controller.obscureKonfirmasi.value,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          suffixIcon: _buildEye(
                            isObscured: controller.obscureKonfirmasi.value,
                            onPressed: controller.toggleKonfirmasi,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSubmitButton(textTheme),
                      const SizedBox(height: 16),
                      _buildLoginLink(textTheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Obx(() {
      final bytes = controller.photoBytes.value;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _fieldFill,
          border: Border.all(
            color: bytes == null ? _fieldFill : MainColor.thirdColor,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: bytes == null
              ? Icon(
                  Icons.person_outline,
                  key: const ValueKey('placeholder'),
                  size: 44,
                  color: MainColor.primaryColor.withValues(alpha: 0.4),
                )
              : Image.memory(
                  bytes,
                  key: const ValueKey('selfie'),
                  fit: BoxFit.cover,
                  width: 96,
                  height: 96,
                ),
        ),
      );
    });
  }

  Widget _buildUploadButton(TextTheme textTheme) {
    return Obx(() {
      final hasPhoto = controller.photoBytes.value != null;
      return Material(
        color: _uploadAccent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: controller.ambilSelfie,
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
                  hasPhoto ? 'Ambil Ulang' : 'Upload Foto',
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

  Widget _buildEye({
    required bool isObscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: MainColor.primaryColor,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required TextTheme textTheme,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: textTheme.bodyMedium?.copyWith(color: Colors.black45),
        suffixIcon: suffixIcon,
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
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Buat Akun',
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

  Widget _buildLoginLink(TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Sudah Punya Akun? ',
          style: textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
        GestureDetector(
          onTap: () => Get.offNamed(Routes.login),
          child: Text(
            'Login Disini',
            style: textTheme.bodyMedium?.copyWith(
              color: MainColor.primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
