# Dokumentasi Diagram Flowchart — Aplikasi QR-Scanner

Dokumen ini berisi kumpulan diagram alur (*flowchart*) lengkap untuk sistem **Flutter QR-Scanner**, mulai dari arsitektur lapisan, proses pemindaian kamera, enkripsi basis data **SQLCipher**, manajemen riwayat scan, pengelolaan Folder & Tag, hingga alur pengujian otomatis (CI).

---

## Daftar Isi

1. [Flowchart Arsitektur Lapisan Sistem](#1-flowchart-arsitektur-lapisan-sistem)
2. [Flowchart Pemindaian QR/Barcode & Penyimpanan Otomatis](#2-flowchart-pemindaian-qrbarcode--penyimpanan-otomatis)
3. [Flowchart Enkripsi Basis Data (SQLCipher & Keystore/Keychain)](#3-flowchart-enkripsi-basis-data-sqlcipher--keystorekeychain)
4. [Flowchart Halaman Riwayat Scan (Pencarian, Filter, Copy & Soft Delete)](#4-flowchart-halaman-riwayat-scan-pencarian-filter-copy--soft-delete)
5. [Flowchart Manajemen Folder & Tag (Relasi 1:N dan M:N)](#5-flowchart-manajemen-folder--tag-relasi-1n-dan-mn)
6. [Flowchart Pipeline Pengujian Otomatis (GitHub Actions CI)](#6-flowchart-pipeline-pengujian-otomatis-github-actions-ci)

---

## 1. Flowchart Arsitektur Lapisan Sistem

Menjelaskan hubungan aliran data antar-lapisan dari antarmuka pengguna (*Presentation Layer*), logika layanan (*Service Layer*), hingga penyimpanan lokal terenkripsi (*Encrypted Persistence Layer*):

```mermaid
flowchart TB
    subgraph UI["1. Presentation / UI Layer"]
        HP["HomePage (lib/main.dart)<br/>Pemindai Kamera, AppBar & Drawer"]
        SHP["ScanHistoryPage (lib/pages/scan_history_page.dart)<br/>Search Bar, ChoiceChip Folder, Filter Favorit & Dialog Detail"]
    end

    subgraph SVC["2. Service Layer"]
        SS["ScanService (lib/services/scan_service.dart)<br/>insertScan, searchScans, watchFilteredScans,<br/>toggleFavorite, deleteScan, logAction"]
        FTS["FolderTagService (lib/services/folder_tag_service.dart)<br/>createFolder, deleteFolder, createTag,<br/>assignTagToScan, removeTagFromScan"]
    end

    subgraph DATA["3. Encrypted Persistence Layer"]
        DB["AppDatabase (lib/database/database.dart)<br/>Drift ORM + MigrationStrategy (PRAGMA foreign_keys = ON)"]
        CIPHER[("SQLCipher (qr_scanner.sqlite)<br/>Enkripsi AES-256 At-Rest")]
        KEY["FlutterSecureStorage<br/>Android Keystore / iOS Keychain (Kunci 256-bit)"]
    end

    HP -->|"Simpan Hasil Scan"| SS
    HP -->|"Navigasi"| SHP
    SHP -->|"Stream & Aksi Scan"| SS
    SHP -->|"Kelola Folder & Tag"| FTS
    SS -->|"Query & Mutasi"| DB
    FTS -->|"Query & Transaksi"| DB
    DB -->|"Baca / Tulis Terenkripsi"| CIPHER
    DB -->|"Ambil / Simpan Kunci"| KEY
```

---

## 2. Flowchart Pemindaian QR/Barcode & Penyimpanan Otomatis

Menjelaskan alur kerja saat pengguna menekan tombol **Scan** di halaman utama (`lib/main.dart`):

```mermaid
flowchart TD
    Start(["Mulai: Pengguna Buka Aplikasi"]) --> RenderHome["Tampilkan HomePage (lib/main.dart)"]
    RenderHome --> PressScan["Pengguna Tekan Tombol 'Scan'"]
    PressScan --> CallPlugin["Panggil BarcodeScanner.scan()"]
    CallPlugin --> CheckPerm{"Status Eksekusi Kamera"}

    CheckPerm -- "PlatformException<br/>(CameraAccessDenied)" --> MsgDenied["Set State Result:<br/>'Camera permission was denied'"]
    CheckPerm -- "FormatException<br/>(Tombol Back Ditekan)" --> MsgCancel["Set State Result:<br/>'You pressed the back button before scanning anything'"]
    CheckPerm -- "Error Lainnya" --> MsgErr["Set State Result:<br/>'Unknown Error'"]
    CheckPerm -- "Berhasil Membaca QR/Barcode" --> SetResult["Perbarui Teks Hasil di Layar Utama"]

    SetResult --> DetectType["Deteksi Tipe Konten (_detectContentType)<br/>• http:// atau https:// -> 'url'<br/>• WIFI: -> 'wifi'<br/>• BEGIN:VCARD -> 'vcard'<br/>• geo: -> 'geo'<br/>• Lainnya -> 'text'"]
    DetectType --> SaveScan["Panggil ScanService.instance.insertScan()"]
    SaveScan --> EnsureUser["Pastikan Baris Lokal Users & Devices Tersedia"]
    EnsureUser --> InsertDB["Insert ke Tabel SCAN_HISTORY<br/>(UUID v4 otomatis, syncStatus = 'pending')"]

    MsgDenied --> End(["Selesai"])
    MsgCancel --> End
    MsgErr --> End
    InsertDB --> End
```

---

## 3. Flowchart Enkripsi Basis Data (SQLCipher & Keystore/Keychain)

Menjelaskan alur pembukaan basis data terenkripsi di `lib/database/database.dart`:

```mermaid
flowchart TD
    OpenReq(["Permintaan Koneksi Pertama ke AppDatabase"]) --> CheckOS{"Platform Android?"}
    CheckOS -- "Ya" --> OverrideAndroid["Override sqlite3 open dengan openCipherOnAndroid<br/>& applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()"]
    CheckOS -- "Tidak (iOS)" --> ResolveDir["Ambil Direktori Dokumen Aplikasi<br/>(getApplicationDocumentsDirectory)"]
    OverrideAndroid --> ResolveDir

    ResolveDir --> ReadKey["Baca Kunci 'qr_scanner_db_key' dari<br/>FlutterSecureStorage (Keystore / Keychain)"]
    ReadKey --> HasKey{"Kunci Sudah Ada?"}

    HasKey -- "Belum Ada (Instalasi Pertama)" --> GenKey["Bangkitkan Kunci Acak 32-Byte (256-bit)<br/>menggunakan Random.secure()"]
    GenKey --> SaveKey["Simpan Kunci Hex ke FlutterSecureStorage"]
    SaveKey --> InitIsolate

    HasKey -- "Sudah Ada" --> InitIsolate["Jalankan NativeDatabase.createInBackground<br/>pada File qr_scanner.sqlite"]
    InitIsolate --> VerifyCipher{"Cek PRAGMA cipher_version;"}

    VerifyCipher -- "Kosong (SQLCipher Tidak Aktif)" --> ThrowErr["Lempar UnsupportedError<br/>(Mencegah Database Tersimpan Tanpa Enkripsi)"]
    VerifyCipher -- "Tersedia" --> ApplyKey["Eksekusi PRAGMA key = \"x'<hexKey>'\";<br/>& PRAGMA foreign_keys = ON;"]
    ApplyKey --> Ready(["Database Siap Digunakan (Terenkripsi AES-256)"])
```

---

## 4. Flowchart Halaman Riwayat Scan (Pencarian, Filter, Copy & Soft Delete)

Menjelaskan alur interaktif pada halaman `ScanHistoryPage` (`lib/pages/scan_history_page.dart`):

```mermaid
flowchart TD
    OpenPage(["Pengguna Buka Halaman Riwayat Scan"]) --> SubStream["StreamBuilder Berlangganan ke<br/>ScanService.watchFilteredScans()"]
    SubStream --> EvalFilter["Evaluasi Query SQL:<br/>• isDeleted = false<br/>• Jika Filter Favorit aktif -> isFavorite = true<br/>• Jika Folder dipilih -> folderId = selectedFolderId<br/>• Jika Search diisi -> rawValue / title / notes LIKE '%query%'<br/>• Urutkan scannedAt DESC"]

    EvalFilter --> HasData{"Ada Data yang Cocok?"}
    HasData -- "Tidak Ada" --> EmptyState["Tampilkan Pesan:<br/>'Tidak ada hasil pemindaian yang cocok.'"]
    HasData -- "Ada" --> RenderList["Tampilkan Daftar ListTile Riwayat Scan"]

    RenderList --> Action{"Aksi Pengguna"}

    Action -- "Ketik di Search Bar /<br/>Klik Filter Favorit /<br/>Pilih Chip Folder" --> UpdateFilterState["setState() Perbarui Parameter Filter"]
    UpdateFilterState --> EvalFilter

    Action -- "Klik Ikon Bintang" --> ToggleFav["ScanService.toggleFavorite()<br/>Balik Nilai isFavorite & Perbarui updatedAt"]
    ToggleFav --> SubStream

    Action -- "Geser Item ke Kiri (Dismissible)" --> SoftDelete["ScanService.deleteScan()<br/>Ubah isDeleted = true (Data Tetap Ada untuk Sync)"]
    SoftDelete --> SubStream

    Action -- "Klik Tombol Salin (Copy)" --> CopyClip["1. Salin rawValue ke Clipboard<br/>2. ScanService.logAction(actionType: 'copy') ke SCAN_ACTIONS<br/>3. Tampilkan SnackBar Konfirmasi"]
```

---

## 5. Flowchart Manajemen Folder & Tag (Relasi 1:N dan M:N)

Menjelaskan alur pengorganisasian scan ke dalam **Folder** dan **Tag** melalui `FolderTagService` (`lib/services/folder_tag_service.dart`):

```mermaid
flowchart TD
    TapItem(["Pengguna Klik Item Scan di Riwayat"]) --> LoadMeta["Muat Daftar Folder (getAllFolders),<br/>Semua Tag (getAllTags), & Tag Scan Ini (getTagsForScan)"]
    LoadMeta --> ShowDialog["Tampilkan Dialog Detail Scan"]

    ShowDialog --> DialogAct{"Pilihan Aksi di Dialog"}

    DialogAct -- "Ubah Dropdown Folder" --> MoveFolder["ScanService.assignFolder(scanId, newFolderId)<br/>Update kolom folder_id pada SCAN_HISTORY"]
    MoveFolder --> RefreshUI["Perbarui State Dialog & Stream Riwayat"]

    DialogAct -- "Klik '+ Tag Baru'" --> InputTag["Tampilkan Dialog Input Nama Tag"]
    InputTag --> CreateTag["FolderTagService.createTag()<br/>Insert ke Tabel TAGS"]
    CreateTag --> AttachNewTag["FolderTagService.assignTagToScan()<br/>Insert ke Tabel SCAN_TAGS (insertOrIgnore)"]
    AttachNewTag --> RefreshUI

    DialogAct -- "Klik FilterChip Tag" --> CheckSelected{"Chip Dipilih atau Dilepas?"}
    CheckSelected -- "Dipilih (Selected = true)" --> AttachTag["FolderTagService.assignTagToScan()<br/>Insert (scan_id, tag_id) ke SCAN_TAGS"]
    CheckSelected -- "Dilepas (Selected = false)" --> DetachTag["FolderTagService.removeTagFromScan()<br/>Hapus baris (scan_id, tag_id) dari SCAN_TAGS"]
    AttachTag --> RefreshUI
    DetachTag --> RefreshUI
```

---

## 6. Flowchart Pipeline Pengujian Otomatis (GitHub Actions CI)

Menjelaskan alur kerja otomatis pada `.github/workflows/flutter_test.yml` setiap kali ada `push` atau `pull_request` ke branch `main`:

```mermaid
flowchart LR
    Trigger(["Git Push / Pull Request<br/>ke Branch main"]) --> Checkout["Checkout Kode Repositori<br/>(actions/checkout@v4)"]
    Checkout --> InstallSQLite["Instal Native SQLite3 Linux<br/>(apt-get install libsqlite3-dev)"]
    InstallSQLite --> SetupFlutter["Siapkan Flutter SDK Stable<br/>(subosito/flutter-action@v2)"]
    SetupFlutter --> PubGet["Unduh Paket Dependensi<br/>(flutter pub get)"]
    PubGet --> BuildRunner["Generate Kode ORM Drift<br/>(dart run build_runner build)"]
    BuildRunner --> RunTest["Jalankan Unit Test In-Memory<br/>(flutter test test/database_test.dart)"]
    RunTest --> Result{"Semua Test Lulus?"}
    Result -- "Ya" --> Pass(["Status CI: Hijau (Passed)"])
    Result -- "Tidak" --> Fail(["Status CI: Merah (Failed)"])
```

