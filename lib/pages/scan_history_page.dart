// lib/pages/scan_history_page.dart
// -------------------------------------------------------------------
// UI page that displays scanned QR codes / barcodes with real-time
// search, favorite & folder filtering, tag management, copy action
// logging (ScanActions), and CSV / JSON export & backup restore.
// -------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterqrscan/database/database.dart';
import 'package:flutterqrscan/services/export_service.dart';
import 'package:flutterqrscan/services/folder_tag_service.dart';
import 'package:flutterqrscan/services/scan_service.dart';
import 'package:flutterqrscan/services/smart_action_service.dart';

class ScanHistoryPage extends StatefulWidget {
  const ScanHistoryPage({Key? key}) : super(key: key);

  @override
  State<ScanHistoryPage> createState() => _ScanHistoryPageState();
}

class _ScanHistoryPageState extends State<ScanHistoryPage> {
  final ScanService _scanService = ScanService.instance;
  final FolderTagService _folderTagService = FolderTagService.instance;
  final ExportService _exportService = ExportService.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _favoritesOnly = false;
  String? _selectedFolderId;
  String? _selectedTagId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copyScanValue(ScanHistoryData scan) async {
    await Clipboard.setData(ClipboardData(text: scan.rawValue));
    await _scanService.logAction(scanId: scan.id, actionType: 'copy');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teks berhasil disalin ke clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Folder Baru'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nama folder (mis. Kerja, Wi-Fi)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );

      if (created == true && controller.text.trim().isNotEmpty) {
        await _folderTagService.createFolder(name: controller.text.trim());
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showRenameFolderDialog(Folder folder) async {
    final controller = TextEditingController(text: folder.name);
    try {
      final updated = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ubah Nama Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nama folder baru',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );

      if (updated == true && controller.text.trim().isNotEmpty) {
        await _folderTagService.renameFolder(folder.id, controller.text.trim());
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showCreateTagDialog() async {
    final controller = TextEditingController();
    try {
      final created = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tag Baru'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nama tag (mis. Penting, Kantor)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      );

      if (created == true && controller.text.trim().isNotEmpty) {
        await _folderTagService.createTag(name: controller.text.trim());
      }
    } finally {
      controller.dispose();
    }
  }

  void _showManageFoldersAndTagsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.78,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Kelola Folder & Tag',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daftar Folder',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.create_new_folder_outlined,
                            size: 18),
                        label: const Text('+ Folder Baru'),
                        onPressed: _showCreateFolderDialog,
                      ),
                    ],
                  ),
                  StreamBuilder<List<Folder>>(
                    stream: _folderTagService.watchFolders(),
                    builder: (context, snapshot) {
                      final folders = snapshot.data ?? [];
                      if (folders.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Belum ada folder.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        );
                      }
                      return Column(
                        children: folders.map((folder) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.folder_outlined,
                                color: Colors.deepOrange),
                            title: Text(folder.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 19),
                                  tooltip: 'Ubah Nama',
                                  onPressed: () =>
                                      _showRenameFolderDialog(folder),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 19, color: Colors.red),
                                  tooltip: 'Hapus Folder',
                                  onPressed: () async {
                                    await _folderTagService
                                        .deleteFolder(folder.id);
                                    if (!mounted) return;
                                    if (_selectedFolderId == folder.id) {
                                      setState(() => _selectedFolderId = null);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Daftar Tag',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.new_label_outlined, size: 18),
                        label: const Text('+ Tag Baru'),
                        onPressed: _showCreateTagDialog,
                      ),
                    ],
                  ),
                  StreamBuilder<List<Tag>>(
                    stream: _folderTagService.watchTags(),
                    builder: (context, snapshot) {
                      final tags = snapshot.data ?? [];
                      if (tags.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Belum ada tag.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        );
                      }
                      return Column(
                        children: tags.map((tag) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.label_outline,
                                color: Colors.amber),
                            title: Text(tag.name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 19, color: Colors.red),
                              tooltip: 'Hapus Tag',
                              onPressed: () async {
                                await _folderTagService.deleteTag(tag.id);
                                if (!mounted) return;
                                if (_selectedTagId == tag.id) {
                                  setState(() => _selectedTagId = null);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleExportCsv() async {
    try {
      final csv = await _exportService.exportScansToCsv();
      await Clipboard.setData(ClipboardData(text: csv));

      String savedInfo = '';
      try {
        final file = await _exportService.saveExportToFile(
          filename: 'riwayat_scan.csv',
          content: csv,
        );
        savedInfo = '\nDisimpan di: ${file.path}';
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data CSV berhasil disalin ke clipboard!$savedInfo'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor CSV: $e')),
      );
    }
  }

  Future<void> _handleExportJson() async {
    try {
      final jsonStr = await _exportService.exportToJson();
      await Clipboard.setData(ClipboardData(text: jsonStr));

      String savedInfo = '';
      try {
        final file = await _exportService.saveExportToFile(
          filename: 'backup_qr_scanner.json',
          content: jsonStr,
        );
        savedInfo = '\nDisimpan di: ${file.path}';
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup JSON berhasil disalin ke clipboard!$savedInfo'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor JSON: $e')),
      );
    }
  }

  Future<void> _showImportJsonDialog() async {
    final jsonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore dari Backup JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tempelkan isi file backup JSON Anda di bawah ini untuk memulihkan riwayat scan dan QR code:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: jsonController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: '{\n  "app": "QR-Scanner",\n  "scans": [...]\n}',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.paste, size: 16),
                label: const Text('Tempel dari Clipboard'),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    jsonController.text = data!.text!;
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Pulihkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && jsonController.text.trim().isNotEmpty) {
      try {
        final count =
            await _exportService.importFromJson(jsonController.text.trim());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil memulihkan $count item dari backup JSON!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Format JSON tidak valid: $e')),
        );
      }
    }
  }

  void _showExportBackupSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ekspor & Backup Riwayat Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih format ekspor untuk membuka data di Excel/Spreadsheet atau mencadangkan seluruh database.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 24),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: const Icon(Icons.table_chart, color: Colors.green),
                ),
                title: const Text('Ekspor ke CSV (Excel / Spreadsheet)'),
                subtitle:
                    const Text('Format tabel RFC 4180 siap buka di Excel'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleExportCsv();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(Icons.code, color: Colors.blue),
                ),
                title: const Text('Backup Lengkap ke JSON'),
                subtitle: const Text(
                    'Mencakup riwayat scan, folder, dan QR yang dibuat'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleExportJson();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade50,
                  child: const Icon(Icons.restore, color: Colors.deepOrange),
                ),
                title: const Text('Restore / Impor dari JSON'),
                subtitle:
                    const Text('Pulihkan riwayat scan dari data backup JSON'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showImportJsonDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showScanDetails(ScanHistoryData scan) async {
    final folders = await _folderTagService.getAllFolders();
    final allTags = await _folderTagService.getAllTags();
    final assignedTags = await _folderTagService.getTagsForScan(scan.id);
    final assignedTagIds = assignedTags.map((t) => t.id).toSet();
    String? currentFolderId = scan.folderId;

    if (!mounted) return;

    final parsed =
        SmartActionService.instance.parse(scan.rawValue, scan.barcodeFormat);
    final titleController = TextEditingController(text: scan.title ?? '');
    final notesController = TextEditingController(text: scan.notes ?? '');

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(parsed.displayTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    scan.rawValue,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Format: ${scan.barcodeFormat}'),
                  Text('Tipe konten: ${scan.contentType}'),
                  Text(
                      'Waktu: ${scan.scannedAt.toLocal().toString().split('.').first}'),
                  if (parsed.attributes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: parsed.attributes.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              '${e.key}: ${e.value}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul',
                      hintText: 'Tambahkan judul (opsional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan',
                      hintText: 'Tambahkan catatan...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Simpan Judul & Catatan'),
                      onPressed: () async {
                        await _scanService.updateScanDetails(
                          scanId: scan.id,
                          title: titleController.text,
                          notes: notesController.text,
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Judul dan catatan berhasil diperbarui'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                  value: currentFolderId,
                  decoration: const InputDecoration(
                    labelText: 'Folder',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tanpa Folder'),
                    ),
                    ...folders.map(
                      (f) => DropdownMenuItem<String?>(
                        value: f.id,
                        child: Text(f.name),
                      ),
                    ),
                  ],
                  onChanged: (newFolderId) async {
                    await _scanService.assignFolder(scan.id, newFolderId);
                    setDialogState(() {
                      currentFolderId = newFolderId;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tag:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tag Baru'),
                      onPressed: () async {
                        final tagCtrl = TextEditingController();
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (innerCtx) => AlertDialog(
                            title: const Text('Tambah Tag'),
                            content: TextField(
                              controller: tagCtrl,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'Nama tag (mis. Penting)',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(innerCtx).pop(false),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(innerCtx).pop(true),
                                child: const Text('Tambah'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && tagCtrl.text.trim().isNotEmpty) {
                          final newTag = await _folderTagService.createTag(
                            name: tagCtrl.text.trim(),
                          );
                          await _folderTagService.assignTagToScan(
                            scanId: scan.id,
                            tagId: newTag.id,
                          );
                          setDialogState(() {
                            allTags.add(newTag);
                            assignedTagIds.add(newTag.id);
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (allTags.isEmpty)
                  const Text(
                    'Belum ada tag.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 6,
                    children: allTags.map((tag) {
                      final isSelected = assignedTagIds.contains(tag.id);
                      return FilterChip(
                        label: Text(tag.name),
                        selected: isSelected,
                        onSelected: (selected) async {
                          if (selected) {
                            await _folderTagService.assignTagToScan(
                              scanId: scan.id,
                              tagId: tag.id,
                            );
                            setDialogState(() => assignedTagIds.add(tag.id));
                          } else {
                            await _folderTagService.removeTagFromScan(
                              scanId: scan.id,
                              tagId: tag.id,
                            );
                            setDialogState(() => assignedTagIds.remove(tag.id));
                          }
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            if (parsed.actions.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      parsed.actions.first.color ?? Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(parsed.actions.first.icon, size: 16),
                label: Text(parsed.actions.first.label),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  SmartActionService.instance.executeAction(
                    context: context,
                    action: parsed.actions.first,
                    scanId: scan.id,
                  );
                },
              ),
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Salin'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _copyScanValue(scan);
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
    } finally {
      titleController.dispose();
      notesController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Scan'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_favoritesOnly ? Icons.star : Icons.star_border),
            tooltip: 'Filter Favorit',
            onPressed: () {
              setState(() {
                _favoritesOnly = !_favoritesOnly;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_special_outlined),
            tooltip: 'Kelola Folder & Tag',
            onPressed: _showManageFoldersAndTagsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.import_export),
            tooltip: 'Ekspor & Backup Data',
            onPressed: _showExportBackupSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari isi scan, judul, atau catatan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          StreamBuilder<List<Folder>>(
            stream: _folderTagService.watchFolders(),
            builder: (context, folderSnap) {
              final folders = folderSnap.data ?? [];
              if (folders.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Semua'),
                        selected: _selectedFolderId == null,
                        onSelected: (_) =>
                            setState(() => _selectedFolderId = null),
                      ),
                    ),
                    ...folders.map(
                      (folder) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(folder.name),
                          selected: _selectedFolderId == folder.id,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFolderId = selected ? folder.id : null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          StreamBuilder<List<Tag>>(
            stream: _folderTagService.watchTags(),
            builder: (context, tagSnap) {
              final tags = tagSnap.data ?? [];
              if (tags.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Semua Tag'),
                        selected: _selectedTagId == null,
                        onSelected: (_) =>
                            setState(() => _selectedTagId = null),
                      ),
                    ),
                    ...tags.map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: const Icon(Icons.label_outline, size: 16),
                          label: Text(tag.name),
                          selected: _selectedTagId == tag.id,
                          onSelected: (selected) {
                            setState(() {
                              _selectedTagId = selected ? tag.id : null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ScanHistoryData>>(
              stream: _scanService.watchFilteredScans(
                query: _searchQuery,
                favoritesOnly: _favoritesOnly,
                folderId: _selectedFolderId,
                tagId: _selectedTagId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final scans = snapshot.data ?? [];
                if (scans.isEmpty) {
                  return const Center(
                    child: Text('Tidak ada hasil pemindaian yang cocok.'),
                  );
                }
                return ListView.separated(
                  itemCount: scans.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final scan = scans[index];
                    return Dismissible(
                      key: ValueKey(scan.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.redAccent,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _scanService.deleteScan(scan.id),
                      child: ListTile(
                        leading: const Icon(Icons.qr_code),
                        title: Text(
                          scan.title ?? scan.rawValue,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${scan.barcodeFormat} • ${scan.scannedAt.toLocal().toString().split('.').first}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              tooltip: 'Salin',
                              onPressed: () => _copyScanValue(scan),
                            ),
                            IconButton(
                              icon: Icon(
                                scan.isFavorite
                                    ? Icons.star
                                    : Icons.star_border,
                                color: scan.isFavorite ? Colors.amber : null,
                              ),
                              tooltip: 'Favorit',
                              onPressed: () =>
                                  _scanService.toggleFavorite(scan),
                            ),
                          ],
                        ),
                        onTap: () => _showScanDetails(scan),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
