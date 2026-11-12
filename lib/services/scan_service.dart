// lib/services/scan_service.dart
// -------------------------------------------------------------------
// Service layer that encapsulates all database operations related to scans.
// -------------------------------------------------------------------
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutterqrscan/database/database.dart';

class ScanService {
  ScanService._();
  static final ScanService instance = ScanService._();

  final AppDatabase _db = AppDatabase.instance;

  /// Insert a new scan entry for the local user/device.
  Future<void> insertScan({
    required String rawValue,
    required String barcodeFormat,
    String? title,
    String? notes,
    String contentType = 'text',
  }) async {
    final user = await _ensureUser();
    final device = await _ensureDevice(user.id);

    await _db.into(_db.scanHistory).insert(ScanHistoryCompanion.insert(
          userId: user.id,
          deviceId: device.id,
          rawValue: rawValue,
          barcodeFormat: barcodeFormat,
          title: Value(title),
          notes: Value(notes),
          contentType: Value(contentType),
        ));
  }

  /// Toggle the `isFavorite` flag for a given scan.
  Future<void> toggleFavorite(ScanHistoryData scan) async {
    await (_db.update(_db.scanHistory)..where((t) => t.id.equals(scan.id)))
        .write(ScanHistoryCompanion(
      isFavorite: Value(!scan.isFavorite),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Soft-delete a scan (keeps the row so the deletion can be synced).
  Future<void> deleteScan(String scanId) async {
    await (_db.update(_db.scanHistory)..where((t) => t.id.equals(scanId)))
        .write(ScanHistoryCompanion(
      isDeleted: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<List<ScanHistoryData>> fetchAllScans() => _db.getAllScans();

  // -----------------------------------------------------------------
  // Ensure a local user & device exist (placeholder until auth exists).
  // -----------------------------------------------------------------
  Future<User> _ensureUser() async {
    final existing = await (_db.select(_db.users)..limit(1)).getSingleOrNull();
    if (existing != null) return existing;
    return _db.into(_db.users).insertReturning(
          UsersCompanion.insert(displayName: 'Local User'),
        );
  }

  Future<Device> _ensureDevice(String userId) async {
    final existing = await (_db.select(_db.devices)
          ..where((t) => t.userId.equals(userId))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing;
    return _db.into(_db.devices).insertReturning(
          DevicesCompanion.insert(
            userId: userId,
            platform: Platform.isIOS ? 'ios' : 'android',
          ),
        );
  }
}
