// lib/services/scan_service.dart
// -------------------------------------------------------------------
// Service layer that encapsulates all database operations related to scans.
// This keeps UI code clean and makes it easy to unit‑test the data layer.
// -------------------------------------------------------------------
import 'package:drift/drift.dart';
import 'package:flutterqrscan/database/database.dart'; // adjust the import path to match your package name

class ScanService {
  // Singleton pattern – one instance shared across the app.
  ScanService._();
  static final ScanService instance = ScanService._();

  final AppDatabase _db = AppDatabase.instance;

  /// Insert a new scan entry.
  ///
  /// [rawValue]   – raw payload returned by the scanner.
  /// [barcodeFormat] – e.g. "QR_CODE", "EAN_13".
  /// Optional parameters allow callers to store parsed metadata.
  Future<void> insertScan({
    required String rawValue,
    required String barcodeFormat,
    String? title,
    String? notes,
    String contentType = 'text',
  }) async {
    // For a minimal implementation we assume a single local user/device exists.
    // In a real app you would fetch or create the user/device first.
    // Here we use a lazy‑loaded dummy user/device if none exist.
    final user = await _ensureUser();
    final device = await _ensureDevice(user.id);

    final entry = ScanHistoryCompanion(
      userId: Value(user.id),
      deviceId: Value(device.id),
      rawValue: Value(rawValue),
      barcodeFormat: Value(barcodeFormat),
      title: Value(title),
      notes: Value(notes),
      contentType: Value(contentType),
      scannedAt: Value(DateTime.now()),
    );
    await _db.into(_db.scanHistory).insert(entry);
  }

  /// Toggle the `isFavorite` flag for a given scan.
  Future<void> toggleFavorite(String scanId) async {
    final current = await (_db.select(_db.scanHistory)
          ..where((t) => t.id.equals(scanId)))
        .getSingle();
    final updated = current.copyWith(isFavorite: !current.isFavorite);
    await (_db.update(_db.scanHistory)..where((t) => t.id.equals(scanId)))
        .write(updated);
  }

  /// Soft‑delete a scan – marks `isDeleted = true`.
  Future<void> deleteScan(String scanId) async {
    await (_db.update(_db.scanHistory)..where((t) => t.id.equals(scanId)))
        .write(const ScanHistoryCompanion(isDeleted: Value(true)));
  }

  /// Retrieve all non‑deleted scans (ordered newest first).
  Future<List<ScanHistoryData>> fetchAllScans() =>
      (_db.select(_db.scanHistory)
            ..where((t) => t.isDeleted.equals(false)))
          .orderBy([
        (t) => OrderingTerm(expression: t.scannedAt, mode: OrderingMode.desc)
      ]).get();

  // -----------------------------------------------------------------
  // Helper methods to guarantee that a user & device row exist. In a
  // production app you would integrate this with your authentication flow.
  // -----------------------------------------------------------------
  Future<UserData> _ensureUser() async {
    final users = await _db.select(_db.users).get();
    if (users.isNotEmpty) return users.first;
    // Create a placeholder local user.
    final userCompanion = UsersCompanion(
      email: const Value(null),
      displayName: const Value('Local User'),
      authProvider: const Value('local'),
    );
    final id = await _db.into(_db.users).insert(userCompanion);
    return (await _db.select(_db.users).where((t) => t.id.equals(id)).getSingle());
  }

  Future<DeviceData> _ensureDevice(String userId) async {
    final devices = await (_db.select(_db.devices)
          ..where((t) => t.userId.equals(userId)))
        .get();
    if (devices.isNotEmpty) return devices.first;
    final deviceCompanion = DevicesCompanion(
      userId: Value(userId),
      platform: const Value('unknown'),
    );
    final id = await _db.into(_db.devices).insert(deviceCompanion);
    return (await _db.select(_db.devices).where((t) => t.id.equals(id)).getSingle());
  }
}

// -------------------------------------------------------------------
// END – ScanService.
// -------------------------------------------------------------------

