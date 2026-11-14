// lib/services/export_service.dart
// -------------------------------------------------------------------
// Service for exporting scan history & generated QRs to RFC 4180 CSV
// and structured JSON backup, plus importing/restoring from JSON.
// -------------------------------------------------------------------
import 'dart:convert';
import 'dart:io';

import 'package:flutterqrscan/database/database.dart';
import 'package:flutterqrscan/services/folder_tag_service.dart';
import 'package:flutterqrscan/services/qr_generator_service.dart';
import 'package:flutterqrscan/services/scan_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ExportService {
  ExportService._([
    AppDatabase? db,
    ScanService? scanService,
    QRGeneratorService? qrService,
    FolderTagService? folderTagService,
  ])  : _db = db ?? AppDatabase.instance,
        _scanService = scanService ?? ScanService.instance,
        _qrService = qrService ?? QRGeneratorService.instance,
        _folderTagService = folderTagService ?? FolderTagService.instance;

  /// Creates an [ExportService] backed by custom test instances.
  factory ExportService.forTesting(
    AppDatabase db, {
    ScanService? scanService,
    QRGeneratorService? qrService,
    FolderTagService? folderTagService,
  }) {
    final sService = scanService ?? ScanService.forTesting(db);
    final qService = qrService ?? QRGeneratorService.forTesting(db, sService);
    final fService =
        folderTagService ?? FolderTagService.forTesting(db, sService);
    return ExportService._(db, sService, qService, fService);
  }

  static final ExportService instance = ExportService._();

  // ignore: unused_field
  final AppDatabase _db;
  final ScanService _scanService;
  final QRGeneratorService _qrService;
  final FolderTagService _folderTagService;

  /// Escapes a single CSV field according to RFC 4180.
  String escapeCsvField(String? value) {
    if (value == null || value.isEmpty) return '';
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  /// Exports all active (non-deleted) scans to an RFC 4180 CSV string.
  Future<String> exportScansToCsv() async {
    final scans = await _scanService.fetchAllScans();
    final buffer = StringBuffer();

    // Header row
    buffer.writeln(
      'id,raw_value,content_type,barcode_format,title,notes,is_favorite,folder_id,scanned_at',
    );

    for (final s in scans) {
      final row = [
        escapeCsvField(s.id),
        escapeCsvField(s.rawValue),
        escapeCsvField(s.contentType),
        escapeCsvField(s.barcodeFormat),
        escapeCsvField(s.title),
        escapeCsvField(s.notes),
        s.isFavorite ? 'true' : 'false',
        escapeCsvField(s.folderId),
        escapeCsvField(s.scannedAt.toIso8601String()),
      ].join(',');
      buffer.writeln(row);
    }

    return buffer.toString();
  }

  /// Exports a full structured JSON backup including folders, scans, and generated QRs.
  Future<String> exportToJson() async {
    final scans = await _scanService.fetchAllScans();
    final generatedQRs = await _qrService.fetchAllGeneratedQRs();
    final folders = await _folderTagService.getAllFolders();

    final payload = {
      'app': 'QR-Scanner',
      'version': '1.2.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'counts': {
        'scans': scans.length,
        'generatedQRs': generatedQRs.length,
        'folders': folders.length,
      },
      'folders': folders
          .map((f) => {
                'id': f.id,
                'name': f.name,
                'colorHex': f.colorHex,
                'iconName': f.iconName,
                'createdAt': f.createdAt.toIso8601String(),
              })
          .toList(),
      'scans': scans
          .map((s) => {
                'id': s.id,
                'rawValue': s.rawValue,
                'contentType': s.contentType,
                'barcodeFormat': s.barcodeFormat,
                'title': s.title,
                'notes': s.notes,
                'isFavorite': s.isFavorite,
                'folderId': s.folderId,
                'scannedAt': s.scannedAt.toIso8601String(),
              })
          .toList(),
      'generatedQRs': generatedQRs
          .map((q) => {
                'id': q.id,
                'payload': q.payload,
                'contentType': q.contentType,
                'fgColorHex': q.fgColorHex,
                'bgColorHex': q.bgColorHex,
                'errorCorrection': q.errorCorrection,
                'createdAt': q.createdAt.toIso8601String(),
              })
          .toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Restores scans and generated QRs from a JSON backup string.
  /// Returns the total count of restored records.
  Future<int> importFromJson(String jsonContent) async {
    final dynamic decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format JSON backup tidak valid.');
    }

    int restoredCount = 0;

    // 1. Restore scans
    final scansList = decoded['scans'];
    if (scansList is List) {
      for (final item in scansList) {
        if (item is Map<String, dynamic>) {
          final rawValue = item['rawValue']?.toString() ?? '';
          if (rawValue.isEmpty) continue;

          final barcodeFormat =
              item['barcodeFormat']?.toString() ?? 'QR_CODE';
          final contentType = item['contentType']?.toString() ?? 'text';
          final title = item['title']?.toString();
          final notes = item['notes']?.toString();
          final isFavorite = item['isFavorite'] == true;

          final inserted = await _scanService.insertScan(
            rawValue: rawValue,
            barcodeFormat: barcodeFormat,
            contentType: contentType,
            title: title,
            notes: notes,
          );
          if (isFavorite) {
            await _scanService.toggleFavorite(inserted);
          }
          restoredCount++;
        }
      }
    }

    // 2. Restore generated QRs
    final qrList = decoded['generatedQRs'];
    if (qrList is List) {
      for (final item in qrList) {
        if (item is Map<String, dynamic>) {
          final payload = item['payload']?.toString() ?? '';
          if (payload.isEmpty) continue;

          await _qrService.insertGeneratedQR(
            payload: payload,
            contentType: item['contentType']?.toString() ?? 'text',
            fgColorHex: item['fgColorHex']?.toString() ?? '#000000',
            bgColorHex: item['bgColorHex']?.toString() ?? '#FFFFFF',
            errorCorrection: item['errorCorrection']?.toString() ?? 'M',
          );
          restoredCount++;
        }
      }
    }

    return restoredCount;
  }

  /// Saves an exported string (CSV or JSON) to the application documents directory.
  Future<File> saveExportToFile({
    required String filename,
    required String content,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, filename));
    return file.writeAsString(content, flush: true);
  }
}
