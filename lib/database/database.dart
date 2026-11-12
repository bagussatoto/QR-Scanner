// lib/database/database.dart
// -------------------------------------------------------------------
// Drift database singleton for the QR‑Scanner app.
// -------------------------------------------------------------------
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Users,
  Devices,
  Folders,
  Tags,
  ScanHistory,
  QRGenerated,
  ScanActions,
  ScanTags,
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  // Private constructor – use the `instance` getter.
  AppDatabase._internal() : super(_openConnection());

  static final AppDatabase _instance = AppDatabase._internal();
  static AppDatabase get instance => _instance;

  @override
  int get schemaVersion => 1;

  // ---------------------------------------------------------------
  // Simple helper methods (add more as needed).
  // ---------------------------------------------------------------
  Future<List<ScanHistoryData>> getAllScans() =>
      (select(scanHistory)..where((t) => t.isDeleted.equals(false)))
          .orderBy([(t) => OrderingTerm(expression: t.scannedAt, mode: OrderingMode.desc)])
          .get();

  Stream<List<ScanHistoryData>> watchScans() =>
      (select(scanHistory)..where((t) => t.isDeleted.equals(false)))
          .orderBy([(t) => OrderingTerm(expression: t.scannedAt, mode: OrderingMode.desc)])
          .watch();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'qr_scanner.sqlite'));
    return NativeDatabase(file);
  });
}

// -------------------------------------------------------------------
// END – database singleton.
// -------------------------------------------------------------------

