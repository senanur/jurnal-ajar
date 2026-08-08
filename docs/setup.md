# Setup & Menjalankan Proyek

## Prasyarat

- Flutter SDK sesuai `environment.sdk` di `pubspec.yaml` (`^3.12.2`).
- Akses ke project Supabase yang sudah berisi skema database aplikasi ini (lihat [`architecture.md`](architecture.md#skema-database) — skema **tidak** disertakan sebagai file migration di repo ini, jadi harus didapat dari admin project atau di-reverse-engineer dari dashboard Supabase).
- Project Firebase (untuk FCM) dengan Android app dan (opsional) iOS app terdaftar.
- OAuth client Google (Web, Android, iOS) untuk fitur Login with Google, terdaftar di Google Cloud Console dan didaftarkan di **Authorized Client IDs** pada konfigurasi provider Google di Supabase Auth.
- Akun Nobox.ai (gateway WhatsApp) — opsional untuk development, tapi wajib untuk fitur notifikasi orang tua.

## File yang Di-gitignore (harus didapat terpisah)

File-file berikut **tidak ada di git** karena berisi kredensial, tapi wajib ada supaya aplikasi bisa jalan penuh. Tanyakan ke pemilik project atau generate ulang dari console masing-masing layanan:

| File | Isi | Sumber |
|---|---|---|
| `.env` | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `WEB_CLIENT`, `ANDROID_CLIENT`, `IOS_CLIENT` | Supabase dashboard (Settings → API) + Google Cloud Console (OAuth clients) |
| `android/app/google-services.json` | Konfigurasi Firebase Android | Firebase Console → Project Settings → Android app |
| `lib/firebase_options.dart` | `FirebaseOptions` per platform (dipakai `Firebase.initializeApp()`) | `flutterfire configure`, atau tulis manual seperti contoh di bawah |
| `assets/api/jurnal-mengajar-10846-firebase-adminsdk-fbsvc-*.json` | Service account key Firebase Admin SDK — dipakai untuk isi secret `FIREBASE_SERVICE_ACCOUNT` di Edge Function, **bukan** dipakai langsung oleh aplikasi Flutter | Firebase Console → Project Settings → Service Accounts |

Tanpa file-file ini aplikasi tetap bisa berjalan (login email/password & fitur non-notifikasi tetap normal), tapi push notification dan Google Sign-In tidak akan berfungsi.

### Isi `.env`

```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon/publishable key>
WEB_CLIENT=<web-client-id>.apps.googleusercontent.com
ANDROID_CLIENT=<android-client-id>.apps.googleusercontent.com
IOS_CLIENT=<ios-client-id>.apps.googleusercontent.com
```

`WEB_CLIENT` dipakai sebagai `serverClientId` di semua platform non-web (supaya ID token dari Google punya audience yang konsisten dan bisa diverifikasi Supabase); `IOS_CLIENT` dipakai sebagai `clientId` khusus di iOS. Lihat pemakaiannya di `lib/main.dart` (`GoogleSignIn.instance.initialize(...)`).

### Contoh `lib/firebase_options.dart`

```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:get/get.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (GetPlatform.isAndroid) {
      return const FirebaseOptions(
        apiKey: '...',
        appId: '1:...:android:...',
        messagingSenderId: '...',
        projectId: '...',
        storageBucket: '....firebasestorage.app',
      );
    }
    if (GetPlatform.isIOS) {
      return const FirebaseOptions(
        apiKey: '...',
        appId: '1:...:ios:...',
        messagingSenderId: '...',
        projectId: '...',
      );
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform.',
    );
  }
}
```

Catatan penting: file ini **hanya** mendefinisikan Android & iOS. Di platform lain (Windows, web), `Firebase.initializeApp()` di `main.dart` akan melempar `UnsupportedError` — ini sudah ditangkap (`try/catch`) dan aplikasi tetap jalan tanpa Firebase di platform tersebut. Lihat [`known-issues.md`](known-issues.md).

## Menjalankan Secara Lokal

```bash
flutter pub get
flutter run              # pilih device: Android, iOS, Windows, atau web
```

Untuk build Android release, pastikan `android/app/google-services.json` sudah ada — build akan gagal di step Google Services plugin kalau tidak ada.

## Konfigurasi yang Dilakukan Lewat Aplikasi (bukan file)

Sebagian konfigurasi disimpan di database (tabel `pengaturan_aplikasi`), diisi lewat halaman **Pengaturan** (khusus admin) di dalam aplikasi, bukan lewat file config:

- **Periode aktif** — periode tahun ajaran yang sedang berjalan.
- **Batas input jurnal** — berapa hari guru boleh mengisi jurnal mundur (pilihan: 2/3/5 hari).
- **Nobox Account IDs** & **API Key** — kredensial gateway WhatsApp. Tanpa ini, notifikasi WhatsApp ke orang tua akan otomatis di-skip (lihat [`architecture.md`](architecture.md#pipeline-notifikasi)) — fitur lain tidak terpengaruh.

## Edge Function Secrets (Supabase)

Function `notify-jurnal-validated` butuh environment secret berikut, di-set lewat Supabase dashboard (Edge Functions → Secrets) atau Supabase CLI, **bukan** lewat `.env` Flutter:

| Secret | Isi |
|---|---|
| `SUPABASE_URL` | Otomatis tersedia di semua Edge Function |
| `SUPABASE_SERVICE_ROLE_KEY` | Otomatis tersedia di semua Edge Function |
| `FIREBASE_SERVICE_ACCOUNT` | Isi mentah JSON dari file service account Firebase Admin SDK (lihat tabel file gitignored di atas) |
