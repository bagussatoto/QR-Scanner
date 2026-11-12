// lib/database/tables.dart
// -------------------------------------------------------------------
// Drift table definitions for the QR-Scanner app (mirrors README ERD).
// -------------------------------------------------------------------
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Base mixin: client-generated UUID primary key (offline-safe).
mixin UuidPk on Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();

  @override
  Set<Column> get primaryKey => {id};
}

class Users extends Table with UuidPk {
  TextColumn get email => text().nullable()();
  TextColumn get displayName => text().withLength(min: 1, max: 100)();
  TextColumn get authProvider =>
      text().withDefault(const Constant('local'))(); // local|google|apple|email
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Devices extends Table with UuidPk {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get platform => text()(); // android | ios
  TextColumn get deviceName => text().nullable()();
  TextColumn get appVersion => text().nullable()();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Folders extends Table with UuidPk {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get colorHex => text().withDefault(const Constant('#FFFFFF'))();
  TextColumn get iconName => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Tags extends Table with UuidPk {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get colorHex => text().withDefault(const Constant('#FFCC00'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ScanHistoryData')
class ScanHistory extends Table with UuidPk {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get deviceId => text().references(Devices, #id)();
  TextColumn get folderId => text().nullable().references(Folders, #id)();
  TextColumn get rawValue => text()();
  TextColumn get contentType =>
      text().withDefault(const Constant('text'))(); // url|wifi|vcard|text|product|geo
  TextColumn get barcodeFormat => text()(); // QR_CODE | EAN_13 | ...
  TextColumn get title => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('pending'))(); // pending|synced|failed
  DateTimeColumn get scannedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('QRGeneratedData')
class QRGenerated extends Table with UuidPk {
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get contentType => text()();
  TextColumn get payload => text()();
  TextColumn get fgColorHex => text().withDefault(const Constant('#000000'))();
  TextColumn get bgColorHex => text().withDefault(const Constant('#FFFFFF'))();
  TextColumn get errorCorrection =>
      text().withDefault(const Constant('M'))(); // L|M|Q|H
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ScanActions extends Table with UuidPk {
  TextColumn get scanId =>
      text().references(ScanHistory, #id, onDelete: KeyAction.cascade)();
  TextColumn get actionType => text()(); // open_url|copy|share|connect_wifi|save_contact
  DateTimeColumn get performedAt => dateTime().withDefault(currentDateAndTime)();
}

class ScanTags extends Table {
  TextColumn get scanId =>
      text().references(ScanHistory, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get assignedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {scanId, tagId};
}

@DataClassName('SyncQueueData')
class SyncQueue extends Table with UuidPk {
  TextColumn get deviceId => text().references(Devices, #id)();
  TextColumn get entityType => text()(); // scan_history|folders|tags|qr_generated
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // INSERT | UPDATE | DELETE
  TextColumn get payloadJson => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status =>
      text().withDefault(const Constant('queued'))(); // queued|processing|failed
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
