# Ringkasan Perbaikan & Pengembangan Proyek QR-Scanner

Dokumen ini merangkum seluruh perbaikan, perancangan arsitektur basis data, implementasi fitur aplikasi Flutter, hingga pengujian otomatis (CI) yang telah diterapkan pada repositori **QR-Scanner**.

---

## 1. Perombakan Dokumentasi, ERD & Database Roadmap (`README.md`)

- **Pembaruan Struktur Profesional**:
  - Menghapus tautan gambar GIF `gfycat.com` yang sudah tidak aktif dan memperbaiki kesalahan ketik pada dokumentasi lama.
  - Menambahkan badge status proyek, daftar isi (*Table of Contents*), tabel *Tech Stack*, struktur direktori proyek, serta panduan konfigurasi Android (`AndroidManifest.xml`) dan iOS (`Info.plist`).
- **Entity Relationship Diagram (ERD)**:
  - Merancang skema basis data relasional *offline-first* menggunakan diagram **Mermaid `erDiagram`** yang terdiri dari **9 entitas**:
    1. `USERS` — Profil pengguna lokal/terautentikasi.
    2. `DEVICES` — Identitas perangkat Android/iOS untuk pelacakan sinkronisasi.
    3. `FOLDERS` — Pengelompokan riwayat scan ke dalam kategori/folder.
    4. `SCAN_HISTORY` — Tabel transaksi utama penyimpan hasil scan QR/barcode.
    5. `QR_GENERATED` — Riwayat QR code yang dibuat oleh pengguna.
    6. `TAGS` — Daftar label/tag kustom milik pengguna.
    7. `SCAN_TAGS` — Tabel relasi *many-to-many* (`COMPOSITE PK (scan_id, tag_id)`) antara hasil scan dan tag.
    8. `SCAN_ACTIONS` — Catatan interaksi pasca-scan (`copy`, `open_url`, `share`, dll.).
    9. `SYNC_QUEUE` — Tabel *outbox pattern* untuk antrean sinkronisasi ke cloud.
- **Database Roadmap**:
  - Menyusun rencana pengembangan 4 fase mulai dari **Phase 1 (`v1.1.0`)** fondasi SQLite lokal (`drift`), **Phase 2 (`v1.2.0`)** QR Generator & pencatatan aksi, **Phase 3 (`v2.0.0`)** sinkronisasi cloud PostgreSQL (*Last-Write-Wins*), hingga **Phase 4 (`v2.1.0+`)** enkripsi *at-rest* (`SQLCipher`) & pengarsipan.

---

## 2. Implementasi Skema Basis Data Drift & Enkripsi SQLCipher

- **Definisi Tabel (`lib/database/tables.dart`)**:
  - Mengimplementasikan ke-9 tabel sesuai ERD menggunakan paket `drift` dan `uuid` (UUID v4 yang di-generate di sisi klien agar aman untuk mode *offline*).
  - Mengaktifkan *cascade delete* (`KeyAction.cascade`) pada `ScanActions` dan `ScanTags` serta *soft delete* (`isDeleted`) untuk mendukung sinkronisasi antar-perangkat.
- **Enkripsi Basis Data *At-Rest* (`lib/database/database.dart`)**:
  - Menggantikan SQLite standar dengan **SQLCipher** (`sqlcipher_flutter_libs` + `sqlite3`) berenkripsi AES-256.
  - Kunci enkripsi 256-bit dibuat secara kriptografis (`Random.secure()`) pada saat aplikasi pertama kali dijalankan dan disimpan secara aman di **Android Keystore / iOS Keychain** melalui `flutter_secure_storage`.
  - Menambahkan konstruktor `AppDatabase.forTesting(QueryExecutor executor)` dan mengaktifkan `PRAGMA foreign_keys = ON` agar skema dapat diuji menggunakan database *in-memory*.

---

## 3. Lapisan Layanan (*Service Layer*)

- **`ScanService` (`lib/services/scan_service.dart`)**:
  - Menyediakan operasi `insertScan`, `toggleFavorite`, `assignFolder`, dan `deleteScan` (*soft delete*).
  - Menyediakan pencarian dan pemfilteran *real-time* (`searchScans` & `watchFilteredScans`) berdasarkan kata kunci (`rawValue`, `title`, `notes`), filter khusus favorit (`favoritesOnly`), serta filter per folder (`folderId`).
  - Menyediakan pencatatan riwayat aksi pengguna ke tabel `ScanActions` (`logAction` & `getActionsForScan`).
- **`FolderTagService` (`lib/services/folder_tag_service.dart`)**:
  - Mengelola pembuatan, pembacaan *stream*, dan penghapusan folder (`createFolder`, `watchFolders`, `deleteFolder`). Saat folder dihapus, seluruh scan di dalamnya otomatis dilepaskan (`folderId = null`) dalam satu transaksi.
  - Mengelola pembuatan tag (`createTag`) serta pemasangan/pelepasan tag ke hasil scan (`assignTagToScan`, `removeTagFromScan`, `getTagsForScan`).

---

## 4. Perbaikan Kode Utama & Antarmuka Pengguna (UI)

- **Pembersihan & Integrasi Halaman Utama (`lib/main.dart`)**:
  - Menghapus class rusak/duplikat `HomePageStat extends $state<HomePage>` pada kode lama.
  - Mengintegrasikan `_scanQR()` dengan `ScanService.instance.insertScan()` beserta deteksi tipe konten otomatis (`url`, `wifi`, `vcard`, `geo`, `text`).
  - Menambahkan navigasi **Drawer** dan tombol pintasan di **AppBar** menuju halaman **Riwayat Scan**.
- **Halaman Riwayat Scan Interaktif (`lib/pages/scan_history_page.dart`)**:
  - Menampilkan daftar riwayat scan secara *real-time* menggunakan `StreamBuilder`.
  - Menyediakan **Search Bar**, baris **ChoiceChip Folder**, tombol **Filter Favorit**, dan dialog **Buat Folder Baru**.
  - Mendukung *swipe-to-delete* (`Dismissible`), tombol cepat **Salin (Copy)** ke `Clipboard` (yang otomatis tercatat ke `ScanActions`), serta dialog **Detail Scan** untuk mengubah Folder dan memilih/menambah **Tag** (`FilterChip`).

---

## 5. Pengujian Unit (*Unit Testing*) & GitHub Actions CI

- **Unit Test Basis Data (`test/database_test.dart`)**:
  - Menguji pembuatan UUID v4 otomatis dan nilai default kolom pada `ScanHistory`.
  - Menguji operasi CRUD, *soft delete*, pencarian kata kunci, filter favorit, filter folder, dan pencatatan `ScanActions`.
  - Menguji manajemen Folder & Tag (*many-to-many*) serta aturan `ON DELETE CASCADE` pada `ScanTags` dan `ScanActions`.
- **Integrasi Berkelanjutan (`.github/workflows/flutter_test.yml`)**:
  - Menambahkan workflow GitHub Actions yang otomatis menginstal `libsqlite3-dev`, menyiapkan Flutter SDK, men-generate kode Drift (`build_runner`), dan menjalankan `flutter test test/database_test.dart` di setiap `push` atau `pull_request` ke branch `main`.

---

## 6. Daftar File yang Dibuat / Diperbarui

| Path File | Status | Fungsi Utama |
| :--- | :--- | :--- |
| `README.md` | Diperbarui | Dokumentasi utama, ERD Mermaid, dan Database Roadmap |
| `pubspec.yaml` | Diperbarui | Konfigurasi dependensi Drift, SQLCipher, Secure Storage, dan UUID |
| `lib/main.dart` | Diperbarui | Halaman utama pemindai QR, Drawer navigasi, & penyimpanan otomatis |
| `lib/database/tables.dart` | Baru | Definisi 9 tabel Drift sesuai spesifikasi ERD |
| `lib/database/database.dart` | Baru | Koneksi singleton `AppDatabase` dengan enkripsi SQLCipher & Keystore |
| `lib/services/scan_service.dart` | Baru | Layanan CRUD scan, pencarian, filter favorit/folder, & log aksi |
| `lib/services/folder_tag_service.dart` | Baru | Layanan manajemen Folder, Tag, dan relasi *many-to-many* `ScanTags` |
| `lib/pages/scan_history_page.dart` | Baru | UI Riwayat Scan dengan Search Bar, Filter Chip Folder, Tag, & Copy |
| `test/database_test.dart` | Baru | Suite unit test *in-memory* untuk tabel Drift dan lapisan *service* |
| `.github/workflows/flutter_test.yml` | Baru | Pipeline CI otomatis untuk code-gen Drift dan eksekusi unit test |
| `RINGKASAN_PERBAIKAN.md` | Baru | Dokumen ringkasan perbaikan proyek |

---

## 7. Riwayat Commit GitHub (`origin/main`)

| Commit SHA | Pesan Commit |
| :--- | :--- |
| `a9aaed6` | `docs: revamp README with professional structure, ERD, and database roadmap` |
| `2f1bbf4` | `feat: add Drift DB, ScanService, ScanHistory UI` |
| `227c8bc` | `feat: add SQLCipher encryption, drawer navigation, and scan persistence` |
| `19726f5` | `test: add Drift unit tests and GitHub Actions CI workflow` |
| `4a59dd0` | `feat: add folder/tag management, search & favorite filters, and scan action logging` |
