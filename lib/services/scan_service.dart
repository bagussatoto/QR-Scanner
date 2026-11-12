// lib/services/scan_service.dart
// -------------------------------------------------------------------
// Service layer that encapsulates database operations related to scans
// and post-scan user actions (ScanActions).
// -------------------------------------------------------------------
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutterqrscan/database/database.dart';

class ScanService {
  ScanService._([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  /// Creates a [ScanService] backed by a custom [AppDatabase] instance
  /// (used in unit tests with an in-memory database).
  factory ScanService.forTesting(AppDatabase db) => ScanService._(db);

  static final ScanService instance = ScanService._();

  final AppDatabase _db;

  /// Insert a new scan entry for the local user/device.
  Future<ScanHistoryData> insertScan({
    required String rawValue,
    required String barcodeFormat,
    String? title,
    String? notes,
    String? folderId,
    String contentType = 'text',
  }) async {
    final user = await ensureLocalUser();
    final device = await _ensureDevice(user.id);

    return _db.into(_db.scanHistory).insertReturning(
          ScanHistoryCompanion.insert(
            userId: user.id,
            deviceId: device.id,
            folderId: Value(folderId),
            rawValue: rawValue,
            barcodeFormat: barcodeFormat,
            title: Value(title),
            notes: Value(notes),
            contentType: Value(contentType),
          ),
        );
  }

  /// Toggle the `isFavorite` flag for a given scan.
  Future<void> toggleFavorite(ScanHistoryData scan) async {
    await (_db.update(_db.scanHistory)..where((t) => t.id.equals(scan.id)))
        .write(ScanHistoryCompanion(
      isFavorite: Value(!scan.isFavorite),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Move a scan into a folder (or pass `null` to remove from folder).
  Future<void> assignFolder(String scanId, String? folderId) async {
    await (_db.update(_db.scanHistory)..where((t) => t.id.equals(scanId)))
        .write(ScanHistoryCompanion(
      folderId: Value(folderId),
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

  /// Fetch all non-deleted scans ordered newest first.
  Future<List<ScanHistoryData>> fetchAllScans() => _db.getAllScans();

  /// Search and filter non-deleted scans (one-shot query).
  Future<List<ScanHistoryData>> searchScans({
    String query = '',
    bool favoritesOnly = false,
    String? folderId,
  }) {
    return _buildFilteredQuery(
      query: query,
      favoritesOnly: favoritesOnly,
      folderId: folderId,
    ).get();
  }

  /// Live stream of searched and filtered non-deleted scans.
  Stream<List<ScanHistoryData>> watchFilteredScans({
    String query = '',
    bool favoritesOnly = false,
    String? folderId,
  }) {
    return _buildFilteredQuery(
      query: query,
      favoritesOnly: favoritesOnly,
      folderId: folderId,
    ).watch();
  }

  SimpleSelectStatement<$ScanHistoryTable, ScanHistoryData> _buildFilteredQuery({
    required String query,
    required bool favoritesOnly,
    required String? folderId,
  }) {
    final trimmed = query.trim();
    final selectStmt = _db.select(_db.scanHistory)
      ..where((t) {
        Expression<bool> predicate = t.isDeleted.equals(false);
        if (favoritesOnly) {
          predicate = predicate & t.isFavorite.equals(true);
        }
        if (folderId != null) {
          predicate = predicate & t.folderId.equals(folderId);
        }
        if (trimmed.isNotEmpty) {
          final pattern = '%$trimmed%';
          predicate = predicate &
              (t.rawValue.like(pattern) |
                  t.title.like(pattern) |
                  t.notes.like(pattern));
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.scannedAt)]);
    return selectStmt;
  }

  /// Record a post-scan user interaction (e.g. `copy`, `open_url`, `share`).
  Future<ScanAction> logAction({
    required String scanId,
    required String actionType,
  }) {
    return _db.into(_db.scanActions).insertReturning(
          ScanActionsCompanion.insert(
            scanId: scanId,
            actionType: actionType,
          ),
        );
  }

  /// Retrieve logged actions for a specific scan, newest first.
  Future<List<ScanAction>> getActionsForScan(String scanId) {
    return (_db.select(_db.scanActions)
          ..where((t) => t.scanId.equals(scanId))
          ..orderBy([(t) => OrderingTerm.desc(t.performedAt)]))
        .get();
  }

  // -----------------------------------------------------------------
  // Ensure a local user & device exist (placeholder until auth exists).
  // -----------------------------------------------------------------
  Future<User> ensureLocalUser() async {
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
