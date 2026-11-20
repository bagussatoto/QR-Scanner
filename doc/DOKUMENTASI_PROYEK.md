# Dokumentasi Resmi Proyek — QR-Scanner Mobile App

**Aplikasi Pemindai QR Code & Barcode Multi-Platform Berbasis Flutter dengan Basis Data Lokal Terenkripsi (SQLCipher) dan Siap Sinkronisasi Cloud.**

---

## Informasi Proyek

| Atribut | Keterangan |
| :--- | :--- |
| **Nama Proyek** | Flutter QR-Scanner |
| **Repositori GitHub** | [bagussatoto/QR-Scanner](https://github.com/bagussatoto/QR-Scanner) |
| **Versi Aplikasi** | `v1.2.0+3` |
| **Framework Utama** | Flutter (`sdk: flutter`, Dart `>=3.0.0 <4.0.0`) |
| **Scanner & Generator** | `mobile_scanner ^5.2.3`, `qr_flutter ^4.1.0`, `url_launcher ^6.2.5` |
| **Target Platform** | Android (API Level 21+, Embedding v2) & iOS (iOS 12.0+) |
| **Engine Basis Data** | SQLite Terenkripsi via **SQLCipher** (AES-256) & **Drift ORM** |
| **Keamanan Kunci** | Android Keystore / iOS Keychain via `FlutterSecureStorage` |
| **Lisensi** | Open Source |

---

## Daftar Isi

1. [Pendahuluan & Tujuan Proyek](#1-pendahuluan--tujuan-proyek)
2. [Arsitektur Perangkat Lunak](#2-arsitektur-perangkat-lunak)
3. [Alur Operasional Sistem (Flowcharts)](#3-alur-operasional-sistem-flowcharts)
4. [Desain Basis Data & Entity Relationship Diagram (ERD)](#4-desain-basis-data--entity-relationship-diagram-erd)
5. [Spesifikasi Keamanan & Kriptografi](#5-spesifikasi-keamanan--kriptografi)
6. [Struktur Kode Sumber (*Source Code Structure*)](#6-struktur-kode-sumber-source-code-structure)
7. [Pengujian Otomatis (*Unit Testing*) & CI/CD](#7-pengujian-otomatis-unit-testing--cicd)
8. [Panduan Instalasi & Deployment](#8-panduan-instalasi--deployment)
9. [Roadmap Pengembangan Lanjutan](#9-roadmap-pengembangan-lanjutan)
10. [Indeks Dokumen Terkait](#10-indeks-dokumen-terkait)
11. [Daftar Referensi & Pustaka Teknis](#11-daftar-referensi--pustaka-teknis)

---

## 1. Pendahuluan & Tujuan Proyek

### 1.1 Latar Belakang
Aplikasi pemindai barcode/QR konvensional seringkali hanya bersifat *stateless* (hanya menampilkan teks hasil scan lalu hilang saat aplikasi ditutup) atau menyimpan data teks polos tanpa perlindungan privasi. Proyek **QR-Scanner** ini dikembangkan untuk mentransformasi utilitas pemindai sederhana menjadi platform manajemen riwayat pemindaian yang **aman (*encrypted at-rest*)**, **terorganisir (Folder & Tag)**, dan **berkinerja tinggi (*offline-first*)**.

### 1.2 Tujuan Utama
1. **Pemindaian Cepat & Akurat**: Mendukung QR Code dan barcode 2D secara *real-time* dengan kontrol kamera terintegrasi.
2. **Penyimpanan Lokal Terenkripsi**: Mengamankan riwayat scan sensitif (seperti kredensial Wi-Fi, kontak vCard, URL token) menggunakan enkripsi standar militer AES-256.
3. **Manajemen Data yang Fleksibel**: Memungkinkan pencarian teks instan, pengelompokan folder, pemberian label *tag*, dan penandaan favorit.
4. **Kesiapan Sinkronisasi Multi-Perangkat**: Skema data dirancang dengan UUID v4 di sisi klien dan tabel *outbox* (`sync_queue`) sehingga siap terhubung ke backend cloud tanpa konflik *primary key*.

---

## 2. Arsitektur Perangkat Lunak

Aplikasi dibangun menggunakan pola **Layered Clean Architecture** yang memisahkan tanggung jawab kode menjadi 4 lapisan utama:

```mermaid
flowchart TB
    subgraph L1["1. Presentation / UI Layer"]
        HP["HomePage (lib/main.dart)<br/>• Hub Utama, Hasil Terakhir & Drawer Navigasi"]
        SCP["ScannerPage (lib/pages/scanner_page.dart)<br/>• Viewfinder mobile_scanner v5, Flash & Flip Kamera<br/>• Mode Standar & Batch Scan + Modal Aksi Cerdas"]
        SHP["ScanHistoryPage (lib/pages/scan_history_page.dart)<br/>• Search Bar, Filter Favorit/Folder/Tag<br/>• Edit Judul/Catatan, Kelola Folder & Tag, Ekspor/Restore"]
        QGP["QRGeneratorPage (lib/pages/qr_generator_page.dart)<br/>• Pembuat QR Kustom (Warna FG/BG & ECC L/M/Q/H)<br/>• Tab Riwayat QR Dibuat"]
        ANP["AnalyticsPage (lib/pages/analytics_page.dart)<br/>• KPI Ringkas, Distribusi Kategori & Format Barcode"]
    end

    subgraph L2["2. Service / Domain Layer"]
        SS["ScanService (lib/services/scan_service.dart)<br/>• CRUD Scan, Update Judul/Catatan, Filter Multi-Kondisi<br/>• Pencatatan Aksi Interaksi (ScanActions)"]
        FTS["FolderTagService (lib/services/folder_tag_service.dart)<br/>• CRUD & Rename Folder, Hapus Tag & Relasi ScanTags (M:N)"]
        SAS["SmartActionService (lib/services/smart_action_service.dart)<br/>• Parser 9 Kategori Konten & Eksekusi url_launcher"]
        QGS["QRGeneratorService (lib/services/qr_generator_service.dart)<br/>• Persistensi & Stream Tabel QRGenerated"]
        ANS["AnalyticsService (lib/services/analytics_service.dart)<br/>• Agregasi KPI, Tren Harian/Mingguan & Ringkasan Teks"]
        EXS["ExportService (lib/services/export_service.dart)<br/>• Ekspor CSV RFC 4180 & Backup/Restore JSON Idempoten"]
    end

    subgraph L3["3. Data Persistence Layer (Drift ORM)"]
        DB["AppDatabase (lib/database/database.dart)<br/>• Singleton Database Connection<br/>• MigrationStrategy & Foreign Keys Enforcement"]
        TBL["Tabel Skema (lib/database/tables.dart)<br/>• 9 Tabel Relasional (Drift DSL)"]
    end

    subgraph L4["4. Security & Hardware Storage Layer"]
        KEY["FlutterSecureStorage<br/>• Android Keystore / iOS Keychain (Kunci 256-bit)"]
        CIPHER[("SQLCipher Native Database (qr_scanner.sqlite)<br/>• Enkripsi AES-256 Halaman Basis Data At-Rest")]
    end

    HP -->|"Navigasi"| SCP
    HP -->|"Navigasi"| SHP
    HP -->|"Navigasi"| QGP
    HP -->|"Navigasi"| ANP
    SCP -->|"Parse Konten & Aksi"| SAS
    SCP -->|"Simpan Scan"| SS
    SAS -->|"Log ScanActions"| SS
    SHP -->|"Stream, Filter & Edit"| SS
    SHP -->|"Kelola Folder & Tag"| FTS
    SHP -->|"Aksi Kontekstual"| SAS
    SHP -->|"Ekspor / Restore"| EXS
    QGP -->|"Simpan & Stream QR"| QGS
    ANP -->|"Laporan Agregat"| ANS
    ANP -->|"Ekspor Cepat"| EXS
    ANS -->|"Query Agregasi"| DB
    EXS -->|"Backup / Restore"| SS
    EXS -->|"Backup / Restore"| FTS
    EXS -->|"Backup / Restore"| QGS
    SS -->|"Operasi DML / DQL"| DB
    FTS -->|"Transaksi Relasi"| DB
    QGS -->|"Operasi DML / DQL"| DB
    DB -->|"Validasi Skema"| TBL
    DB -->|"Ambil Kunci Kriptografi"| KEY
    DB -->|"Enkripsi / Dekripsi I/O"| CIPHER
```

---

## 3. Alur Operasional Sistem (Flowcharts)

### 3.1 Alur Pemindaian Kamera, Batch Mode & Aksi Cerdas
Alur saat pengguna membuka `ScannerPage` hingga data dianalisis, ditindaklanjuti, dan tersimpan:

```mermaid
flowchart TD
    Start(["Buka Aplikasi"]) --> Home["Layar Utama (HomePage)"]
    Home --> PressScan["Pilih 'Scan Kamera' atau 'Mode Batch'"]
    PressScan --> CamOpen["Buka ScannerPage (mobile_scanner v5)<br/>• Kontrol Flash & Ganti Kamera<br/>• Segmented Toggle Standar / Batch"]

    CamOpen --> Capture{"BarcodeCapture.onDetect()"}
    Capture -- "Mode Batch Aktif" --> Debounce{"Duplikat < 1.5 detik?"}
    Debounce -- "Ya" --> Ignore["Abaikan Sementara"]
    Debounce -- "Tidak" --> ParseBatch["SmartActionService.parse() (9 Kategori)"]
    ParseBatch --> SaveBatch["ScanService.insertScan()<br/>+ Tambah ke Baki Sesi Batch"]

    Capture -- "Mode Standar" --> ParseSingle["SmartActionService.parse():<br/>url | wifi | vcard | email |<br/>phone | sms | geo | product | text"]
    ParseSingle --> SaveLocal["ScanService.insertScan()<br/>(SQLCipher AES-256)"]
    SaveLocal --> ShowSheet["Tampilkan Bottom Sheet Aksi Cerdas:<br/>• Atribut Terstruktur & Aksi Native (url_launcher)<br/>• Scan Lagi / Kembali ke Beranda"]
    SaveBatch --> End(["Selesai"])
    ShowSheet --> End
    Ignore --> End
```

### 3.2 Alur Riwayat Scan, Manajemen Folder/Tag & Backup
Alur kerja pada `ScanHistoryPage` terhubung secara reaktif (*reactive stream*):

```mermaid
flowchart TD
    OpenHistory(["Buka Menu Riwayat Scan"]) --> StreamWatch["Berlangganan Stream: watchFilteredScans()"]
    StreamWatch --> FilterEvaluator["Evaluasi Filter Aktif:<br/>1. Kata Kunci (rawValue / title / notes)<br/>2. Status Favorit (isFavorite)<br/>3. Chip Folder Terpilih (folderId)<br/>4. Chip Tag Terpilih (tagId via ScanTags)<br/>5. Data Aktif (isDeleted = false)"]

    FilterEvaluator --> RenderItems["Tampilkan Daftar Scan"]
    RenderItems --> UserAction{"Pilihan Interaksi Pengguna"}

    UserAction -- "Kelola Folder & Tag" --> ManageSheet["Sheet Kelola: Buat / Rename / Hapus Folder & Hapus Tag"]
    UserAction -- "Ekspor / Restore" --> ExportSheet["Ekspor CSV (RFC 4180) atau<br/>Backup/Restore JSON Idempoten"]
    UserAction -- "Salin / Bintang / Swipe" --> QuickAct["Salin (+ log SCAN_ACTIONS) / Toggle Favorit / Soft Delete"]
    UserAction -- "Ketuk Item" --> DetailModal["Dialog Detail Scan:<br/>• Edit & Simpan Judul + Catatan<br/>• Aksi Cerdas Kontekstual<br/>• Atur Folder & Pasang/Buat Tag"]

    ManageSheet --> StreamWatch
    ExportSheet --> StreamWatch
    QuickAct --> StreamWatch
    DetailModal --> StreamWatch
```

---

## 4. Desain Basis Data & Entity Relationship Diagram (ERD)

Basis data dirancang dengan spesifikasi **9 entitas** terorganisir untuk mengakomodasi kebutuhan lokal saat ini dan sinkronisasi cloud di masa depan:

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
        string email UK
        string display_name
        string auth_provider
        timestamp created_at
        timestamp updated_at
    }

    DEVICES {
        uuid id PK
        uuid user_id FK
        string platform
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
        uuid folder_id FK
        text raw_value
        string content_type
        string barcode_format
        string title
        text notes
        boolean is_favorite
        boolean is_deleted
        string sync_status
        timestamp scanned_at
        timestamp updated_at
    }

    QR_GENERATED {
        uuid id PK
        uuid user_id FK
        string content_type
        text payload
        string fg_color_hex
        string bg_color_hex
        string error_correction
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
        string action_type
        timestamp performed_at
    }

    SYNC_QUEUE {
        uuid id PK
        uuid device_id FK
        string entity_type
        uuid entity_id
        string operation
        text payload_json
        int retry_count
        string status
        timestamp created_at
    }
```

### Ringkasan Fungsi Entitas
1. **`USERS` & `DEVICES`**: Identitas pengguna lokal (anonim) dan metadata perangkat untuk atribusi sinkronisasi.
2. **`FOLDERS`**: Kategori pengelompokan scan (`1:N` terhadap `SCAN_HISTORY`).
3. **`SCAN_HISTORY`**: Tabel inti transaksi pemindaian QR/barcode.
4. **`TAGS` & `SCAN_TAGS`**: Relasi banyak-ke-banyak (*many-to-many*) untuk pelabelan fleksibel dengan *Composite Primary Key* `(scan_id, tag_id)` dan aturan `ON DELETE CASCADE`.
5. **`SCAN_ACTIONS`**: Catatan riwayat interaksi pengguna (`copy`, `open_url`, `share`).
6. **`QR_GENERATED`**: Menyimpan riwayat pembuatan QR code kustom.
7. **`SYNC_QUEUE`**: Antrean *Transactional Outbox* untuk pengiriman data saat terhubung ke server cloud.

*(Spesifikasi lengkap kamus data dan skrip DDL SQL dapat dilihat pada [doc/DATABASE.md](DATABASE.md)).*

---

## 5. Spesifikasi Keamanan & Kriptografi

Aplikasi menerapkan perlindungan data berlapis:

1. **Enkripsi File Basis Data (*Encryption at Rest*)**:
   - Seluruh blok file basis data `qr_scanner.sqlite` dienkripsi menggunakan library native **SQLCipher** dengan algoritma **AES-256-CBC**.
   - Integritas data diverifikasi pada setiap pembukaan menggunakan `PRAGMA cipher_version;`.
2. **Penyimpanan Kunci Kriptografi Aman**:
   - Kunci enkripsi dibangkitkan secara kriptografis menggunakan generator bilangan acak perangkat keras (`Random.secure()`) sepanjang 256-bit (32 byte).
   - Kunci disimpan menggunakan `FlutterSecureStorage`:
     - **Android**: Tersimpan di **Android Keystore System** menggunakan enkripsi AES master key (`encryptedSharedPreferences: true`).
     - **iOS**: Tersimpan di **iOS Keychain Services** dengan akses yang terikat pada sandbox aplikasi.
3. **Pencegahan Kehilangan Data & Konflik (*Data Integrity*)**:
   - Penerapan *Soft Delete* (`is_deleted = true`) mencegah hilangnya riwayat lokal secara tidak sengaja dan memfasilitasi rekonsiliasi data pada sinkronisasi cloud.
   - Pembangkitan UUID v4 di sisi klien mencegah benturan ID (*primary key collision*) saat sinkronisasi multi-perangkat.

---

## 6. Struktur Kode Sumber (*Source Code Structure*)

```text
QR-Scanner/
├── .github/
│   └── workflows/
│       ├── flutter_test.yml       # CI: Analyze, Build Drift, Unit/Widget Test & APK Build
│       └── release.yml            # CD: Publikasi GitHub Release & Lampiran PDF Otomatis
├── android/                       # Android Embedding v2, Gradle 8.5.2 & AndroidManifest
├── ios/                           # iOS Runner, Podfile (iOS 12.0+) & Info.plist
├── doc/                           # Dokumentasi Teknis Lengkap
│   ├── DATABASE.md                # Kamus Data & DDL SQL (SQLite / PostgreSQL)
│   ├── DOKUMENTASI_PROYEK.md      # Dokumen Resmi Master Proyek (File ini)
│   ├── DOKUMENTASI_PROYEK.html    # Ekspor HTML Resmi Dokumentasi Proyek
│   ├── DOKUMENTASI_PROYEK.pdf     # Ekspor PDF Siap Cetak Dokumentasi Proyek
│   ├── FLOWCHART.md               # Diagram Alur Lengkap Sistem
│   ├── PANDUAN_PENGGUNAAN.md      # Panduan Operasional Pengguna & Developer
│   └── RINGKASAN_PERBAIKAN.md     # Rekapitulasi Riwayat Pengembangan
├── lib/
│   ├── database/
│   │   ├── database.dart          # Singleton AppDatabase & Engine SQLCipher
│   │   └── tables.dart            # Definisi 9 Tabel Relasional (Drift ORM)
│   ├── pages/
│   │   ├── analytics_page.dart    # Dashboard Statistik & Distribusi Kategori
│   │   ├── qr_generator_page.dart # Pembuat QR Kustom & Tab Riwayat QR Dibuat
│   │   ├── scan_history_page.dart # Riwayat, Search, Filter Folder/Tag, Notes & Export
│   │   └── scanner_page.dart      # Viewfinder mobile_scanner v5, Batch & Smart Actions
│   ├── services/
│   │   ├── analytics_service.dart   # Layanan Agregasi Statistik & Laporan Ringkas
│   │   ├── export_service.dart      # Layanan Ekspor CSV RFC 4180 & Restore JSON Idempoten
│   │   ├── folder_tag_service.dart  # Layanan CRUD/Rename Folder, Hapus Tag & ScanTags
│   │   ├── qr_generator_service.dart# Layanan Persistensi Tabel QRGenerated
│   │   ├── scan_service.dart        # Layanan CRUD Scan, Update Notes, Filter & Actions
│   │   └── smart_action_service.dart# Parser 9 Tipe Konten & Eksekusi url_launcher
│   └── main.dart                  # Entry Point Aplikasi, Beranda & Drawer Navigasi
├── test/
│   ├── database_test.dart         # Suite Unit Test In-Memory DB & Seluruh Service
│   └── widget_test.dart           # Smoke Test Antarmuka HomePage
├── pubspec.yaml                   # Manifest Dependensi Proyek Flutter
└── README.md                      # Halaman Utama Repositori GitHub
```

---

## 7. Pengujian Otomatis (*Unit Testing*) & CI/CD

Proyek dilengkapi dengan pipeline jaminan kualitas (*Quality Assurance*) dan rilis otomatis:

### 7.1 Cakupan Unit & Widget Test (`test/`)
- **Verifikasi UUID & Default Value (`test/database_test.dart`)**: Memastikan kolom `id` menghasilkan UUID v4 36-karakter serta default `sync_status = 'pending'`.
- **Logika Bisnis Scan (`ScanService`)**: Pengujian `insertScan`, `updateScanDetails` (edit & reset judul/catatan), toggle favorit, serta *soft delete*.
- **Pencarian & Multi-Filter**: Pengujian `searchScans` terhadap kombinasi kata kunci (`rawValue`/`title`/`notes`), status favorit, `folderId`, dan `tagId` (subquery `ScanTags`).
- **Relasi, Rename & Cascade (`FolderTagService`)**: Pengujian *composite primary key* `ScanTags`, `renameFolder`, `deleteTag`, serta `ON DELETE CASCADE` dan detaching folder saat `deleteFolder`.
- **QR Generator (`QRGeneratorService`) & Batch Scanning**: Verifikasi persistensi kustomisasi warna/`errorCorrection`, urutan kronologis batch, serta *soft delete*.
- **Analitik (`AnalyticsService`)**: Verifikasi agregasi KPI, jumlah harian/mingguan, distribusi tipe & format, serta teks laporan ringkasan.
- **Ekspor & Backup Idempoten (`ExportService`)**: Validasi *escaping* CSV RFC 4180 serta siklus backup & restore JSON (folder, tag, relasi `ScanTags`, scan, dan QR dibuat) tanpa duplikasi pada restore berulang.
- **Parser Aksi Cerdas (`SmartActionService`)**: Pengujian parsing `URL`, `WIFI`, `vCard`, `tel`, `smsto`, `geo`, dan barcode produk.
- **Widget Smoke Test (`test/widget_test.dart`)**: Memverifikasi `HomePage` serta kontrol navigasi utama (`QR Scanner`, `Scan Kamera`, `Mode Batch`, `Statistik`) ter-render dengan benar.

### 7.2 Integrasi & Rilis Berkelanjutan (*CI/CD*)
1. **Continuous Integration ([.github/workflows/flutter_test.yml](../.github/workflows/flutter_test.yml))**: Berjalan otomatis pada setiap *push* atau *pull request* ke `main`:
   - Menyiapkan lingkungan Ubuntu (`libsqlite3-dev`), **Java 17 (Temurin)**, dan **Flutter SDK stable**.
   - Menjalankan `flutter pub get` dan `dart run build_runner build --delete-conflicting-outputs`.
   - Menjalankan analisis statis `flutter analyze --no-fatal-infos`.
   - Mengeksekusi seluruh pengujian `flutter test` (`database_test.dart` & `widget_test.dart`).
   - Memverifikasi kompilasi Android via `flutter build apk --debug`.
2. **Continuous Delivery ([.github/workflows/release.yml](../.github/workflows/release.yml))**: Berjalan otomatis setiap ada *push* tag `v*` untuk mempublikasikan **GitHub Release** beserta berkas PDF dokumentasi proyek.

---

## 8. Panduan Instalasi & Deployment

### 8.1 Prasyarat Sistem
- **Flutter SDK**: Versi 3.0.0 ke atas.
- **Android Studio / VS Code**: Terpasang Flutter & Dart extension.
- **JDK**: Versi 17 atau yang kompatibel dengan Gradle 8.x.
- **Xcode** (khusus macOS untuk target iOS).

### 8.2 Langkah Instalasi

1. **Clone Repositori**:
   ```bash
   git clone https://github.com/bagussatoto/QR-Scanner.git
   cd QR-Scanner
   ```

2. **Unduh Dependensi**:
   ```bash
   flutter pub get
   ```

3. **Generate Kode Drift ORM**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Jalankan Analisis Statis & Seluruh Pengujian**:
   ```bash
   flutter analyze --no-fatal-infos
   flutter test
   ```

5. **Jalankan Aplikasi pada Emulator/Perangkat Fisik**:
   ```bash
   flutter run
   ```

---

## 9. Roadmap Pengembangan Lanjutan

| Fase | Target | Fokus Pengembangan | Status |
| :--- | :--- | :--- | :--- |
| **Fase 1** | `v1.1.0` | Skema basis data lokal Drift, operasi CRUD scan, folder, tag, pencarian, dan filter favorit. | **Selesai (100%)** |
| **Fase 2** | `v1.2.0` | Modernisasi pemindai kamera (`mobile_scanner`), mode **Batch Scanning**, **Aksi Cerdas Kontekstual** (`SmartActionService`), generator QR code (`qr_flutter`), **Dashboard Analitik**, serta **Ekspor/Backup CSV & JSON** (`ExportService`). | **Selesai (100%)** |
| **Fase 3** | `v2.0.0` | Sinkronisasi *offline-first* ke server cloud (PostgreSQL / Supabase) menggunakan tabel `SYNC_QUEUE` (*outbox pattern*), autentikasi akun pengguna, dan Row-Level Security (RLS). | **Tabel Siap di Skema** |
| **Fase 4** | `v2.1.0+` | Enkripsi *at-rest* SQLCipher AES-256, kebijakan retensi arsip otomatis, dan optimasi performa skala besar. | **Enkripsi Lokal Selesai** |

---

## 10. Indeks Dokumen Terkait

Dokumentasi teknis pendukung yang tersedia pada folder [`doc/`](./):
- [doc/DATABASE.md](DATABASE.md) — Kamus data detail per kolom, indeks performa, serta skrip DDL SQL untuk SQLite dan PostgreSQL.
- [doc/FLOWCHART.md](FLOWCHART.md) — Seluruh diagram alur sistem, arsitektur data, dan alur CI.
- [doc/PANDUAN_PENGGUNAAN.md](PANDUAN_PENGGUNAAN.md) — Panduan visual langkah demi langkah bagi pengguna akhir dan pengembang.
- [doc/RINGKASAN_PERBAIKAN.md](RINGKASAN_PERBAIKAN.md) — Rekapitulasi historis pembaruan dan implementasi fitur yang telah selesai dilakukan.

---

## 11. Daftar Referensi & Pustaka Teknis

Pengembangan arsitektur, basis data, keamanan, dan fungsionalitas aplikasi ini mengacu pada standar industri dan dokumentasi resmi berikut:

### 11.1 Framework & Bahasa Pemrograman
- **Flutter Official Documentation**: Panduan arsitektur aplikasi mobile, siklus hidup widget, dan manajemen status.  
  Tautan: [https://docs.flutter.dev/](https://docs.flutter.dev/)
- **Dart Language Tour & Specification**: Spesifikasi bahasa Dart 3.x, sistem tipe *sound null safety*, serta pustaka asynchronous (`async`/`await`/`Stream`).  
  Tautan: [https://dart.dev/guides](https://dart.dev/guides)

### 11.2 Basis Data & ORM (Drift & SQLite)
- **Drift (formerly Moor) Documentation**: Dokumentasi resmi ORM Drift untuk Flutter, mencakup DSL tabel, generator `build_runner`, migrasi skema, dan unit testing in-memory.  
  Tautan: [https://drift.simonbinder.eu/](https://drift.simonbinder.eu/)
- **SQLite Database Engine Specification**: Standar engine SQLite, dukungan relasi `PRAGMA foreign_keys`, indeks komposit, serta *full-text search* (FTS5).  
  Tautan: [https://www.sqlite.org/docs.html](https://www.sqlite.org/docs.html)

### 11.3 Keamanan, Kriptografi & Penyimpanan Kunci
- **OWASP Mobile Application Security (MAS / MSTG)**: Standar pengujian keamanan aplikasi mobile industri internasional mencakup penyimpanan data aman (*Data Storage*), kriptografi (*Cryptography*), dan autentikasi.  
  Tautan: [https://mas.owasp.org/](https://mas.owasp.org/)
- **NIST SP 800-38D**: Standar kriptografi National Institute of Standards and Technology untuk rekomendasi mode operasi Galois/Counter Mode (GCM) dan enkripsi blok lanjutan AES.  
  Tautan: [https://csrc.nist.gov/publications/detail/sp/800-38d/final](https://csrc.nist.gov/publications/detail/sp/800-38d/final)
- **Zetetic SQLCipher Cryptographic Design**: Arsitektur enkripsi basis data tingkat halaman (*page-level*) berbasis AES-256-CBC, PBKDF2 HMAC-SHA512 key derivation, dan MAC integritas halaman.  
  Tautan: [https://www.zetetic.net/sqlcipher/design/](https://www.zetetic.net/sqlcipher/design/)
- **Android Keystore System Guide**: Praktik terbaik Google untuk enkripsi master key di Android menggunakan hardware-backed security (TEE/SE) dan `EncryptedSharedPreferences`.  
  Tautan: [https://developer.android.com/training/articles/keystore](https://developer.android.com/training/articles/keystore)
- **Apple iOS Keychain Services API**: Panduan keamanan Apple untuk penyimpanan item sensitif dan sertifikat/kunci kriptografi pada *Secure Enclave*.  
  Tautan: [https://developer.apple.com/documentation/security/keychain_services](https://developer.apple.com/documentation/security/keychain_services)
- **Flutter Secure Storage Library**: Spesifikasi plugin penyimpanan aman multi-platform berbasis Keystore & Keychain.  
  Tautan: [https://pub.dev/packages/flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)

### 11.4 Standar Format Barcode & QR Code
- **ISO/IEC 18004:2015**: Standar internasional teknologi informasi — *Automatic identification and data capture techniques — QR Code bar code symbology specification*.
- **ISO/IEC 15420:2009**: Standar spesifikasi symbology barcode linear internasional EAN/UPC (*EAN-13, EAN-8, UPC-A, UPC-E*).
- **RFC 6350 (vCard Format)**: Standar format pertukaran data kartu kontak elektronik.  
  Tautan: [https://datatracker.ietf.org/doc/html/rfc6350](https://datatracker.ietf.org/doc/html/rfc6350)
- **ZXing Barcode Format & Wi-Fi URI Scheme**: Spesifikasi sintaks decoding untuk barcode 1D/2D dan payload Wi-Fi (`WIFI:S:...;T:...;P:...;;`).  
  Tautan: [https://github.com/zxing/zxing/wiki/Barcode-Contents](https://github.com/zxing/zxing/wiki/Barcode-Contents)
- **Flutter `mobile_scanner` Package**: Pustaka pemindai barcode & QR code modern berbasis Google ML Kit dengan kontrol kamera fleksibel (flash/torch, pergantian kamera depan/belakang, dan viewfinder kustom).  
  Tautan: [https://pub.dev/packages/mobile_scanner](https://pub.dev/packages/mobile_scanner)

### 11.5 Pola Desain Perangkat Lunak (*Software Architecture Patterns*)
- **Martin Fowler — Clean Architecture & Presentation-Domain-Data Layering**: Panduan pola arsitektur pemisahan tanggung jawab antarmuka pengguna, layanan aplikasi, dan penyimpanan data.  
  Tautan: [https://martinfowler.com/architecture/](https://martinfowler.com/architecture/)
- **Martin Fowler — Transactional Outbox Pattern**: Arsitektur pengiriman event asinkron yang andal untuk sinkronisasi offline-first (`sync_queue`).  
  Tautan: [https://microservices.io/patterns/data/transactional-outbox.html](https://microservices.io/patterns/data/transactional-outbox.html)
- **Google Material Design 3 Guidelines**: Panduan sistem desain antarmuka, navigasi drawer, skema warna adaptif, kontras tinggi, dan aksesibilitas komponen UI.  
  Tautan: [https://m3.material.io/](https://m3.material.io/)
- **RFC 4122 (A Universally Unique IDentifier - UUID URN Namespace)**: Pembangkitan UUID v4 berbasis nilai acak (pseudo-random) untuk identitas record terdistribusi.  
  Tautan: [https://datatracker.ietf.org/doc/html/rfc4122](https://datatracker.ietf.org/doc/html/rfc4122)
- **RFC 4180 (Common Format and MIME Type for CSV Files)**: Standar internasional pemformatan dan *escaping* tanda kutip/koma pada ekspor tabel CSV.  
  Tautan: [https://datatracker.ietf.org/doc/html/rfc4180](https://datatracker.ietf.org/doc/html/rfc4180)
- **Mermaid JavaScript Charting Documentation**: Standar penulisan diagram Mermaid (`erDiagram`, `flowchart`, `sequenceDiagram`) pada Markdown.  
  Tautan: [https://mermaid.js.org/](https://mermaid.js.org/)


