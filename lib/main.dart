import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/dashboard_admin.dart';
import 'package:jurnal_mengajar/app/dashboard_guru.dart';
import 'package:jurnal_mengajar/app/login.dart';
import 'package:jurnal_mengajar/app/masterdata/guru_page.dart';
import 'package:jurnal_mengajar/app/masterdata/jam_pelajaran_page.dart';
import 'package:jurnal_mengajar/app/masterdata/kelas_page.dart';
import 'package:jurnal_mengajar/app/masterdata/pelajaran_page.dart';
import 'package:jurnal_mengajar/app/masterdata/periode_page.dart';
import 'package:jurnal_mengajar/app/masterdata/siswa_page.dart';
import 'package:jurnal_mengajar/app/register.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: _requireEnv('SUPABASE_URL'),
    // publishableKey accepts both the legacy anon JWT and the newer
    // sb_publishable_* format, so swapping the .env value needs no code change.
    publishableKey: _requireEnv('SUPABASE_ANON_KEY'),
  );

  runApp(const MyApp());
}

/// Reads a required key from .env, failing loudly instead of passing a null
/// straight into Supabase.initialize where the error would be unreadable.
String _requireEnv(String key) {
  final value = dotenv.env[key];
  if (value == null || value.isEmpty) {
    throw StateError('$key tidak ditemukan di file .env');
  }
  return value;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Jurnal Mengajar",
      theme: ThemeData(
        colorSchemeSeed: MainColor.primaryColor,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      initialRoute: Routes.splash,
      defaultTransition: Transition.fade,
      transitionDuration: const Duration(milliseconds: 400),
      getPages: [
        GetPage(
          name: Routes.splash,
          page: () => const SplashScreen(),
          transition: Transition.fade,
        ),
        GetPage(
          name: Routes.login,
          page: () => const LoginScreen(),
          transition: Transition.fade,
        ),
        GetPage(
          name: Routes.register,
          page: () => const Register(),
          transition: Transition.fade,
        ),
        GetPage(
          name: Routes.dashboardGuru,
          page: () => const DashboardGuru(),
          transition: Transition.fade,
        ),
        GetPage(
          name: Routes.dashboardAdmin,
          page: () => const DashboardAdmin(),
          transition: Transition.fade,
        ),
        GetPage(
          name: Routes.masterPeriode,
          page: () => const PeriodeListPage(),
          transition: Transition.fade,
        ),
        GetPage(
          name: Routes.masterKelas,
          page: () => const KelasListPage(),
          transition: Transition.fade,
        ),
        GetPage(
          name: Routes.masterPelajaran,
          page: () => const PelajaranListPage(),
          transition: Transition.fade,
        ),
        GetPage(
          name: Routes.masterJam,
          page: () => const JamListPage(),
          transition: Transition.fade,
        ),
        GetPage(
          name: Routes.masterSiswa,
          page: () => const SiswaListPage(),
          transition: Transition.fade,
        ),
        GetPage(
          name: Routes.masterGuru,
          page: () => const GuruListPage(),
          transition: Transition.fade,
        ),
      ],
    );
  }
}
