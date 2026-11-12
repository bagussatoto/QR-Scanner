// lib/pages/scan_history_page.dart
// -------------------------------------------------------------------
// UI page that displays the list of scanned QR codes / barcodes.
// -------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:qr_scanner/database/database.dart'; // adjust import path if needed
import 'package:qr_scanner/database/database.dart';
import 'package:qr_scanner/database/database.dart';

class ScanHistoryPage extends StatelessWidget {
  const ScanHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final db = AppDatabase.instance;
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
              return ListTile(
                leading: const Icon(Icons.qr_code),
                title: Text(scan.title ?? scan.rawValue,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${scan.barcodeFormat} • ${scan.scannedAt.toLocal().toString().split('.').first}',
                ),
                trailing: IconButton(
                  icon: Icon(
                    scan.isFavorite ? Icons.star : Icons.star_border,
                    color: scan.isFavorite ? Colors.amber : null,
                  ),
                  onPressed: () async {
                    // Toggle favorite flag
                    final updated = scan.copyWith(isFavorite: !scan.isFavorite);
                    await (db.update(db.scanHistory)
                          ..where((t) => t.id.equals(scan.id)))
                        .write(updated);
                  },
                ),
                onTap: () {
                  // Show a simple detail dialog
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
              );
            },
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------------
// END – ScanHistoryPage.
// -------------------------------------------------------------------

