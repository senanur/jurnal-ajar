# Keterbatasan & Hal yang Belum Selesai

## Push Notification di iOS Belum Lengkap

Kode klien (`UIBackgroundModes: remote-notification` di `Info.plist`, `NotificationService`) sudah siap, tapi push notification di iOS **butuh langkah tambahan di luar kode** yang belum dilakukan:

- Upload APNs key/certificate ke Firebase Console.
- Aktifkan capability **Push Notifications** di Xcode (ini yang membuat file `Runner.entitlements`).

Kedua langkah ini butuh akun Apple Developer dan Xcode di macOS — tidak bisa dilakukan dari environment development saat ini (Windows). Android tidak terpengaruh, sudah berfungsi penuh begitu `google-services.json` terpasang.

## Statistik Guru Belum Diimplementasikan

Menu **Statistik** ada di drawer guru, tapi rutenya (`Routes.guruStatistik`) belum didaftarkan di `main.dart` — masih menampilkan snackbar "segera hadir".

## Skema Database Tidak Ada di Repo

Tidak ada folder `supabase/migrations/` — skema database (tabel, trigger, function, RLS policy) hanya ada di project Supabase live, tidak di-track sebagai kode. Ringkasan skema ada di `docs/architecture.md`, tapi kalau skema berubah di dashboard, dokumen ini bisa jadi tidak sinkron. Perubahan skema disarankan tetap ditulis sebagai migration SQL ke depannya supaya bisa direview lewat git.

## Kolom Legacy yang Tidak Terpakai

`jurnal_harian.jadwal_ids` (array) dan `jurnal_harian.presensi_json` (jsonb) ada di skema tapi selalu `null` di data yang berjalan — sepertinya sisa dari rancangan awal yang belum/tidak jadi dipakai. Data presensi yang sesungguhnya dipakai ada di tabel terpisah, `presensi_siswa`. Jangan bingung keduanya saat membaca/menulis kode baru.

## Test Kirim Pesan Nobox Tidak Punya Rate Limit

Tombol "Test Kirim Pesan" di halaman Pengaturan (dan pengiriman WhatsApp otomatis di Edge Function) memanggil Nobox langsung tanpa retry/backoff atau pembatasan jumlah. Kalau kredensial salah atau Nobox sedang bermasalah, kegagalan akan terlihat sebagai error biasa (tidak ada penanganan khusus selain pesan error ke admin).

## Google Sign-In Bergantung Konfigurasi Eksternal

Fungsi login Google hanya akan berhasil kalau **Authorized Client IDs** di provider Google pada Supabase Auth sudah memuat ketiga client ID (Web/Android/iOS) yang dipakai `GoogleSignIn.instance.initialize(...)`. Ini konfigurasi di dashboard Supabase, tidak bisa diverifikasi lewat kode — kalau login Google gagal dengan error terkait audience/token, cek konfigurasi ini dulu.
