// lib/database/tables.dart
// -------------------------------------------------------------------
// Drift table definitions for the QR‑Scanner app.
// -------------------------------------------------------------------
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// Helper UUID generator used for client‑side primary keys.
final _uuid = const Uuid();

class Users extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4()).named('id').customConstraint('PRIMARY KEY')();
  TextColumn get email => text().nullable().named('email').withLength(min: 5, max: 255)();
  TextColumn get displayName => text().named('display_name').withLength(min: 1, max: 100)();
  TextColumn get authProvider => text().named('auth_provider').withDefault(Constant('local'))(); // local | google | apple | email
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
}

class Devices extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4()).named('id').customConstraint('PRIMARY KEY')();
  TextColumn get userId => text().named('user_id').references(Users, #id)();
  TextColumn get platform => text().named('platform')(); // android | ios
  TextColumn get deviceName => text().named('device_name').nullable()();
  TextColumn get appVersion => text().named('app_version').nullable()();
  DateTimeColumn get lastSyncAt => dateTime().named('last_sync_at').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
}

class Folders extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4()).named('id').customConstraint('PRIMARY KEY')();
  TextColumn get userId => text().named('user_id').references(Users, #id)();
  TextColumn get name => text().named('name').withLength(min: 1, max: 100)();
  TextColumn get colorHex => text().named('color_hex').withLength(min: 4, max: 7).withDefault(Constant('#FFFFFF'))();
  TextColumn get iconName => text().named('icon_name').nullable()();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
}

class Tags extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4()).named('id').customConstraint('PRIMARY KEY')();
  TextColumn get userId => text().named('user_id').references(Users, #id)();
  TextColumn get name => text().named('name').withLength(min: 1, max: 50)();
  TextColumn get colorHex => text().named('color_hex').withLength(min: 4, max: 7).withDefault(Constant('#FFCC00'))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class ScanHistory extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4()).named('id').customConstraint('PRIMARY KEY')();
  TextColumn get userId => text().named('user_id').references(Users, #id)();
  TextColumn get deviceId => text().named('device_id').references(Devices, #id)();
  TextColumn get folderId => text().named('folder_id').nullable().references(Folders, #id)();
  TextColumn get rawValue => text().named('raw_value')();
  TextColumn get contentType => text().named('content_type').withDefault(Constant('text'))(); // url | wifi | vcard | text | product | geo
  TextColumn get barcodeFormat => text().named('barcode_format')(); // QR_CODE, EAN_13, etc.
  TextColumn get title => text().named('title').nullable()();
  TextColumn get notes => text().named('notes').nullable()();
  BoolColumn get isFavorite => boolean().named('is_favorite').withDefault(Constant(false))();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(Constant(false))();
  TextColumn get syncStatus => text().named('sync_status').withDefault(Constant('pending'))(); // pending | synced | failed
  DateTimeColumn get scannedAt => dateTime().named('scanned_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
}

class QRGenerated extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4()).named('id').customConstraint('PRIMARY KEY')();
  TextColumn get userId => text().named('user_id').references(Users, #id)();
  TextColumn get contentType => text().named('content_type')(); // url | wifi | vcard | text
  TextColumn get payload => text().named('payload')();
  TextColumn get fgColorHex => text().named('fg_color_hex').withLength(min: 4, max: 7).withDefault(Constant('#000000'))();
  TextColumn get bgColorHex => text().named('bg_color_hex').withLength(min: 4, max: 7).withDefault(Constant('#FFFFFF'))();
  TextColumn get errorCorrection => text().named('error_correction').withDefault(Constant('M'))(); // L|M|Q|H
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
}

class ScanActions extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4()).named('id').customConstraint('PRIMARY KEY')();
  TextColumn get scanId => text().named('scan_id').references(ScanHistory, #id)();
  TextColumn get actionType => text().named('action_type')(); // open_url | copy | share | connect_wifi | save_contact
  DateTimeColumn get performedAt => dateTime().named('performed_at').withDefault(currentDateAndTime)();
}

class ScanTags extends Table {
  TextColumn get scanId => text().named('scan_id').references(ScanHistory, #id)();
  TextColumn get tagId => text().named('tag_id').references(Tags, #id)();
  DateTimeColumn get assignedAt => dateTime().named('assigned_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {scanId, tagId};
}

class SyncQueue extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4()).named('id').customConstraint('PRIMARY KEY')();
  TextColumn get deviceId => text().named('device_id').references(Devices, #id)();
  TextColumn get entityType => text().named('entity_type')(); // scan_history | folders | tags | qr_generated
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get operation => text().named('operation')(); // INSERT | UPDATE | DELETE
  TextColumn get payloadJson => text().named('payload_json').named('payload_json')();
  IntColumn get retryCount => integer().named('retry_count').withDefault(Constant(0))();
  TextColumn get status => text().named('status').withDefault(Constant('queued'))(); // queued | processing | failed
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
}

// -------------------------------------------------------------------
// End of table definitions.
// -------------------------------------------------------------------

