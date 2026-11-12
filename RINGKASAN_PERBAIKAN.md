# Ringkasan Perbaikan & Pengembangan Proyek QR-Scanner

Dokumen ini merangkum seluruh perbaikan, perancangan arsitektur basis data, diagram alur operasional (*flowchart*), diagram ERD, implementasi fitur aplikasi Flutter, hingga pengujian otomatis (CI) yang telah diterapkan pada repositori **QR-Scanner**.

---

## 1. Diagram Arsitektur Aplikasi

Aplikasi kini menggunakan arsitektur berlapis (*Layered Architecture*) yang memisahkan antarmuka pengguna (UI), logika bisnis (*Service Layer*), dan penyimpanan lokal terenkripsi (*Encrypted Persistence Layer*):

```mermaid
flowchart TB
    subgraph UI["Presentation / UI Layer"]
        HP["HomePage (lib/main.dart)<br/>Pemindai Kamera & Drawer"]
        SHP["ScanHistoryPage (lib/pages/scan_history_page.dart)<br/>Search Bar, Filter Favorit/Folder, Tag & Copy"]
    end

    subgraph SVC["Service Layer"]
        SS["ScanService (lib/services/scan_service.dart)<br/>CRUD Scan, Search, Filter & ScanActions"]
        FTS["FolderTagService (lib/services/folder_tag_service.dart)<br/>CRUD Folder, Tag & Relasi ScanTags"]
    end

    subgraph DATA["Encrypted Persistence Layer"]
        DB["AppDatabase (lib/database/database.dart)<br/>Drift ORM + MigrationStrategy (FK ON)"]
        CIPHER[("SQLCipher (qr_scanner.sqlite)<br/>Enkripsi AES-256 At-Rest")]
        KEY["FlutterSecureStorage<br/>Android Keystore / iOS Keychain (256-bit Key)"]
    end

    HP --> SS
    HP --> SHP
    SHP --> SS
    SHP --> FTS
    SS --> DB
    FTS --> DB
    DB --> CIPHER
    DB --> KEY
```

---

## 2. Flowchart Operasional Aplikasi

### A. Flowchart Pemindaian QR/Barcode & Penyimpanan Terenkripsi (`HomePage`)

```mermaid
flowchart TD
    Start(["Mulai: Pengguna Buka Aplikasi"]) --> Home["Tampil HomePage (lib/main.dart)"]
    Home --> TapScan["Pengguna Tekan Tombol 'Scan'"]
    TapScan --> CamPerm{"Izin Kamera Diberikan?"}

    CamPerm -- "Tidak (CameraAccessDenied)" --> ErrPerm["Tampilkan Pesan:<br/>'Camera permission was denied'"]
    CamPerm -- "Ya" --> OpenCam["Buka Kamera Pemindai (BarcodeScanner.scan)"]

    OpenCam --> UserAct{"Aksi Pengguna di Kamera"}
    UserAct -- "Tekan Tombol Back (FormatException)" --> CancelMsg["Tampilkan Pesan:<br/>'You pressed the back button...'"]
    UserAct -- "QR / Barcode Terbaca" --> DetectType["Deteksi Tipe Konten (_detectContentType)<br/>url | wifi | vcard | geo | text"]

    DetectType --> CallSvc["Panggil ScanService.insertScan()"]
    CallSvc --> InitDB{"Database Sudah Terbuka?"}

    InitDB -- "Belum" --> KeyCheck["Ambil / Buat Kunci 256-bit di<br/>Keystore / Keychain (FlutterSecureStorage)"]
    KeyCheck --> OpenCipher["Buka qr_scanner.sqlite dengan<br/>SQLCipher (PRAGMA key & foreign_keys = ON)"]
    OpenCipher --> EnsureUser

    InitDB -- "Sudah" --> EnsureUser["Pastikan Baris Users & Devices Lokal Ada"]
    EnsureUser --> InsertRow["Simpan ke Tabel SCAN_HISTORY<br/>(UUID v4, syncStatus = 'pending')"]
    InsertRow --> UpdateUI["Tampilkan Hasil Scan di Layar Utama"]
    ErrPerm --> End(["Selesai"])
    CancelMsg --> End
    UpdateUI --> End
```

### B. Flowchart Manajemen Riwayat Scan (`ScanHistoryPage`)

```mermaid
flowchart TD
    OpenHist(["Buka Riwayat Scan<br/>(Drawer / Ikon AppBar)"]) --> StreamInit["Berlangganan Stream:<br/>ScanService.watchFilteredScans()"]
    StreamInit --> FilterCheck["Terapkan Filter Aktif:<br/>1. Keyword Search (rawValue/title/notes)<br/>2. Hanya Favorit (isFavorite)<br/>3. Folder Terpilih (folderId)<br/>4. Hanya Data Aktif (isDeleted = false)"]
    FilterCheck --> RenderList["Tampilkan Daftar Scan (Terbaru di Atas)"]

    RenderList --> UserInteract{"Interaksi Pengguna"}

    UserInteract -- "Ketik di Search / Klik Chip Folder / Bintang AppBar" --> FilterCheck

    UserInteract -- "Klik Ikon Bintang pada Item" --> ToggleFav["ScanService.toggleFavorite()<br/>Ubah isFavorite & updatedAt"]
    ToggleFav --> StreamInit

    UserInteract -- "Geser Item ke Kiri (Swipe Dismiss)" --> SoftDel["ScanService.deleteScan()<br/>Set isDeleted = true (Soft Delete)"]
    SoftDel --> StreamInit

    UserInteract -- "Klik Tombol Salin (Copy)" --> CopyClip["Salin ke Clipboard +<br/>ScanService.logAction(actionType: 'copy')<br/>Simpan ke Tabel SCAN_ACTIONS"]
    CopyClip --> ShowSnack["Tampilkan SnackBar Konfirmasi"]

    UserInteract -- "Klik Item Scan (Buka Dialog Detail)" --> DetailModal["Tampilkan Dialog Detail Scan"]
    DetailModal --> DetailAct{"Aksi di Dialog Detail"}
    DetailAct -- "Ubah Dropdown Folder" --> AssignFolder["ScanService.assignFolder()"]
    DetailAct -- "Pilih / Buat FilterChip Tag" --> AssignTag["FolderTagService.assignTagToScan() /<br/>removeTagFromScan() (Tabel SCAN_TAGS)"]
    AssignFolder --> StreamInit
    AssignTag --> StreamInit
```

---

## 3. Entity Relationship Diagram (ERD)

Skema basis data relasional dirancang secara *offline-first* dengan **9 entitas** yang saling berelasi:

```mermaid
erDiagram
    USERS ||--o{ DEVICES : "registers"
    USERS ||--o{ FOLDERS : "owns"
    USERS ||--o{ SCAN_HISTORY : "records"
    USERS ||--o{ QR_GENERATED : "creates"
    USERS ||--o{ TAGS : "defines"

    DEVICES ||--o{ SCAN_HISTORY : "captures"
    FOLDERS ||--o{ SCAN_HISTORY : "organizes"

    SCAN_HISTORY ||--o{ SCAN_ACTIONS : "logs"
    SCAN_HISTORY ||--o{ SCAN_TAGS : "labeled_with"
    TAGS ||--o{ SCAN_TAGS : "applied_to"

    DEVICES ||--o{ SYNC_QUEUE : "queues"

    USERS {
        uuid id PK
        string email UK "Nullable untuk profil lokal"
        string display_name
        string auth_provider "local | google | apple | email"
        timestamp created_at
        timestamp updated_at
    }

    DEVICES {
        uuid id PK
        uuid user_id FK
        string platform "android | ios"
        string device_name
        string app_version
        timestamp last_sync_at
        timestamp created_at
    }

    FOLDERS {
        uuid id PK
        uuid user_id FK
        string name
        string color_hex
        string icon_name
        boolean is_deleted
        timestamp created_at
        timestamp updated_at
    }

    SCAN_HISTORY {
        uuid id PK
        uuid user_id FK
        uuid device_id FK
        uuid folder_id FK "Nullable"
        text raw_value "Isi hasil scan"
        string content_type "url | wifi | vcard | text | product | geo"
        string barcode_format "QR_CODE | EAN_13 | CODE_128 | DATA_MATRIX"
        string title
        text notes
        boolean is_favorite
        boolean is_deleted "Soft delete untuk sinkronisasi"
        string sync_status "pending | synced | failed"
        timestamp scanned_at
        timestamp updated_at
    }

    QR_GENERATED {
        uuid id PK
        uuid user_id FK
        string content_type "url | wifi | vcard | text"
        text payload
        string fg_color_hex
        string bg_color_hex
        string error_correction "L | M | Q | H"
        boolean is_deleted
        timestamp created_at
        timestamp updated_at
    }

    TAGS {
        uuid id PK
        uuid user_id FK
        string name
        string color_hex
        timestamp created_at
    }

    SCAN_TAGS {
        uuid scan_id PK, FK
        uuid tag_id PK, FK
        timestamp assigned_at
    }

    SCAN_ACTIONS {
        uuid id PK
        uuid scan_id FK
        string action_type "open_url | copy | share | connect_wifi | save_contact"
        timestamp performed_at
    }

    SYNC_QUEUE {
        uuid id PK
        uuid device_id FK
        string entity_type "scan_history | folders | tags | qr_generated"
        uuid entity_id
        string operation "INSERT | UPDATE | DELETE"
        text payload_json
        int retry_count
        string status "queued | processing | failed"
        timestamp created_at
    }
```

### Penjelasan Entitas & Relasi Utama
1. **`USERS` & `DEVICES`**: Menyimpan identitas pengguna dan perangkat lokal (otomatis dibuat saat pertama kali memindai) serta siap di-upgrade ke akun cloud.
2. **`SCAN_HISTORY`**: Tabel utama penyimpan hasil scan beserta tipe konten (`url`, `wifi`, `vcard`, `geo`, `text`), format barcode, status favorit (`is_favorite`), dan *soft delete* (`is_deleted`).
3. **`FOLDERS`**: Mengelompokkan hasil scan ke dalam kategori (`1:N` ke `SCAN_HISTORY`).
4. **`TAGS` & `SCAN_TAGS`**: Relasi *many-to-many* (`M:N`) dengan *Composite Primary Key* `(scan_id, tag_id)` dan aturan `ON DELETE CASCADE`.
5. **`SCAN_ACTIONS`**: Mencatat setiap interaksi pengguna terhadap hasil scan (misalnya menyalin teks ke clipboard).
6. **`QR_GENERATED` & `SYNC_QUEUE`**: Mendukung fitur pembuatan QR kustom dan antrean sinkronisasi *outbox pattern* ke server cloud.

---

## 4. Roadmap Pengembangan Basis Data

```mermaid
flowchart LR
    P1["Phase 1: v1.1<br/>Local Persistence<br/>(SQLite / Drift)"] --> P2["Phase 2: v1.2<br/>QR Generator,<br/>Actions & Export"]
    P2 --> P3["Phase 3: v2.0<br/>Offline-First Sync<br/>& Cloud Postgres"]
    P3 --> P4["Phase 4: v2.1+<br/>Encryption (SQLCipher),<br/>RLS & Archiving"]
```

- **Phase 1 (`v1.1.0`) — Selesai**: Skema lokal Drift, manajemen `ScanHistory`, `Folders`, `Tags`, `ScanTags`, pencarian kata kunci, dan filter favorit/folder.
- **Phase 2 (`v1.2.0`) — Sebagian Selesai**: Deteksi tipe konten otomatis dan pencatatan `ScanActions` (`copy`) telah aktif; tabel `QRGenerated` sudah siap di basis data.
- **Phase 3 (`v2.0.0`) — Siap Integrasi Cloud**: Tabel `Users`, `Devices`, dan `SyncQueue` sudah tersedia di skema lokal untuk dihubungkan ke backend PostgreSQL/Supabase.
- **Phase 4 (`v2.1.0+`) — Enkripsi Lokal Selesai**: Enkripsi *at-rest* menggunakan **SQLCipher** (AES-256) dengan penyimpanan kunci di Android Keystore / iOS Keychain telah diimplementasikan.

---

## 5. Rincian Implementasi Fitur

### A. Perombakan Dokumentasi (`README.md`)
- Menghapus tautan GIF `gfycat.com` yang sudah mati dan memperbarui tautan dokumentasi resmi Flutter.
- Menambahkan badge status, daftar isi, tabel *Tech Stack*, struktur direktori, ERD Mermaid, serta matriks migrasi Database Roadmap.

### B. Skema Basis Data & Enkripsi (`lib/database/`)
- **`lib/database/tables.dart`**: Definisi 9 tabel Drift dengan *mixin* `UuidPk` (UUID v4 otomatis di sisi klien) serta aturan `KeyAction.cascade`.
- **`lib/database/database.dart`**:
  - Membuka database menggunakan **SQLCipher** (`PRAGMA key = "x'<hexKey>'";`) dan memverifikasi `PRAGMA cipher_version;`.
  - Mengelola kunci enkripsi 256-bit via `FlutterSecureStorage`.
  - Menyediakan konstruktor `AppDatabase.forTesting` dan mengaktifkan `PRAGMA foreign_keys = ON`.

### C. Lapisan Layanan (`lib/services/`)
- **`lib/services/scan_service.dart`**:
  - `insertScan`, `toggleFavorite`, `assignFolder`, `deleteScan` (*soft delete*).
  - `searchScans` & `watchFilteredScans` untuk pencarian teks dan filter favorit/folder secara *real-time*.
  - `logAction` & `getActionsForScan` untuk mencatat interaksi pengguna ke tabel `ScanActions`.
- **`lib/services/folder_tag_service.dart`**:
  - `createFolder`, `watchFolders`, `getAllFolders`, `deleteFolder` (transaksi *soft delete* + melepas `folderId` pada scan terkait).
  - `createTag`, `getAllTags`, `assignTagToScan`, `removeTagFromScan`, `getTagsForScan`.

### D. Antarmuka Pengguna (`lib/main.dart` & `lib/pages/scan_history_page.dart`)
- Menghapus class rusak `HomePageStat` di `lib/main.dart`, menambahkan **Drawer** navigasi, serta menyimpan setiap hasil scan secara otomatis ke database.
- Menambahkan **Search Bar**, **ChoiceChip Folder**, tombol **Filter Favorit**, tombol **Salin (Copy)** ke `Clipboard`, serta dialog **Detail Scan** untuk mengatur Folder dan Tag pada `ScanHistoryPage`.

### E. Unit Testing & GitHub Actions CI (`test/database_test.dart` & `.github/workflows/flutter_test.yml`)
- Pengujian otomatis menggunakan `NativeDatabase.memory()` untuk memverifikasi UUID v4, CRUD scan, *soft delete*, pencarian & filter, pencatatan `ScanActions`, relasi *many-to-many* `ScanTags`, dan `ON DELETE CASCADE`.
- Pipeline GitHub Actions yang menjalankan `flutter pub get`, `build_runner`, dan `flutter test` secara otomatis di server Ubuntu setiap kali ada `push` atau `pull_request`.

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
| `RINGKASAN_PERBAIKAN.md` | Diperbarui | Dokumen ringkasan perbaikan lengkap dengan Arsitektur, Flowchart & ERD |

---

## 7. Riwayat Commit GitHub (`origin/main`)

| Commit SHA | Pesan Commit |
| :--- | :--- |
| `a9aaed6` | `docs: revamp README with professional structure, ERD, and database roadmap` |
| `2f1bbf4` | `feat: add Drift DB, ScanService, ScanHistory UI` |
| `227c8bc` | `feat: add SQLCipher encryption, drawer navigation, and scan persistence` |
| `19726f5` | `test: add Drift unit tests and GitHub Actions CI workflow` |
| `4a59dd0` | `feat: add folder/tag management, search & favorite filters, and scan action logging` |
| `a0eb144` | `docs: add RINGKASAN_PERBAIKAN.md project improvement summary` |
| `8508a56` | `docs: add ERD, architecture, and roadmap diagrams to RINGKASAN_PERBAIKAN.md` |
