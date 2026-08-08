import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jurnal_mengajar/app/auth_session.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final RxBool obscurePassword = true.obs;
  final RxBool isLoading = false.obs;

  SupabaseClient get _supabase => Supabase.instance.client;

  void togglePassword() => obscurePassword.toggle();

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email wajib diisi';
    if (!GetUtils.isEmail(email)) return 'Format email tidak valid';
    return null;
  }

  String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password wajib diisi';
    if (password.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  /// Signs in against Supabase Auth, then reads the caller's own row in
  /// `profiles` to decide which dashboard to land on. RLS restricts that select
  /// to `auth.uid() = id`, so the role can't be spoofed from the client.
  Future<void> login() async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final user = response.user;
      if (user == null) {
        _showError('Login gagal', 'Email atau password salah.');
        return;
      }

      await _routeByRole(user);
    } on AuthException catch (error) {
      _showError('Login gagal', error.message);
    } on PostgrestException catch (error) {
      _showError('Gagal memuat profil', error.message);
    } catch (error) {
      _showError('Terjadi kesalahan', '$error');
    } finally {
      isLoading.value = false;
    }
  }

  /// Signs in via Google (ID token flow), then reuses the same
  /// role-lookup/navigation path as password login.
  Future<void> loginWithGoogle() async {
    if (isLoading.value) return;
    isLoading.value = true;

    try {
      final googleSignIn = GoogleSignIn.instance;
      if (!googleSignIn.supportsAuthenticate()) {
        _showError(
          'Login Google gagal',
          'Platform ini belum mendukung Login with Google.',
        );
        return;
      }

      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        _showError('Login Google gagal', 'Tidak menerima ID token dari Google.');
        return;
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      final user = response.user;
      if (user == null) {
        _showError('Login Google gagal', 'Gagal membuat sesi.');
        return;
      }

      await _routeByRole(user);
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _showError('Login Google gagal', error.description ?? '$error');
      }
    } on AuthException catch (error) {
      _showError('Login Google gagal', error.message);
    } on PostgrestException catch (error) {
      _showError('Gagal memuat profil', error.message);
    } catch (error) {
      _showError('Terjadi kesalahan', '$error');
    } finally {
      isLoading.value = false;
    }
  }

  /// Reads the caller's own row in `profiles` to decide which dashboard to
  /// land on. RLS restricts that select to `auth.uid() = id`, so the role
  /// can't be spoofed from the client.
  Future<void> _routeByRole(User user) async {
    final profile = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    final role = profile?['role'] as String?;
    AuthSession.to.setRole(role);

    switch (role) {
      case 'admin':
        Get.offAllNamed(Routes.dashboardAdmin);
        NotificationService.to.registerDeviceToken();
      case 'guru':
        Get.offAllNamed(Routes.dashboardGuru);
        NotificationService.to.registerDeviceToken();
      default:
        // No usable role: don't leave a half-authenticated session behind.
        await _supabase.auth.signOut();
        AuthSession.to.clear();
        _showError(
          'Akses ditolak',
          'Akun ini belum memiliki role admin atau guru.',
        );
    }
  }

  void _showError(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade600,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Owned by the widget, not the controller: a GlobalKey may only exist in one
  // place in the tree, and the controller is a singleton shared by every
  // LoginScreen that mounts (both pages are alive during a fade transition).
  final _formKey = GlobalKey<FormState>();
  final LoginController controller = Get.put(LoginController());

  /// Validation lives with the Form (which owns the key); the network call
  /// lives in the controller.
  void _submit() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() ?? false) {
      controller.login();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          width: 96,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Masuk',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: MainColor.primaryColor,
                        ),
                      ),
                      Text(
                        'Selamat datang kembali! Silakan masuk ke akun Anda.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Email',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MainColor.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: controller.emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: controller.validateEmail,
                        decoration: _inputDecoration(
                          hint: 'Masukkan email Anda',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Password',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MainColor.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => TextFormField(
                          controller: controller.passwordController,
                          obscureText: controller.obscurePassword.value,
                          textInputAction: TextInputAction.done,
                          validator: controller.validatePassword,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: _inputDecoration(
                            hint: 'Masukkan password Anda',
                            icon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              onPressed: controller.togglePassword,
                              icon: Icon(
                                controller.obscurePassword.value
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: MainColor.primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Obx(() {
                        final isLoading = controller.isLoading.value;
                        return InkWell(
                          onTap: isLoading ? null : _submit,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  MainColor.primaryColor,
                                  MainColor.secondaryColor,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                                      'Login',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Colors.black12)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Atau login dengan',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Colors.black12)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Obx(() {
                        final isLoading = controller.isLoading.value;
                        return InkWell(
                          onTap: isLoading
                              ? null
                              : () {
                                  FocusScope.of(context).unfocus();
                                  controller.loginWithGoogle();
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: MainColor.fourthColor,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.g_mobiledata,
                                  size: 28,
                                  color: Color(0xFF4285F4),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Login with Google',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Guru baru? ',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.black54,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Get.toNamed(Routes.register),
                            child: Text(
                              'Daftar disini.',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: MainColor.secondaryColor,
                                decoration: TextDecoration.underline,
                                decorationColor: MainColor.secondaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.black38),
      prefixIcon: Icon(icon, color: MainColor.primaryColor, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: MainColor.fourthColor.withValues(alpha: 0.25),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    );
  }
}
