# Arsitektur

## Gambaran Umum

```
┌─────────────────┐         ┌──────────────────────┐
│   Flutter App    │ ───────▶│   Supabase Postgres    │
│  (GetX routing/   │◀─────── │  + Auth + RLS          │
│   state, DI)       │         └──────────┬────────────┘
└───────┬──────────┘                       │ trigger (AFTER UPDATE
        │                                   │  ON jurnal_harian)
        │ Google Sign-In (ID token)         ▼
        ▼                          ┌──────────────────────┐
┌─────────────────┐               │  Edge Function          │
│  Google OAuth     │               │  notify-jurnal-validated │
└─────────────────┘               └──────┬───────────┬─────┘
                                          │           │
                        FCM (push, guru)  │           │  Nobox.ai (WhatsApp,
                                          ▼           ▼   orang tua siswa absen)
                                  ┌──────────────┐ ┌──────────────┐
                                  │ Firebase FCM  │ │  Nobox.ai API │
                                  └──────────────┘ └──────────────┘
```

- **Klien**: Flutter + `get` (GetX) — dipakai untuk routing (`GetPage`/`Get.toNamed`), state reaktif (`Obx`/`Rx`), dan dependency injection sederhana (`Get.put`/`Get.find`), bukan cuma navigasi.
- **Backend**: Supabase — satu-satunya sumber data. Tidak ada backend custom lain.
- **Push notification**: Firebase Cloud Messaging, dipicu dari Edge Function (server-side), bukan dari klien langsung.
- **WhatsApp**: Nobox.ai, juga dipicu dari Edge Function yang sama.

## Autentikasi

Supabase Auth adalah satu-satunya sistem otentikasi — Firebase **tidak** dipakai untuk auth sama sekali (hanya untuk FCM). Ada dua jalur login:

1. **Email/password** — `signInWithPassword`.
2. **Google Sign-In (native)** — `google_sign_in` mengambil ID token dari akun Google perangkat, lalu `Supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: ...)` menukarnya jadi sesi Supabase. Supabase yang memverifikasi ID token tersebut terhadap **Authorized Client IDs** yang dikonfigurasi di provider Google-nya (lihat `docs/setup.md`).

Di kedua jalur, **role** (`admin`/`guru`) selalu dibaca ulang dari tabel `profiles` (`select('role').eq('id', user.id)`) setelah sesi terbentuk — tidak pernah dipercaya dari data Google/klien. RLS pada `profiles` membatasi select hanya ke baris milik diri sendiri (`auth.uid() = id`), jadi role tidak bisa dipalsukan dari sisi klien.

`AuthSession` (`lib/app/auth_session.dart`) meng-cache role ini secara in-memory supaya `AdminOnlyMiddleware` bisa mengecek secara sinkron saat navigasi (middleware GetX tidak bisa `await` panggilan jaringan). Konsekuensinya: role **harus** di-set ulang setiap kali sesi baru terbentuk (login biasa, login Google, maupun restore sesi di splash) — kalau ada jalur baru yang lupa melakukan ini, admin akan selalu ter-redirect ke dashboard guru walau role di database sudah benar.

### Pembuatan profil otomatis & deteksi profil belum lengkap

Trigger Postgres `on_auth_user_created` (`AFTER INSERT ON auth.users`) menjalankan `handle_new_user()`, yang selalu membuat baris `profiles` untuk user baru — baik dari registrasi email/password maupun login Google pertama kali — dengan `COALESCE` atas `raw_user_meta_data`. Untuk login Google, hanya `nama_lengkap`/`foto_url` yang terisi dari data Google; `role` selalu default ke `'guru'`, dan `jabatan` default ke `'Guru Pengajar'`, sementara `alamat` dan `no_telp` selalu jadi string kosong (`''`), bukan `NULL`, karena tidak ada data itu di profil Google.

`login.dart` (`_routeByRole`) dan `splash.dart` (`_decideDestination`) memakai **`alamat == '' || no_telp == ''`** sebagai sinyal "profil belum lengkap" dan mengarahkan ke `Routes.completeProfile` (lihat `features.md`) alih-alih ke dashboard. Definisi trigger dan constraint `check_no_telp` di tabel `profiles` hanya ada di database Supabase (project `kgvbqytzpzzxourmlwlo`), **tidak** ada file migration di repo ini — perubahan pada keduanya harus dilacak lewat riwayat `apply_migration` di Supabase, bukan git log.

## Skema Database

Tabel-tabel utama (skema lengkap ada di dashboard Supabase, **bukan** di repo ini sebagai file migration):

| Tabel | Fungsi |
|---|---|
| `profiles` | Identitas & role user (`admin`/`guru`), 1:1 dengan `auth.users`. |
| `master_periode` | Periode tahun ajaran; satu baris `is_active = true` menandai periode berjalan. |
| `master_kelas`, `master_mata_pelajaran`, `master_jam` | Data referensi kelas, mata pelajaran, jam pelajaran. |
| `master_siswa` | Data siswa, termasuk `kelas_id` dan `no_hp_ortu` (nomor HP orang tua — tujuan notifikasi WhatsApp). |
| `jadwal_mengajar` | Jadwal mengajar: `guru_id`, `kelas_id`, `mata_pelajaran_id`, `periode_id`, hari/tanggal, `jam_ids` (array). |
| `jurnal_harian` | Jurnal harian yang disubmit guru: `jadwal_id`, `materi`, `catatan`, `status` (`pending`/`approved`/`rejected`), `catatan_admin`, `validated_by`, `validated_at`. Kolom `jadwal_ids` dan `presensi_json` ada tapi **tidak dipakai** (selalu `null` di data yang ada) — jangan bingung dengan `presensi_siswa` di bawah. |
| `presensi_siswa` | **Hanya mencatat siswa yang tidak hadir normal** untuk suatu jurnal: `jurnal_id`, `siswa_id`, `status` (`Sakit`/`Izin`/`Alpha`). Siswa tanpa baris di sini dianggap Hadir. Ini sumber data untuk notifikasi WhatsApp. |
| `jurnal_foto` | Lampiran foto per jurnal. |
| `pengaturan_aplikasi` | Satu baris (`id = 1`) berisi konfigurasi aplikasi: periode aktif, batas input jurnal, kredensial Nobox. |
| `user_fcm_tokens` | Token FCM per user per perangkat (`unique(user_id, fcm_token)`), dipakai Edge Function untuk tahu ke mana push dikirim. |
| `v_jadwal_mengajar`, `v_jurnal_harian` | View yang sudah join dengan tabel referensi (kelas, mata pelajaran, profil guru) dalam bentuk JSON embed — dipakai untuk menyederhanakan query di beberapa tempat, termasuk Edge Function. |

## Pipeline Notifikasi

Ini bagian paling tidak terlihat dari sistem — tidak ada kode Flutter yang memicunya secara langsung.

1. Admin menekan **Approve**/**Reject** di halaman Jurnal Mengajar → aplikasi melakukan `UPDATE jurnal_harian SET status = ...`.
2. Trigger Postgres `jurnal_harian_validated_webhook` (`AFTER UPDATE ON jurnal_harian`) menjalankan fungsi `notify_jurnal_validated()`, yang memanggil `net.http_post` ke Edge Function `notify-jurnal-validated`, membawa `record` (baris baru) dan `old_record` (baris lama) sebagai payload, dengan header `Authorization: Bearer <anon key>`.
3. Edge Function (`supabase/functions/notify-jurnal-validated/index.ts`):
   - Skip kalau bukan `UPDATE` pada `jurnal_harian`, atau `status` tidak benar-benar berubah, atau status baru bukan `approved`/`rejected`.
   - Ambil info jadwal (guru, kelas, mata pelajaran) lewat view `v_jadwal_mengajar`.
   - Jalankan dua operasi **independen** secara paralel (`Promise.all`) — satu gagal tidak menghentikan yang lain:
     - **`sendFcmToGuru`** — kirim push FCM ke semua token milik guru pemilik jurnal. Berjalan untuk **approve maupun reject**. Butuh secret `FIREBASE_SERVICE_ACCOUNT`; kalau tidak ada, di-skip (bukan error fatal).
     - **`sendWhatsappToParents`** — **hanya berjalan kalau status `approved`**. Query `presensi_siswa` untuk jurnal tersebut; kalau kosong (semua siswa hadir), langsung skip — **tidak ada pesan WhatsApp yang dikirim sama sekali**. Kalau ada siswa tidak hadir, kirim satu pesan WhatsApp per siswa tersebut ke `no_hp_ortu`-nya lewat Nobox.ai (`POST https://id.nobox.ai/Inbox/Send`), berisi nama siswa dan status kehadirannya (Sakit/Izin/Alpha). Butuh `pengaturan_aplikasi.nobox_account_ids` & `.nobox_token` terisi; kalau kosong, di-skip.
4. Response Edge Function berbentuk `{ fcm: {...}, whatsapp: {...} }`, masing-masing berisi `sent: [...]` atau `skipped: true, reason: "..."`. Untuk debug, hasil `net.http_post` bisa dilihat di tabel `net._http_response` lewat SQL.

Poin penting yang mudah salah asumsi:
- **Reject tidak pernah memicu WhatsApp**, hanya FCM ke guru.
- **Siswa yang hadir normal tidak pernah dapat notifikasi apa pun** — hanya siswa Sakit/Izin/Alpha yang orang tuanya dihubungi.
- Nomor HP di `no_hp_ortu` disimpan format lokal (`08xxxxxxxxxx`); baik Edge Function maupun `pengaturan_page.dart` melakukan normalisasi ke format `62xxxxxxxxxx` sebelum dikirim ke Nobox (fungsi `normalizeNoboxPhone`, dua implementasi terpisah — TypeScript di Edge Function, Dart di `pengaturan_page.dart` — karena berjalan di dua runtime berbeda).
- FCM hanya otomatis menampilkan notifikasi system-tray saat aplikasi di background/terminated. Saat foreground, `NotificationService` (`lib/app/services/notification_service.dart`) menampilkannya manual lewat `Get.snackbar`.

## Platform Guard untuk Firebase

`lib/firebase_options.dart` hanya mendefinisikan konfigurasi untuk Android & iOS. Di platform lain (Windows, web — proyek ini juga di-build untuk keduanya), `Firebase.initializeApp()` di `main.dart` melempar `UnsupportedError`, yang ditangkap (`try/catch`) supaya aplikasi tetap jalan tanpa Firebase. `NotificationService` mengecek `Firebase.apps.isNotEmpty` di setiap method publiknya sebelum menyentuh `FirebaseMessaging.instance` — tanpa guard ini, aplikasi akan crash saat startup di platform yang tidak didukung Firebase.
