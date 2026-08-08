# Fitur per Peran

## Autentikasi (semua peran)

Halaman: `lib/app/login.dart`, `lib/app/register.dart`, `lib/app/splash.dart`.

- **Login email/password** — lewat Supabase Auth (`signInWithPassword`). Setelah berhasil, role diambil dari tabel `profiles` dan menentukan diarahkan ke dashboard admin atau guru.
- **Login with Google** — pakai `google_sign_in` (native, alur ID token) → `Supabase.auth.signInWithIdToken`. Sama seperti login email/password, role tetap ditentukan dari tabel `profiles`, bukan dari data Google.
- **Registrasi** — hanya untuk guru (`register.dart`); admin dibuat manual di database.
- **Splash / restore sesi** — kalau sesi Supabase masih ada (mis. reload web setelah redirect OAuth), langsung diarahkan ke dashboard sesuai role tanpa perlu login ulang.
- Setelah login sukses (jalur mana pun), aplikasi mendaftarkan **FCM token** perangkat ke `user_fcm_tokens` (lihat `lib/app/services/notification_service.dart`) supaya bisa menerima push notification. Saat logout, token perangkat tersebut dihapus.

## Sisi Admin

Drawer: `lib/app/widgets/admin_drawer.dart`. Semua rute admin dilindungi `AdminOnlyMiddleware` (redirect ke dashboard guru kalau bukan admin).

- **Dashboard** (`dashboard_admin.dart`) — ringkasan statistik mingguan.
- **Jurnal Mengajar** (`masterdata/jurnal_mengajar_page.dart`) — daftar jurnal yang disubmit guru, dengan aksi **Approve** / **Reject**. Aksi ini melakukan `UPDATE` langsung pada `jurnal_harian.status`, yang men-trigger seluruh pipeline notifikasi (lihat `architecture.md`).
- **Jadwal Mengajar** (`masterdata/jadwal_mengajar_page.dart`) — kelola jadwal per guru/kelas/mata pelajaran/jam.
- **Data Master**:
  - Periode (`periode_page.dart`)
  - Pelajaran (`pelajaran_page.dart`)
  - Jam Pelajaran (`jam_pelajaran_page.dart`)
  - Kelas (`kelas_page.dart`)
  - Guru (`guru_page.dart`)
  - Siswa (`siswa_page.dart`) — termasuk nomor HP orang tua (`no_hp_ortu`), sumber tujuan pesan WhatsApp.
- **Pengaturan** (`pengaturan/pengaturan_page.dart`) — periode aktif, batas hari input jurnal, kredensial Nobox (Account IDs + API Key) plus tombol "Test Kirim Pesan" untuk verifikasi kredensial sebelum disimpan.

## Sisi Guru

Drawer: `lib/app/widgets/guru_drawer.dart`. Semua rute guru bisa diakses tanpa middleware admin.

- **Dashboard** (`dashboard_guru.dart`) — ringkasan jadwal & status jurnal.
- **Jadwal Mengajar** (`guru/jadwal_guru_page.dart`) — jadwal mengajar milik guru yang login.
- **Jurnal Mengajar** (`guru/jurnal_guru_page.dart`, `guru/jurnal_form_page.dart`, `guru/detail_jurnal_page.dart`) — isi jurnal harian: materi, catatan, lampiran foto, dan **presensi per siswa**. Default semua siswa dianggap Hadir (ada tombol cepat "Hadir Semua"); guru hanya perlu menandai siswa yang **Sakit / Izin / Alpha**. Hanya siswa non-hadir yang disimpan sebagai baris di tabel `presensi_siswa` — ini penting dipahami karena memengaruhi siapa yang dapat notifikasi WhatsApp (lihat `architecture.md`).
- **Statistik** — ada di drawer tapi **belum diimplementasikan** (rute `Routes.guruStatistik` belum didaftarkan di `main.dart`, jadi masih menampilkan snackbar "segera hadir").

## Bersama (admin & guru)

- **Tentang Aplikasi** (`tentang/tentang_page.dart`) — halaman info versi aplikasi, dapat diakses dari kedua drawer.
