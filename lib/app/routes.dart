class Routes {
  Routes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboardGuru = '/dashboard-guru';
  static const String dashboardAdmin = '/dashboard-admin';

  static const String masterJadwal = '/master/jadwal';
  static const String masterJurnal = '/master/jurnal';
  static const String masterPeriode = '/master/periode';
  static const String masterKelas = '/master/kelas';
  static const String masterPelajaran = '/master/pelajaran';
  static const String masterJam = '/master/jam';
  static const String masterSiswa = '/master/siswa';
  static const String masterGuru = '/master/guru';

  static const String pengaturan = '/pengaturan';
  static const String tentang = '/tentang';

  // Guru-side routes.
  static const String guruJadwal = '/guru/jadwal';
  static const String guruJurnal = '/guru/jurnal';
  static const String guruStatistik = '/guru/statistik';
  static const String guruJurnalForm = '/guru/jurnal/form';
}
