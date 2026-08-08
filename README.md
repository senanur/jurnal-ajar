# Jurnal Mengajar

Aplikasi jurnal mengajar digital untuk sekolah — guru mencatat kegiatan mengajar harian (materi, catatan, presensi siswa), admin memverifikasi (approve/reject), dan orang tua siswa yang tidak hadir mendapat notifikasi WhatsApp otomatis begitu jurnal disetujui.

Dibangun dengan Flutter (GetX) di sisi klien dan Supabase (Postgres, Auth, Edge Functions) di sisi backend, ditambah Firebase Cloud Messaging untuk push notification dan Nobox.ai sebagai gateway WhatsApp.

> Proyek ini dikembangkan mengikuti rangkaian tutorial video (lihat riwayat commit — "video 9", "video 10", dst.), jadi sebagian keputusan struktur mengikuti alur tutorial tersebut, bukan murni desain dari nol.

## Aktor & Use Case

| Aktor | Peran |
|---|---|
| **Admin** | Mengelola data master (periode, kelas, pelajaran, jam, guru, siswa, jadwal mengajar), meninjau dan menyetujui/menolak jurnal yang disubmit guru, mengatur konfigurasi aplikasi (periode aktif, batas hari input jurnal, kredensial Nobox). |
| **Guru** | Melihat jadwal mengajar miliknya, mengisi jurnal harian (materi, catatan, presensi per siswa, lampiran foto), memantau status persetujuan jurnalnya sendiri. |
| **Orang tua siswa** | Aktor pasif — tidak membuka aplikasi. Menerima pesan WhatsApp otomatis ketika anaknya tercatat **Izin/Sakit/Alpha** pada sebuah jurnal yang baru saja disetujui admin. |

Alur yang menghubungkan ketiga aktor ini (submit → approve → notifikasi) adalah bagian paling tidak terlihat dari sistem — detailnya ada di [`docs/architecture.md`](docs/architecture.md#pipeline-notifikasi).

## Arsitektur Singkat

- **Klien**: Flutter, state management & routing pakai `get` (GetX).
- **Backend**: Supabase — Postgres (data + Row Level Security), Auth (email/password & Google Sign-In), Edge Functions (Deno).
- **Push notification**: Firebase Cloud Messaging (FCM), khusus untuk notifikasi ke guru saat jurnal di-approve/reject. Firebase **tidak** dipakai untuk autentikasi.
- **WhatsApp gateway**: Nobox.ai, dipicu dari Edge Function saat jurnal disetujui dan ada siswa yang tidak hadir.

Detail lengkap arsitektur, skema database, dan pipeline notifikasi ada di [`docs/architecture.md`](docs/architecture.md).

## Mulai Cepat

1. Ikuti [`docs/setup.md`](docs/setup.md) untuk menyiapkan `.env`, kredensial Firebase/Google/Nobox, dan menjalankan proyek secara lokal.
2. Lihat [`docs/features.md`](docs/features.md) untuk peta lengkap fitur per peran (admin/guru).
3. Kalau ada yang tidak berjalan seperti yang diharapkan, cek [`docs/known-issues.md`](docs/known-issues.md) dulu — beberapa keterbatasan (terutama di iOS) sudah diketahui dan didokumentasikan.

## Struktur Dokumentasi

```
docs/
├── setup.md          # Cara menjalankan proyek: env vars, kredensial, langkah instalasi
├── features.md        # Fitur per peran (admin & guru), halaman per halaman
├── architecture.md    # Arsitektur, skema database, pipeline notifikasi
└── known-issues.md    # Keterbatasan & hal yang belum selesai
```
