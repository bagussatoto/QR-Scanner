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

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Detail Scan'),
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
                Text('Waktu: ${scan.scannedAt.toLocal()}'),
                const Divider(height: 24),
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
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Buat Folder',
            onPressed: _showCreateFolderDialog,
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
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ScanHistoryData>>(
              stream: _scanService.watchFilteredScans(
                query: _searchQuery,
                favoritesOnly: _favoritesOnly,
                folderId: _selectedFolderId,
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
