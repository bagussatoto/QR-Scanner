# Panduan Penggunaan Aplikasi — QR-Scanner

Dokumen ini menjelaskan alur operasional, diagram alur langkah demi langkah (*flowchart*), dan panduan teknis cara menggunakan aplikasi **Flutter QR-Scanner** bagi pengguna akhir (*end-user*) maupun pengembang (*developer*).

---

## Daftar Isi

1. [Alur Singkat Penggunaan (Overview)](#1-alur-singkat-penggunaan-overview)
2. [Diagram & Panduan Langkah demi Langkah](#2-diagram--panduan-langkah-demi-langkah)
   - [A. Memindai QR Code atau Barcode](#a-memindai-qr-code-atau-barcode-homepage)
   - [B. Membuka, Mencari & Memfilter Riwayat Scan](#b-membuka-mencari--memfilter-riwayat-scan)
   - [C. Mengelola Item Scan (Salin, Favorit, Folder, Tag & Hapus)](#c-mengelola-item-scan-salin-favorit-folder-tag--hapus)
3. [Panduan Developer & Cara Menjalankan Aplikasi](#3-panduan-developer--cara-menjalankan-aplikasi)
4. [Flowchart Implementasi Teknis Kode](#4-flowchart-implementasi-teknis-kode)

---

## 1. Alur Singkat Penggunaan (Overview)

Berikut adalah gambaran besar perjalanan pengguna (*user journey*) dari pertama kali membuka aplikasi hingga mengelola data hasil pemindaian:

```mermaid
flowchart LR
    A(["1. Buka Aplikasi"]) --> B["2. Tekan Tombol 'Scan'"]
    B --> C["3. Arahkan Kamera ke QR/Barcode"]
    C --> D["4. Hasil Tampil & Tersimpan Otomatis"]
    D --> E(["5. Kelola di Menu 'Riwayat Scan'"])
```

---

## 2. Diagram & Panduan Langkah demi Langkah

### A. Memindai QR Code atau Barcode (`HomePage`)

Proses pemindaian dilakukan langsung dari layar utama dengan dukungan deteksi tipe data otomatis dan enkripsi lokal:

```mermaid
flowchart TD
    A(["Mulai: Buka Aplikasi"]) --> B["Layar Utama (HomePage)"]
    B --> C["Tekan Tombol 'Scan' (Tombol Oranye)"]
    C --> D{"Izin Akses Kamera"}
    
    D -- "Belum Pernah Diminta" --> E["Muncul Dialog Izin Kamera OS"]
    E -- "Ditolak" --> F["Pesan: 'Camera permission was denied'"]
    E -- "Diberikan" --> G["Kamera Pemindai Aktif"]
    D -- "Sudah Diberikan" --> G
    
    G --> H{"Aksi Pengguna"}
    H -- "Tekan Tombol Kembali (Batal)" --> I["Pesan: 'You pressed the back button before scanning anything'"]
    H -- "Arahkan ke QR / Barcode" --> J["QR / Barcode Berhasil Terbaca"]
    
    J --> K["Deteksi Otomatis Tipe Konten:<br/>• URL (http/https)<br/>• Wi-Fi (WIFI:)<br/>• Kontak vCard (BEGIN:VCARD)<br/>• Lokasi Geo (geo:)<br/>• Teks Biasa / Barcode Produk"]
    K --> L["Simpan Otomatis ke Database Terenkripsi<br/>(SQLCipher AES-256)"]
    L --> M["Tampilkan Isi Hasil Scan di Layar Utama"]
    M --> N(["Selesai"])
    F --> N
    I --> N
```

#### Langkah Operasional:
1. Buka aplikasi **QR-Scanner**.
2. Tekan tombol mengambang berwarna oranye bertuliskan **Scan** di tengah bawah layar.
3. Pilih **Allow / Izinkan** saat sistem meminta izin akses kamera.
4. Arahkan lensa kamera ke arah QR Code atau Barcode.
5. Begitu kode terbaca:
   - Teks hasil scan langsung ditampilkan di tengah layar.
   - Data otomatis tersimpan dengan aman ke tabel `SCAN_HISTORY` di dalam database terenkripsi **SQLCipher**.

---

### B. Membuka, Mencari & Memfilter Riwayat Scan

Halaman **Riwayat Scan** menyajikan data secara *real-time* dengan fitur pencarian teks dan filter multi-level:

```mermaid
flowchart TD
    A(["Pengguna di Layar Utama"]) --> B{"Cara Membuka Riwayat"}
    B -- "Opsi 1" --> C["Tekan Ikon Jam di AppBar (Kanan Atas)"]
    B -- "Opsi 2" --> D["Buka Menu Drawer (Kiri Atas) -> Pilih 'Riwayat Scan'"]
    
    C --> E["Halaman Riwayat Scan (ScanHistoryPage)"]
    D --> E
    
    E --> F["Daftar Scan Ditampilkan (Real-time Stream)"]
    F --> G{"Opsi Pencarian & Filter"}
    
    G -- "Pencarian Kata Kunci" --> H["Ketik pada Kolom Pencarian:<br/>Mencari teks isi, judul, atau catatan"]
    G -- "Filter Favorit" --> I["Tekan Ikon Bintang di AppBar:<br/>Hanya menampilkan item berbintang"]
    G -- "Filter per Folder" --> J["Ketuk Chip Nama Folder:<br/>Contoh: 'Semua', 'Kerja', 'Pribadi'"]
    G -- "Buat Folder Baru" --> K["Tekan Ikon Folder (+) di AppBar:<br/>Ketik nama folder -> Klik 'Simpan'"]
    
    H --> L["Daftar Hasil Terfilter Secara Otomatis"]
    I --> L
    J --> L
    K --> L
```

#### Langkah Operasional:
1. **Membuka Riwayat**: Tekan ikon **Jam** di *AppBar* kanan atas atau buka menu garis tiga (**Drawer**) di kiri atas dan pilih **Riwayat Scan**.
2. **Mencari Data**: Ketik kata kunci pada **Search Bar** di bagian atas; daftar scan akan menyaring secara otomatis tanpa perlu menekan tombol cari.
3. **Filter Favorit**: Tekan ikon **Bintang** di *AppBar* atas untuk menampilkan hanya scan yang telah difavoritkan.
4. **Filter Folder**: Ketuk salah satu chip folder di bawah search bar untuk menyaring scan berdasarkan kategori.
5. **Membuat Folder**: Tekan tombol **Folder (+)** di *AppBar* kanan atas, masukkan nama folder (misal: *Tagihan*, *Wi-Fi Kantor*), lalu klik **Simpan**.

---

### C. Mengelola Item Scan (Salin, Favorit, Folder, Tag & Hapus)

Setiap item scan dapat dikelola langsung dari baris riwayat atau melalui jendela dialog detail lengkap:

```mermaid
flowchart TD
    A["Daftar Item Riwayat Scan"] --> B{"Pilihan Interaksi Pengguna"}
    
    B -- "Salin Cepat" --> C["Tekan Ikon Salin (Copy) di Baris Item"]
    C --> C1["Teks Disalin ke Clipboard"]
    C1 --> C2["Tercatat Otomatis di Log SCAN_ACTIONS"]
    C2 --> C3["Muncul Notifikasi SnackBar Konfirmasi"]

    B -- "Toggle Bintang" --> D["Tekan Ikon Bintang di Baris Item"]
    D --> D1["Status Favorit Berubah (isFavorite: true / false)"]

    B -- "Hapus Cepat" --> E["Geser Baris ke Kiri (Swipe Left)"]
    E --> E1["Latar Berubah Merah (Tempat Sampah)"]
    E1 --> E2["Soft Delete (isDeleted = true)<br/>Data Disembunyikan & Aman untuk Sinkronisasi"]

    B -- "Buka Detail Lengkap" --> F["Ketuk Baris Item Scan"]
    F --> G["Muncul Dialog 'Detail Scan'"]
    G --> H{"Aksi di Dialog Detail"}
    
    H -- "Pindah Folder" --> H1["Pilih Nama Folder pada Dropdown"]
    H -- "Pasang / Lepas Tag" --> H2["Ketuk Chip Tag yang Tersedia"]
    H -- "Tambah Tag Baru" --> H3["Klik '+ Tag Baru' -> Ketik Nama -> Klik 'Tambah'"]
    H -- "Salin Teks" --> H4["Klik Tombol 'Salin' di Bawah Dialog"]
    H -- "Tutup" --> H5["Klik Tombol 'Tutup'"]
```

#### Ringkasan Aksi Pengguna:

| Aksi | Cara Melakukan | Efek pada Sistem |
| :--- | :--- | :--- |
| **Salin (Copy)** | Tekan ikon **Copy** di baris scan atau tombol **Salin** pada dialog detail. | Teks tersalin ke *clipboard* dan aksi tercatat di tabel `SCAN_ACTIONS`. |
| **Tandai Favorit** | Tekan ikon **Bintang** di baris scan. | Kolom `is_favorite` diperbarui secara instan. |
| **Atur Folder** | Buka dialog detail scan, pilih folder di dropdown **Folder**. | Kolom `folder_id` diperbarui di tabel `SCAN_HISTORY`. |
| **Kelola Tag** | Buka dialog detail scan, pilih chip tag yang ada atau klik **`+ Tag Baru`**. | Data relasi tersimpan pada tabel *many-to-many* `SCAN_TAGS`. |
| **Hapus (Delete)** | Geser (*swipe*) baris scan ke arah kiri. | Diberi status *soft delete* (`is_deleted = true`) sehingga tidak hilang permanen saat sinkronisasi cloud. |

---

## 3. Panduan Developer & Cara Menjalankan Aplikasi

Diagram alur berikut menjelaskan urutan persiapan proyek dari *source code* hingga aplikasi siap diuji pada emulator atau perangkat fisik:

```mermaid
flowchart TD
    Start(["Mulai Setup Developer"]) --> Clone["1. Clone Repositori Git:<br/><code>git clone https://github.com/bagussatoto/QR-Scanner.git</code>"]
    Clone --> PubGet["2. Unduh Paket Dependensi:<br/><code>flutter pub get</code>"]
    PubGet --> BuildRunner["3. Generate Kode ORM Drift:<br/><code>dart run build_runner build --delete-conflicting-outputs</code>"]
    BuildRunner --> CheckGen{"File database.g.dart Terbentuk?"}
    
    CheckGen -- "Gagal" --> FixErr["Periksa Dependensi di pubspec.yaml"]
    FixErr --> BuildRunner
    
    CheckGen -- "Berhasil" --> RunTest["4. Jalankan Unit Test (Opsional):<br/><code>flutter test test/database_test.dart</code>"]
    RunTest --> LaunchApp["5. Jalankan Aplikasi:<br/><code>flutter run</code>"]
    LaunchApp --> Target{"Pilih Target Perangkat"}
    
    Target --> Android["Perangkat / Emulator Android"]
    Target --> iOS["Perangkat / Simulator iOS (macOS)"]
    
    Android --> Ready(["Aplikasi Berjalan Siap Digunakan"])
    iOS --> Ready
```

#### Perintah Terminal Ringkas:

```bash
# 1. Unduh paket pustaka
flutter pub get

# 2. Bangkitkan kode otomatis Drift ORM
dart run build_runner build --delete-conflicting-outputs

# 3. Jalankan pengujian unit
flutter test test/database_test.dart

# 4. Jalankan aplikasi pada perangkat yang terhubung
flutter run
```

---

## 4. Flowchart Implementasi Teknis Kode

Berikut adalah bagan alur (*flowchart*) implementasi teknis yang menghubungkan setiap komponen file, fungsi, dan alur data di dalam arsitektur aplikasi:

### A. Flowchart Komponen & Aliran Data Antar-Lapisan

```mermaid
flowchart TD
    subgraph UI_LAYER["1. Presentation Layer (UI)"]
        UI_Home["HomePage (lib/main.dart)<br/>• Menampilkan tombol FAB Scan<br/>• Menampilkan teks hasil scan<br/>• Drawer navigasi ke riwayat"]
        UI_Scan["HomePageState._scanQR()<br/>• Panggil BarcodeScanner.scan()<br/>• Tangani FormatException & PlatformException"]
        UI_Detect["HomePageState._detectContentType(qrResult)<br/>• Deteksi tipe: url | wifi | vcard | geo | text"]
        UI_History["ScanHistoryPage (lib/pages/scan_history_page.dart)<br/>• Search Bar & FilterChip Folder<br/>• StreamBuilder pembaruan real-time<br/>• Dialog Detail Scan & Salin Clipboard"]
    end

    subgraph SERVICE_LAYER["2. Service Layer (Logika Bisnis)"]
        SVC_Scan["ScanService (lib/services/scan_service.dart)<br/>• insertScan(): Insert data scan baru<br/>• watchFilteredScans(): Query reaktif real-time<br/>• toggleFavorite() & deleteScan() (Soft delete)<br/>• logAction(): Catat log aksi ke SCAN_ACTIONS"]
        SVC_FolderTag["FolderTagService (lib/services/folder_tag_service.dart)<br/>• createFolder() & deleteFolder()<br/>• createTag() & assignTagToScan() / removeTagFromScan()"]
    end

    subgraph DB_LAYER["3. Data Persistence Layer (Drift ORM)"]
        DB_Singleton["AppDatabase.instance (lib/database/database.dart)<br/>• Drift ORM Singleton<br/>• MigrationStrategy: PRAGMA foreign_keys = ON"]
        DB_Tables["Tabel Skema Drift (lib/database/tables.dart)<br/>• USERS & DEVICES (UUID v4)<br/>• SCAN_HISTORY (Data hasil scan)<br/>• FOLDERS & TAGS & SCAN_TAGS (M:N)<br/>• SCAN_ACTIONS & SYNC_QUEUE"]
    end

    subgraph SECURITY_LAYER["4. Security & Storage Engine (SQLCipher)"]
        SEC_Storage["FlutterSecureStorage<br/>• Simpan kunci 256-bit di Keystore / Keychain"]
        SEC_Cipher["SQLCipher Native Database (qr_scanner.sqlite)<br/>• PRAGMA key = \"x'<hexKey>'\"<br/>• Enkripsi AES-256 At-Rest pada disk perangkat"]
    end

    %% Alur Pemindaian & Penyimpanan
    UI_Home -->|"1. Tekan Scan"| UI_Scan
    UI_Scan -->|"2. String Hasil Scan"| UI_Detect
    UI_Detect -->|"3. Data & Tipe Konten"| SVC_Scan
    SVC_Scan -->|"4. insertScan()"| DB_Singleton

    %% Alur Riwayat & Interaksi
    UI_Home -->|"Navigasi Drawer"| UI_History
    UI_History -->|"Berlangganan Stream Query"| SVC_Scan
    UI_History -->|"Kelola Folder & Tag"| SVC_FolderTag
    SVC_FolderTag -->|"Mutasi Folder / Tag"| DB_Singleton

    %% Hubungan DB ke Security
    DB_Singleton -->|"Definisi Tabel & Relasi"| DB_Tables
    DB_Singleton -->|"Ambil Kunci Enkripsi"| SEC_Storage
    DB_Singleton -->|"Baca / Tulis Terenkripsi"| SEC_Cipher
```

---

### B. Flowchart Eksekusi Fungsi Kode Nyata

```mermaid
flowchart LR
    A["_scanQR()<br/>(lib/main.dart)"] -->|"String Mentah"| B["_detectContentType()<br/>(lib/main.dart)"]
    B -->|"Tipe: url/wifi/text"| C["ScanService.insertScan()<br/>(lib/services/scan_service.dart)"]
    C -->|"Generate UUID v4"| D["into(scanHistory).insertReturning()<br/>(lib/database/database.dart)"]
    D -->|"Ambil Kunci 256-bit"| E["_getOrCreateDbKey()<br/>(Keystore/Keychain)"]
    E -->|"AES-256 Terenkripsi"| F[("SQLCipher Native<br/>(qr_scanner.sqlite)")]
    F -->|"Stream Event Otomatis"| G["StreamBuilder Reaktif<br/>(ScanHistoryPage)"]
```

---

### C. Pemetaan Komponen Flowchart ke Kode Sumber

| Komponen Flowchart | File Sumber | Method / Class Konkrit | Fungsi dalam Sistem |
| :--- | :--- | :--- | :--- |
| **Scanner Kamera** | `lib/main.dart` | `HomePageState._scanQR()` | Menjalankan plugin kamera, membaca QR/barcode, dan menangani error. |
| **Parser Tipe Konten** | `lib/main.dart` | `HomePageState._detectContentType()` | Mengidentifikasi format isi seperti URL web, Wi-Fi, vCard, atau lokasi geografis. |
| **Logika Bisnis Scan** | `lib/services/scan_service.dart` | `ScanService.insertScan()` | Menghasilkan UUID v4, memastikan profil pengguna/perangkat ada, dan menyimpan scan. |
| **Query Reaktif Riwayat** | `lib/services/scan_service.dart` | `ScanService.watchFilteredScans()` | Menggabungkan filter kata kunci (`LIKE`), favorit, dan folder secara *real-time*. |
| **Pengelolaan Folder & Tag** | `lib/services/folder_tag_service.dart` | `FolderTagService` | Menangani operasi CRUD folder dan relasi *many-to-many* pada `scan_tags`. |
| **Kunci Kriptografi** | `lib/database/database.dart` | `_getOrCreateDbKey()` | Membuat kunci acak 256-bit dan menyimpannya di Android Keystore / iOS Keychain. |
| **Mesin Enkripsi DB** | `lib/database/database.dart` | `_openConnection()` | Membuka database dengan SQLCipher AES-256 (`PRAGMA key`). |

