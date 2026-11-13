// lib/services/qr_generator_service.dart
// -------------------------------------------------------------------
// Service layer for generating and persisting QR codes to Drift DB.
// -------------------------------------------------------------------
import 'package:drift/drift.dart';
import 'package:flutterqrscan/database/database.dart';
import 'package:flutterqrscan/services/scan_service.dart';

class QRGeneratorService {
  QRGeneratorService._([AppDatabase? db, ScanService? scanService])
      : _db = db ?? AppDatabase.instance,
        _scanService = scanService ?? ScanService.instance;

  /// Creates a [QRGeneratorService] backed by custom instances (for unit testing).
  factory QRGeneratorService.forTesting(
    AppDatabase db, [
    ScanService? scanService,
  ]) =>
      QRGeneratorService._(db, scanService ?? ScanService.forTesting(db));

  static final QRGeneratorService instance = QRGeneratorService._();

  final AppDatabase _db;
  final ScanService _scanService;

  /// Insert a newly generated QR code into the local database.
  Future<QRGeneratedData> insertGeneratedQR({
    required String payload,
    String contentType = 'text',
    String fgColorHex = '#000000',
    String bgColorHex = '#FFFFFF',
    String errorCorrection = 'M',
  }) async {
    final user = await _scanService.ensureLocalUser();

    return _db.into(_db.qRGenerated).insertReturning(
          QRGeneratedCompanion.insert(
            userId: user.id,
            contentType: contentType,
            payload: payload,
            fgColorHex: Value(fgColorHex),
            bgColorHex: Value(bgColorHex),
            errorCorrection: Value(errorCorrection),
          ),
        );
  }

  /// Live stream of active (non-deleted) generated QR codes, newest first.
  Stream<List<QRGeneratedData>> watchGeneratedQRs() {
    return _db.watchGeneratedQRs();
  }

  /// Fetch all active (non-deleted) generated QR codes, newest first.
  Future<List<QRGeneratedData>> fetchAllGeneratedQRs() {
    return _db.getAllGeneratedQRs();
  }

  /// Soft-delete a generated QR record by setting `isDeleted = true`.
  Future<void> deleteGeneratedQR(String id) async {
    await (_db.update(_db.qRGenerated)..where((t) => t.id.equals(id))).write(
      QRGeneratedCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Permanently delete a generated QR record (optional / cleanup).
  Future<int> hardDeleteGeneratedQR(String id) {
    return (_db.delete(_db.qRGenerated)..where((t) => t.id.equals(id))).go();
  }
}

