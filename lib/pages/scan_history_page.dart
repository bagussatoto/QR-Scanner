// lib/pages/scan_history_page.dart
// -------------------------------------------------------------------
// UI page that displays the list of scanned QR codes / barcodes.
// -------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutterqrscan/database/database.dart';
import 'package:flutterqrscan/services/scan_service.dart';

class ScanHistoryPage extends StatelessWidget {
  const ScanHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final db = AppDatabase.instance;
    final scanService = ScanService.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Scan'),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<List<ScanHistoryData>>(
        stream: db.watchScans(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final scans = snapshot.data ?? [];
          if (scans.isEmpty) {
            return const Center(child: Text('Tidak ada hasil pemindaian.'));
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
                onDismissed: (_) => scanService.deleteScan(scan.id),
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
                  trailing: IconButton(
                    icon: Icon(
                      scan.isFavorite ? Icons.star : Icons.star_border,
                      color: scan.isFavorite ? Colors.amber : null,
                    ),
                    onPressed: () => scanService.toggleFavorite(scan),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Detail Scan'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Value: ${scan.rawValue}'),
                            const SizedBox(height: 8),
                            Text('Format: ${scan.barcodeFormat}'),
                            const SizedBox(height: 8),
                            Text('Tipe konten: ${scan.contentType}'),
                            const SizedBox(height: 8),
                            Text('Waktu: ${scan.scannedAt.toLocal()}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Tutup'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
