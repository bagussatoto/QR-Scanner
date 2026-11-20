// lib/services/export_service.dart
// -------------------------------------------------------------------
// Service for exporting scan history & generated QRs to RFC 4180 CSV
// and structured JSON backup, plus idempotent importing/restoring from JSON.
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

  /// Exports a full structured JSON backup including folders, tags, scans,
  /// scan-tag links, and generated QRs.
  Future<String> exportToJson() async {
    final scans = await _scanService.fetchAllScans();
    final generatedQRs = await _qrService.fetchAllGeneratedQRs();
    final folders = await _folderTagService.getAllFolders();
    final tags = await _folderTagService.getAllTags();
    final activeScanIds = scans.map((s) => s.id).toSet();
    final scanTags = (await _db.select(_db.scanTags).get())
        .where((st) => activeScanIds.contains(st.scanId))
        .toList();

    final payload = {
      'app': 'QR-Scanner',
      'version': '1.2.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'counts': {
        'scans': scans.length,
        'generatedQRs': generatedQRs.length,
        'folders': folders.length,
        'tags': tags.length,
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
      'tags': tags
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'colorHex': t.colorHex,
                'createdAt': t.createdAt.toIso8601String(),
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
      'scanTags': scanTags
          .map((st) => {
                'scanId': st.scanId,
                'tagId': st.tagId,
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

  String _scanFallbackKey(
    String rawValue,
    String format,
    String? title,
    String? notes,
  ) {
    return '$rawValue|${format.toUpperCase()}|${title ?? ''}|${notes ?? ''}';
  }

  String _scanFullKey(
    String rawValue,
    String format,
    String? title,
    String? notes,
    int epochSec,
  ) {
    return '${_scanFallbackKey(rawValue, format, title, notes)}|$epochSec';
  }

  String _qrDedupeKey(
    String payload,
    String contentType,
    String fgColorHex,
    String bgColorHex,
    String errorCorrection,
  ) {
    return '$payload|$contentType|${fgColorHex.toUpperCase()}|${bgColorHex.toUpperCase()}|${errorCorrection.toUpperCase()}';
  }

  /// Restores folders, tags, scans (with folder/tag relationships), and
  /// generated QRs idempotently from a JSON backup string.
  /// Returns the count of newly inserted primary entities (folders, tags,
  /// scans, and generated QRs).
  Future<int> importFromJson(String jsonContent) async {
    final dynamic decoded = jsonDecode(jsonContent);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Format JSON backup tidak valid.');
    }

    int restoredCount = 0;

    // 1. Restore folders (case-insensitive deduplication by name)
    final existingFolders = await _folderTagService.getAllFolders();
    final folderByName = <String, String>{
      for (final f in existingFolders) f.name.trim().toLowerCase(): f.id,
    };
    final folderIdMap = <String, String>{};

    final foldersList = decoded['folders'];
    if (foldersList is List) {
      for (final item in foldersList) {
        if (item is Map<String, dynamic>) {
          final oldId = item['id']?.toString();
          final name = item['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;

          final key = name.toLowerCase();
          String localId;
          if (folderByName.containsKey(key)) {
            localId = folderByName[key]!;
          } else {
            final created = await _folderTagService.createFolder(
              name: name,
              colorHex: item['colorHex']?.toString() ?? '#FF5722',
              iconName: item['iconName']?.toString(),
            );
            localId = created.id;
            folderByName[key] = localId;
            restoredCount++;
          }
          if (oldId != null && oldId.isNotEmpty) {
            folderIdMap[oldId] = localId;
          }
        }
      }
    }

    // 2. Restore tags (case-insensitive deduplication by name)
    final existingTags = await _folderTagService.getAllTags();
    final tagByName = <String, String>{
      for (final t in existingTags) t.name.trim().toLowerCase(): t.id,
    };
    final tagIdMap = <String, String>{};

    final tagsList = decoded['tags'];
    if (tagsList is List) {
      for (final item in tagsList) {
        if (item is Map<String, dynamic>) {
          final oldId = item['id']?.toString();
          final name = item['name']?.toString().trim() ?? '';
          if (name.isEmpty) continue;

          final key = name.toLowerCase();
          String localId;
          if (tagByName.containsKey(key)) {
            localId = tagByName[key]!;
          } else {
            final created = await _folderTagService.createTag(
              name: name,
              colorHex: item['colorHex']?.toString() ?? '#FFCC00',
            );
            localId = created.id;
            tagByName[key] = localId;
            restoredCount++;
          }
          if (oldId != null && oldId.isNotEmpty) {
            tagIdMap[oldId] = localId;
          }
        }
      }
    }

    // 3. Restore scans (anti-duplication + folderId & scannedAt preservation)
    final existingScans = await _scanService.fetchAllScans();
    final existingScanByKey = <String, String>{};
    final existingScanByFallback = <String, String>{};
    for (final s in existingScans) {
      final epochSec = s.scannedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
      existingScanByKey[_scanFullKey(
        s.rawValue,
        s.barcodeFormat,
        s.title,
        s.notes,
        epochSec,
      )] = s.id;
      existingScanByFallback[_scanFallbackKey(
        s.rawValue,
        s.barcodeFormat,
        s.title,
        s.notes,
      )] = s.id;
    }
    final scanIdMap = <String, String>{};

    final scansList = decoded['scans'];
    if (scansList is List) {
      for (final item in scansList) {
        if (item is Map<String, dynamic>) {
          final rawValue = item['rawValue']?.toString() ?? '';
          if (rawValue.isEmpty) continue;

          final oldId = item['id']?.toString();
          final barcodeFormat =
              item['barcodeFormat']?.toString() ?? 'QR_CODE';
          final contentType = item['contentType']?.toString() ?? 'text';
          final title = item['title']?.toString();
          final notes = item['notes']?.toString();
          final isFavorite = item['isFavorite'] == true;
          final oldFolderId = item['folderId']?.toString();
          final scannedAtStr = item['scannedAt']?.toString();
          final parsedScannedAt =
              scannedAtStr != null ? DateTime.tryParse(scannedAtStr) : null;

          final fallbackKey =
              _scanFallbackKey(rawValue, barcodeFormat, title, notes);
          final fullKey = parsedScannedAt != null
              ? _scanFullKey(
                  rawValue,
                  barcodeFormat,
                  title,
                  notes,
                  parsedScannedAt.toUtc().millisecondsSinceEpoch ~/ 1000,
                )
              : null;

          final existingId = fullKey != null
              ? existingScanByKey[fullKey]
              : existingScanByFallback[fallbackKey];

          if (existingId != null) {
            if (oldId != null && oldId.isNotEmpty) {
              scanIdMap[oldId] = existingId;
            }
            continue;
          }

          final mappedFolderId =
              oldFolderId != null ? folderIdMap[oldFolderId] : null;

          final inserted = await _scanService.insertScan(
            rawValue: rawValue,
            barcodeFormat: barcodeFormat,
            contentType: contentType,
            title: title,
            notes: notes,
            folderId: mappedFolderId,
            scannedAt: parsedScannedAt,
          );
          if (isFavorite) {
            await _scanService.toggleFavorite(inserted);
          }

          final insertedEpochSec =
              inserted.scannedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
          existingScanByKey[_scanFullKey(
            inserted.rawValue,
            inserted.barcodeFormat,
            inserted.title,
            inserted.notes,
            insertedEpochSec,
          )] = inserted.id;
          if (fullKey != null) {
            existingScanByKey[fullKey] = inserted.id;
          }
          existingScanByFallback[fallbackKey] = inserted.id;

          if (oldId != null && oldId.isNotEmpty) {
            scanIdMap[oldId] = inserted.id;
          }
          restoredCount++;
        }
      }
    }

    // 4. Restore ScanTags links
    final scanTagsList = decoded['scanTags'];
    if (scanTagsList is List) {
      for (final item in scanTagsList) {
        if (item is Map<String, dynamic>) {
          final oldScanId = item['scanId']?.toString();
          final oldTagId = item['tagId']?.toString();
          if (oldScanId == null || oldTagId == null) continue;

          final mappedScanId = scanIdMap[oldScanId];
          final mappedTagId = tagIdMap[oldTagId];
          if (mappedScanId != null && mappedTagId != null) {
            await _folderTagService.assignTagToScan(
              scanId: mappedScanId,
              tagId: mappedTagId,
            );
          }
        }
      }
    }

    // 5. Restore generated QRs (anti-duplication)
    final existingQRs = await _qrService.fetchAllGeneratedQRs();
    final existingQrKeys = <String>{
      for (final q in existingQRs)
        _qrDedupeKey(
          q.payload,
          q.contentType,
          q.fgColorHex,
          q.bgColorHex,
          q.errorCorrection,
        ),
    };

    final qrList = decoded['generatedQRs'];
    if (qrList is List) {
      for (final item in qrList) {
        if (item is Map<String, dynamic>) {
          final payload = item['payload']?.toString() ?? '';
          if (payload.isEmpty) continue;

          final contentType = item['contentType']?.toString() ?? 'text';
          final fgColorHex = item['fgColorHex']?.toString() ?? '#000000';
          final bgColorHex = item['bgColorHex']?.toString() ?? '#FFFFFF';
          final errorCorrection =
              item['errorCorrection']?.toString() ?? 'M';

          final key = _qrDedupeKey(
            payload,
            contentType,
            fgColorHex,
            bgColorHex,
            errorCorrection,
          );
          if (existingQrKeys.contains(key)) {
            continue;
          }

          await _qrService.insertGeneratedQR(
            payload: payload,
            contentType: contentType,
            fgColorHex: fgColorHex,
            bgColorHex: bgColorHex,
            errorCorrection: errorCorrection,
          );
          existingQrKeys.add(key);
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
