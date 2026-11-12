// lib/database/database.dart
// -------------------------------------------------------------------
// Encrypted Drift database (SQLCipher) for the QR-Scanner app.
// -------------------------------------------------------------------
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

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
  AppDatabase._internal() : super(_openConnection());

  static final AppDatabase _instance = AppDatabase._internal();
  static AppDatabase get instance => _instance;

  @override
  int get schemaVersion => 1;

  /// Live stream of non-deleted scans, newest first.
  Stream<List<ScanHistoryData>> watchScans() => (select(scanHistory)
        ..where((t) => t.isDeleted.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.scannedAt)]))
      .watch();

  /// One-shot fetch of non-deleted scans, newest first.
  Future<List<ScanHistoryData>> getAllScans() => (select(scanHistory)
        ..where((t) => t.isDeleted.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.scannedAt)]))
      .get();
}

// -------------------------------------------------------------------
// Encryption key management
// -------------------------------------------------------------------
const _keyStorageName = 'qr_scanner_db_key';
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Returns the DB key from the Keystore/Keychain, generating a random
/// 256-bit key on first launch.
Future<String> _getOrCreateDbKey() async {
  final existing = await _secureStorage.read(key: _keyStorageName);
  if (existing != null && existing.isNotEmpty) return existing;

  final rnd = Random.secure();
  final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
  final hexKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await _secureStorage.write(key: _keyStorageName, value: hexKey);
  return hexKey;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Load the SQLCipher native library instead of plain SQLite.
    if (Platform.isAndroid) {
      open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    }

    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'qr_scanner.sqlite'));
    final hexKey = await _getOrCreateDbKey();

    return NativeDatabase.createInBackground(
      file,
      // Runs on the background isolate, so the override must be repeated there.
      isolateSetup: () {
        open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      },
      setup: (rawDb) {
        // Fail fast if SQLCipher is not actually linked.
        final result = rawDb.select('PRAGMA cipher_version;');
        if (result.isEmpty) {
          throw UnsupportedError(
              'SQLCipher is not available - database would not be encrypted.');
        }
        // Raw 256-bit key (hex) - skips PBKDF2 derivation for faster opening.
        rawDb.execute("PRAGMA key = \"x'$hexKey'\";");
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}
