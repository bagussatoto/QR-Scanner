// lib/services/folder_tag_service.dart
// -------------------------------------------------------------------
// Service layer for managing Folders, Tags, and ScanTags (M:N).
// -------------------------------------------------------------------
import 'package:drift/drift.dart';
import 'package:flutterqrscan/database/database.dart';
import 'package:flutterqrscan/services/scan_service.dart';

class FolderTagService {
  FolderTagService._([AppDatabase? db, ScanService? scanService])
      : _db = db ?? AppDatabase.instance,
        _scanService = scanService ?? ScanService.instance;

  /// Creates a [FolderTagService] backed by a custom [AppDatabase] instance
  /// for unit testing.
  factory FolderTagService.forTesting(
    AppDatabase db, [
    ScanService? scanService,
  ]) =>
      FolderTagService._(db, scanService ?? ScanService.forTesting(db));

  static final FolderTagService instance = FolderTagService._();

  final AppDatabase _db;
  final ScanService _scanService;

  // -----------------------------------------------------------------
  // Folders
  // -----------------------------------------------------------------

  Future<Folder> createFolder({
    required String name,
    String colorHex = '#FF5722',
    String? iconName,
  }) async {
    final user = await _scanService.ensureLocalUser();
    return _db.into(_db.folders).insertReturning(
          FoldersCompanion.insert(
            userId: user.id,
            name: name.trim(),
            colorHex: Value(colorHex),
            iconName: Value(iconName),
          ),
        );
  }

  Future<List<Folder>> getAllFolders() {
    return (_db.select(_db.folders)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Stream<List<Folder>> watchFolders() {
    return (_db.select(_db.folders)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Soft-delete a folder and detach any scans currently assigned to it.
  Future<void> deleteFolder(String folderId) async {
    await _db.transaction(() async {
      await (_db.update(_db.scanHistory)
            ..where((t) => t.folderId.equals(folderId)))
          .write(ScanHistoryCompanion(
        folderId: const Value(null),
        updatedAt: Value(DateTime.now()),
      ));

      await (_db.update(_db.folders)..where((t) => t.id.equals(folderId)))
          .write(FoldersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ));
    });
  }

  // -----------------------------------------------------------------
  // Tags & ScanTags (Many-to-Many)
  // -----------------------------------------------------------------

  Future<Tag> createTag({
    required String name,
    String colorHex = '#FFCC00',
  }) async {
    final user = await _scanService.ensureLocalUser();
    return _db.into(_db.tags).insertReturning(
          TagsCompanion.insert(
            userId: user.id,
            name: name.trim(),
            colorHex: Value(colorHex),
          ),
        );
  }

  Future<List<Tag>> getAllTags() {
    return (_db.select(_db.tags)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  Stream<List<Tag>> watchTags() {
    return (_db.select(_db.tags)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Attach a tag to a scan (ignores if already attached).
  Future<void> assignTagToScan({
    required String scanId,
    required String tagId,
  }) async {
    await _db.into(_db.scanTags).insert(
          ScanTagsCompanion.insert(scanId: scanId, tagId: tagId),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Detach a tag from a scan.
  Future<void> removeTagFromScan({
    required String scanId,
    required String tagId,
  }) async {
    await (_db.delete(_db.scanTags)
          ..where((t) => t.scanId.equals(scanId) & t.tagId.equals(tagId)))
        .go();
  }

  /// Fetch all [Tag]s attached to a given [scanId].
  Future<List<Tag>> getTagsForScan(String scanId) async {
    final query = _db.select(_db.tags).join([
      innerJoin(
        _db.scanTags,
        _db.scanTags.tagId.equalsExp(_db.tags.id),
      ),
    ])
      ..where(_db.scanTags.scanId.equals(scanId))
      ..orderBy([OrderingTerm.asc(_db.tags.name)]);

    final rows = await query.get();
    return rows.map((row) => row.readTable(_db.tags)).toList();
  }
}

