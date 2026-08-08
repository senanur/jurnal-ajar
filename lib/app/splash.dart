import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/auth_session.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How long the splash stays on screen before handing off.
const Duration splashDuration = Duration(seconds: 4);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(splashDuration, _decideDestination);
  }

  /// Routes to the dashboard when a session is already present (e.g. the app
  /// reloads after a web OAuth redirect, or a native session persists), and to
  /// login otherwise. Reads the caller's own `profiles.role`, just like login.
  Future<void> _decideDestination() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) {
      Get.offAllNamed(Routes.login);
      return;
    }

    final profile = await supabase
        .from('profiles')
        .select('role')
        .eq('id', session.user.id)
        .maybeSingle();

    final role = profile?['role'] as String?;
    AuthSession.to.setRole(role);

    switch (role) {
      case 'admin':
        Get.offAllNamed(Routes.dashboardAdmin);
      case 'guru':
        Get.offAllNamed(Routes.dashboardGuru);
      default:
        await supabase.auth.signOut();
        AuthSession.to.clear();
        Get.offAllNamed(Routes.login);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
            end: AlignmentGeometry.bottomCenter,
            begin: AlignmentGeometry.topCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/image/logoApp.png',
                width: 200,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 15),
              // width: double.infinity spans the full width so every wrapped
              // line centers within the screen, not within the text's own box.
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Jurnal Mengajar',
                  style: TextStyle(
                    fontSize: 28,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                    fontWeight: FontWeight.w800,
                    color: MainColor.fourthColor,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Pelatihan Pemrograman Mobile KPTK Balikpapan 2026 Kelas C',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                    color: MainColor.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 60),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(MainColor.primaryColor),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
