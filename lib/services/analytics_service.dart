// lib/services/analytics_service.dart
// -------------------------------------------------------------------
// Service providing aggregated statistics, distribution breakdown,
// and usage analytics from the local Drift database.
// -------------------------------------------------------------------
import 'package:flutterqrscan/database/database.dart';
import 'package:flutterqrscan/services/folder_tag_service.dart';
import 'package:flutterqrscan/services/qr_generator_service.dart';
import 'package:flutterqrscan/services/scan_service.dart';

class ScanAnalyticsReport {
  final int totalScans;
  final int totalFavorites;
  final int totalGeneratedQRs;
  final int totalFolders;
  final int totalTags;
  final int scansToday;
  final int scansThisWeek;
  final Map<String, int> contentTypeCounts;
  final Map<String, int> formatCounts;

  const ScanAnalyticsReport({
    required this.totalScans,
    required this.totalFavorites,
    required this.totalGeneratedQRs,
    required this.totalFolders,
    required this.totalTags,
    required this.scansToday,
    required this.scansThisWeek,
    required this.contentTypeCounts,
    required this.formatCounts,
  });

  /// Formatted plain text export for sharing
  String toSummaryText() {
    final buffer = StringBuffer();
    buffer.writeln('📊 LAPORAN STATISTIK QR-SCANNER');
    buffer.writeln('================================');
    buffer.writeln('• Total Pemindaian: $totalScans item');
    buffer.writeln('• Pemindaian Hari Ini: $scansToday item');
    buffer.writeln('• Pemindaian 7 Hari Terakhir: $scansThisWeek item');
    buffer.writeln('• Kode QR Favorit: $totalFavorites item');
    buffer.writeln('• Total QR Dibuat: $totalGeneratedQRs item');
    buffer.writeln('• Folder Aktif: $totalFolders');
    buffer.writeln('• Tag Kustom: $totalTags');
    buffer.writeln('\nDistribusi Kategori Konten:');
    contentTypeCounts.forEach((type, count) {
      final pct = totalScans > 0
          ? ((count / totalScans) * 100).toStringAsFixed(1)
          : '0.0';
      buffer.writeln('  - ${type.toUpperCase()}: $count ($pct%)');
    });
    buffer.writeln('\nDistribusi Format Barcode:');
    formatCounts.forEach((format, count) {
      final pct = totalScans > 0
          ? ((count / totalScans) * 100).toStringAsFixed(1)
          : '0.0';
      buffer.writeln('  - $format: $count ($pct%)');
    });
    return buffer.toString();
  }
}

class AnalyticsService {
  AnalyticsService._([
    AppDatabase? db,
    ScanService? scanService,
    QRGeneratorService? qrService,
    FolderTagService? folderTagService,
  ])  : _db = db ?? AppDatabase.instance,
        _scanService = scanService ?? ScanService.instance,
        _qrService = qrService ?? QRGeneratorService.instance,
        _folderTagService = folderTagService ?? FolderTagService.instance;

  factory AnalyticsService.forTesting(
    AppDatabase db, {
    ScanService? scanService,
    QRGeneratorService? qrService,
    FolderTagService? folderTagService,
  }) {
    final sService = scanService ?? ScanService.forTesting(db);
    final qService = qrService ?? QRGeneratorService.forTesting(db, sService);
    final fService =
        folderTagService ?? FolderTagService.forTesting(db, sService);
    return AnalyticsService._(db, sService, qService, fService);
  }

  static final AnalyticsService instance = AnalyticsService._();

  final AppDatabase _db;
  final ScanService _scanService;
  final QRGeneratorService _qrService;
  final FolderTagService _folderTagService;

  /// Aggregates and returns a comprehensive [ScanAnalyticsReport].
  Future<ScanAnalyticsReport> getReport() async {
    final scans = await _scanService.fetchAllScans();
    final generatedQRs = await _qrService.fetchAllGeneratedQRs();
    final folders = await _folderTagService.getAllFolders();
    final tags = await (_db.select(_db.tags)).get();

    final now = DateTime.now();

    int totalFavorites = 0;
    int scansToday = 0;
    int scansThisWeek = 0;
    final Map<String, int> contentTypeCounts = {};
    final Map<String, int> formatCounts = {};

    for (final scan in scans) {
      if (scan.isFavorite) totalFavorites++;

      // Today check
      if (scan.scannedAt.year == now.year &&
          scan.scannedAt.month == now.month &&
          scan.scannedAt.day == now.day) {
        scansToday++;
      }

      // Past 7 days check
      if (now.difference(scan.scannedAt).inDays <= 7) {
        scansThisWeek++;
      }

      // Content type count
      final type = scan.contentType.toLowerCase();
      contentTypeCounts[type] = (contentTypeCounts[type] ?? 0) + 1;

      // Barcode format count
      final fmt = scan.barcodeFormat.toUpperCase();
      formatCounts[fmt] = (formatCounts[fmt] ?? 0) + 1;
    }

    return ScanAnalyticsReport(
      totalScans: scans.length,
      totalFavorites: totalFavorites,
      totalGeneratedQRs: generatedQRs.length,
      totalFolders: folders.length,
      totalTags: tags.length,
      scansToday: scansToday,
      scansThisWeek: scansThisWeek,
      contentTypeCounts: contentTypeCounts,
      formatCounts: formatCounts,
    );
  }
}
