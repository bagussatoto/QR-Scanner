// test/database_test.dart
// -------------------------------------------------------------------
// Unit tests for Drift tables (Users, Devices, ScanHistory, Tags,
// ScanTags, ScanActions) and ScanService using an in-memory SQLite DB.
// -------------------------------------------------------------------
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterqrscan/database/database.dart';
import 'package:flutterqrscan/services/scan_service.dart';

void main() {
  late AppDatabase db;
  late ScanService scanService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    scanService = ScanService.forTesting(db);
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

  group('ScanService CRUD Operations', () {
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

      // Should no longer appear in active scan list
      final activeScans = await scanService.fetchAllScans();
      expect(activeScans, isEmpty);

      // Row must still exist in the raw table with isDeleted = true
      final rawRows = await db.select(db.scanHistory).get();
      expect(rawRows, hasLength(1));
      expect(rawRows.single.isDeleted, isTrue);
    });
  });

  group('Relational Integrity & Cascade Rules', () {
    test('composite PK on ScanTags prevents duplicate tag assignments',
        () async {
      await scanService.insertScan(
        rawValue: 'https://example.com',
        barcodeFormat: 'QR_CODE',
      );
      final scan = (await scanService.fetchAllScans()).single;

      final tag = await db.into(db.tags).insertReturning(
            TagsCompanion.insert(
              userId: scan.userId,
              name: 'Work',
            ),
          );

      await db.into(db.scanTags).insert(
            ScanTagsCompanion.insert(scanId: scan.id, tagId: tag.id),
          );

      // Inserting the exact same (scanId, tagId) pair must throw a constraint error
      expect(
        () => db.into(db.scanTags).insert(
              ScanTagsCompanion.insert(scanId: scan.id, tagId: tag.id),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('deleting a ScanHistory row cascades to ScanTags and ScanActions',
        () async {
      await scanService.insertScan(
        rawValue: 'https://github.com/bagussatoto/QR-Scanner',
        barcodeFormat: 'QR_CODE',
        contentType: 'url',
      );
      final scan = (await scanService.fetchAllScans()).single;

      final tag = await db.into(db.tags).insertReturning(
            TagsCompanion.insert(
              userId: scan.userId,
              name: 'GitHub',
            ),
          );

      await db.into(db.scanTags).insert(
            ScanTagsCompanion.insert(scanId: scan.id, tagId: tag.id),
          );
      await db.into(db.scanActions).insert(
            ScanActionsCompanion.insert(
              scanId: scan.id,
              actionType: 'open_url',
            ),
          );

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
