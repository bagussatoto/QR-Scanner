// test/database_test.dart
// -------------------------------------------------------------------
// Unit tests for Drift tables (Users, Devices, Folders, Tags,
// ScanHistory, ScanTags, ScanActions, QRGenerated) and services
// (ScanService, FolderTagService, QRGeneratorService) using an in-memory SQLite DB.
// -------------------------------------------------------------------
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterqrscan/database/database.dart';
import 'package:flutterqrscan/services/folder_tag_service.dart';
import 'package:flutterqrscan/services/qr_generator_service.dart';
import 'package:flutterqrscan/services/scan_service.dart';

void main() {
  late AppDatabase db;
  late ScanService scanService;
  late FolderTagService folderTagService;
  late QRGeneratorService qrService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scanService = ScanService.forTesting(db);
    folderTagService = FolderTagService.forTesting(db, scanService);
    qrService = QRGeneratorService.forTesting(db, scanService);
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift Schema & Default Values', () {
    test('generates UUID v4 primary keys and sets default column values',
        () async {
      await scanService.insertScan(
        rawValue: 'https://flutter.dev',
        barcodeFormat: 'QR_CODE',
        contentType: 'url',
        title: 'Flutter Website',
      );

      final scans = await db.getAllScans();
      expect(scans, hasLength(1));

      final scan = scans.first;
      expect(scan.id, isNotEmpty);
      expect(scan.id.length, equals(36)); // UUID v4 format
      expect(scan.rawValue, equals('https://flutter.dev'));
      expect(scan.barcodeFormat, equals('QR_CODE'));
      expect(scan.contentType, equals('url'));
      expect(scan.title, equals('Flutter Website'));
      expect(scan.isFavorite, isFalse);
      expect(scan.isDeleted, isFalse);
      expect(scan.syncStatus, equals('pending'));
    });
  });

  group('ScanService CRUD, Search & Action Logging', () {
    test('toggleFavorite flips isFavorite state', () async {
      await scanService.insertScan(
        rawValue: 'WIFI:S:MyNetwork;T:WPA;P:secret;;',
        barcodeFormat: 'QR_CODE',
        contentType: 'wifi',
      );

      final initial = (await scanService.fetchAllScans()).single;
      expect(initial.isFavorite, isFalse);

      await scanService.toggleFavorite(initial);
      final afterFirstToggle = (await scanService.fetchAllScans()).single;
      expect(afterFirstToggle.isFavorite, isTrue);

      await scanService.toggleFavorite(afterFirstToggle);
      final afterSecondToggle = (await scanService.fetchAllScans()).single;
      expect(afterSecondToggle.isFavorite, isFalse);
    });

    test(
        'deleteScan performs soft delete (hides from active queries but retains row for sync)',
        () async {
      await scanService.insertScan(
        rawValue: '9780201379624',
        barcodeFormat: 'EAN_13',
        contentType: 'product',
      );

      final created = (await scanService.fetchAllScans()).single;
      await scanService.deleteScan(created.id);

      final activeScans = await scanService.fetchAllScans();
      expect(activeScans, isEmpty);

      final rawRows = await db.select(db.scanHistory).get();
      expect(rawRows, hasLength(1));
      expect(rawRows.single.isDeleted, isTrue);
    });

    test('searchScans filters by keyword, favoritesOnly, and folderId',
        () async {
      final workFolder = await folderTagService.createFolder(name: 'Work');

      final s1 = await scanService.insertScan(
        rawValue: 'https://dart.dev',
        barcodeFormat: 'QR_CODE',
        title: 'Dart Docs',
        folderId: workFolder.id,
      );
      await scanService.toggleFavorite(s1);

      await scanService.insertScan(
        rawValue: 'https://flutter.dev',
        barcodeFormat: 'QR_CODE',
        title: 'Flutter Home',
      );

      // Search by keyword
      final queryDart = await scanService.searchScans(query: 'dart');
      expect(queryDart, hasLength(1));
      expect(queryDart.single.title, equals('Dart Docs'));

      // Filter by favorites only
      final queryFavs = await scanService.searchScans(favoritesOnly: true);
      expect(queryFavs, hasLength(1));
      expect(queryFavs.single.title, equals('Dart Docs'));

      // Filter by folder
      final queryFolder =
          await scanService.searchScans(folderId: workFolder.id);
      expect(queryFolder, hasLength(1));
      expect(queryFolder.single.title, equals('Dart Docs'));
    });

    test('assignFolder updates the folder reference', () async {
      final personal = await folderTagService.createFolder(name: 'Personal');
      final scan = await scanService.insertScan(
        rawValue: 'user@example.com',
        barcodeFormat: 'QR_CODE',
      );
      expect(scan.folderId, isNull);

      await scanService.assignFolder(scan.id, personal.id);
      final updated = (await scanService.fetchAllScans()).single;
      expect(updated.folderId, equals(personal.id));

      await scanService.assignFolder(scan.id, null);
      final cleared = (await scanService.fetchAllScans()).single;
      expect(cleared.folderId, isNull);
    });

    test('logAction records user interactions with scans', () async {
      final scan = await scanService.insertScan(
        rawValue: 'https://github.com',
        barcodeFormat: 'QR_CODE',
      );

      await scanService.logAction(scanId: scan.id, actionType: 'copy');
      await scanService.logAction(scanId: scan.id, actionType: 'open_url');

      final actions = await scanService.getActionsForScan(scan.id);
      expect(actions, hasLength(2));
      final types = actions.map((a) => a.actionType).toList();
      expect(types, containsAll(['copy', 'open_url']));
    });
  });

  group('FolderTagService & Relational Cascades', () {
    test('createFolder and getAllFolders only returns non-deleted folders',
        () async {
      final f1 = await folderTagService.createFolder(
        name: 'Work',
        colorHex: '#0055FF',
        iconName: 'work',
      );
      expect(f1.name, equals('Work'));
      expect(f1.colorHex, equals('#0055FF'));

      final list = await folderTagService.getAllFolders();
      expect(list, hasLength(1));
    });

    test('createTag, assignTagToScan, and getTagsForScan', () async {
      final scan = await scanService.insertScan(
        rawValue: 'https://pub.dev',
        barcodeFormat: 'QR_CODE',
      );
      final tag1 = await folderTagService.createTag(
        name: 'flutter',
        colorHex: '#02569B',
      );
      final tag2 = await folderTagService.createTag(name: 'dart');

      await folderTagService.assignTagToScan(scanId: scan.id, tagId: tag1.id);
      await folderTagService.assignTagToScan(scanId: scan.id, tagId: tag2.id);

      final scanTags = await folderTagService.getTagsForScan(scan.id);
      expect(scanTags, hasLength(2));
      final names = scanTags.map((t) => t.name).toList();
      expect(names, containsAll(['flutter', 'dart']));

      await folderTagService.removeTagFromScan(scanId: scan.id, tagId: tag1.id);
      final remaining = await folderTagService.getTagsForScan(scan.id);
      expect(remaining, hasLength(1));
      expect(remaining.single.name, equals('dart'));
    });

    test('deleteFolder soft-deletes the folder and detaches its scans',
        () async {
      final folder = await folderTagService.createFolder(name: 'Receipts');
      final scan = await scanService.insertScan(
        rawValue: 'INV-2026-001',
        barcodeFormat: 'CODE_128',
        folderId: folder.id,
      );
      expect(scan.folderId, equals(folder.id));

      await folderTagService.deleteFolder(folder.id);

      final activeFolders = await folderTagService.getAllFolders();
      expect(activeFolders, isEmpty);

      final updatedScan = (await scanService.fetchAllScans()).single;
      expect(updatedScan.folderId, isNull);
    });

    test('deleting a ScanHistory row cascades to ScanTags and ScanActions',
        () async {
      final scan = await scanService.insertScan(
        rawValue: 'https://github.com/bagussatoto/QR-Scanner',
        barcodeFormat: 'QR_CODE',
        contentType: 'url',
      );

      final tag = await folderTagService.createTag(name: 'GitHub');
      await folderTagService.assignTagToScan(scanId: scan.id, tagId: tag.id);
      await scanService.logAction(scanId: scan.id, actionType: 'open_url');

      // Hard-delete the parent scan
      await (db.delete(db.scanHistory)..where((t) => t.id.equals(scan.id)))
          .go();

      final remainingScanTags = await db.select(db.scanTags).get();
      final remainingActions = await db.select(db.scanActions).get();
      expect(remainingScanTags, isEmpty);
      expect(remainingActions, isEmpty);
    });
  });

  group('QRGeneratorService CRUD & Customization', () {
    test('insertGeneratedQR generates valid record with default and custom values',
        () async {
      final qr = await qrService.insertGeneratedQR(
        payload: 'https://flutter.dev',
        contentType: 'url',
        fgColorHex: '#FF5722',
        bgColorHex: '#FFFFFF',
        errorCorrection: 'H',
      );

      expect(qr.id, isNotEmpty);
      expect(qr.id.length, equals(36)); // UUID v4 format
      expect(qr.payload, equals('https://flutter.dev'));
      expect(qr.contentType, equals('url'));
      expect(qr.fgColorHex, equals('#FF5722'));
      expect(qr.bgColorHex, equals('#FFFFFF'));
      expect(qr.errorCorrection, equals('H'));
      expect(qr.isDeleted, isFalse);
    });

    test('fetchAllGeneratedQRs returns non-deleted records newest first',
        () async {
      await qrService.insertGeneratedQR(payload: 'First QR');
      await qrService.insertGeneratedQR(payload: 'Second QR');

      final list = await qrService.fetchAllGeneratedQRs();
      expect(list, hasLength(2));
      expect(list.first.payload, equals('Second QR'));
      expect(list.last.payload, equals('First QR'));
    });

    test('deleteGeneratedQR performs soft delete', () async {
      final qr = await qrService.insertGeneratedQR(payload: 'Temporary QR');
      await qrService.deleteGeneratedQR(qr.id);

      final activeList = await qrService.fetchAllGeneratedQRs();
      expect(activeList, isEmpty);

      final rawRows = await db.select(db.qRGenerated).get();
      expect(rawRows, hasLength(1));
      expect(rawRows.single.isDeleted, isTrue);
    });
  });
}
