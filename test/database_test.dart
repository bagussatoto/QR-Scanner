// test/database_test.dart
// -------------------------------------------------------------------
// Unit tests for Drift tables (Users, Devices, Folders, Tags,
// ScanHistory, ScanTags, ScanActions) and services (ScanService,
// FolderTagService) using an in-memory SQLite DB.
// -------------------------------------------------------------------
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterqrscan/database/database.dart';
import 'package:flutterqrscan/services/folder_tag_service.dart';
import 'package:flutterqrscan/services/scan_service.dart';

void main() {
  late AppDatabase db;
  late ScanService scanService;
  late FolderTagService folderTagService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scanService = ScanService.forTesting(db);
    folderTagService = FolderTagService.forTesting(db, scanService);
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
      await scanService.insertScan(
        rawValue: 'WIFI:S:HomeWifi;T:WPA;P:12345678;;',
        barcodeFormat: 'QR_CODE',
        title: 'Home Network',
      );

      await scanService.toggleFavorite(s1);

      final byKeyword = await scanService.searchScans(query: 'Home');
      expect(byKeyword, hasLength(1));
      expect(byKeyword.single.title, equals('Home Network'));

      final byFavorite = await scanService.searchScans(favoritesOnly: true);
      expect(byFavorite, hasLength(1));
      expect(byFavorite.single.id, equals(s1.id));

      final byFolder =
          await scanService.searchScans(folderId: workFolder.id);
      expect(byFolder, hasLength(1));
      expect(byFolder.single.id, equals(s1.id));
    });

    test('logAction records user interactions in ScanActions table', () async {
      final scan = await scanService.insertScan(
        rawValue: 'https://pub.dev',
        barcodeFormat: 'QR_CODE',
        contentType: 'url',
      );

      await scanService.logAction(scanId: scan.id, actionType: 'copy');
      await scanService.logAction(scanId: scan.id, actionType: 'open_url');

      final actions = await scanService.getActionsForScan(scan.id);
      expect(actions, hasLength(2));
      expect(
        actions.map((a) => a.actionType).toSet(),
        containsAll(['copy', 'open_url']),
      );
    });
  });

  group('FolderTagService & Relational Integrity', () {
    test('assigns and removes tags on a scan (many-to-many)', () async {
      final scan = await scanService.insertScan(
        rawValue: 'https://example.com',
        barcodeFormat: 'QR_CODE',
      );

      final tagUrgent = await folderTagService.createTag(name: 'Urgent');
      final tagWork = await folderTagService.createTag(name: 'Work');

      await folderTagService.assignTagToScan(
        scanId: scan.id,
        tagId: tagUrgent.id,
      );
      await folderTagService.assignTagToScan(
        scanId: scan.id,
        tagId: tagWork.id,
      );
      // Duplicate assignment is safely ignored by insertOrIgnore
      await folderTagService.assignTagToScan(
        scanId: scan.id,
        tagId: tagUrgent.id,
      );

      final attached = await folderTagService.getTagsForScan(scan.id);
      expect(attached.map((t) => t.name).toList(), equals(['Urgent', 'Work']));

      await folderTagService.removeTagFromScan(
        scanId: scan.id,
        tagId: tagUrgent.id,
      );
      final afterRemoval = await folderTagService.getTagsForScan(scan.id);
      expect(afterRemoval.map((t) => t.name).toList(), equals(['Work']));
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
}
