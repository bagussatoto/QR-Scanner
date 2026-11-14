// lib/pages/analytics_page.dart
// -------------------------------------------------------------------
// Dashboard displaying aggregated scan statistics, content type
// breakdown, barcode format distribution, and report sharing.
// -------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterqrscan/services/analytics_service.dart';
import 'package:flutterqrscan/services/export_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({Key? key}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late Future<ScanAnalyticsReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _loadReport() {
    setState(() {
      _reportFuture = AnalyticsService.instance.getReport();
    });
  }

  void _copySummary(ScanAnalyticsReport report) {
    Clipboard.setData(ClipboardData(text: report.toSummaryText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Laporan statistik berhasil disalin ke clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _exportCsv() async {
    final csv = await ExportService.instance.exportScansToCsv();
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data CSV berhasil diekspor dan disalin ke clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _exportJson() async {
    final jsonStr = await ExportService.instance.exportToJson();
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backup JSON berhasil diekspor dan disalin ke clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Color _getContentTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'url':
        return Colors.blue;
      case 'wifi':
        return Colors.teal;
      case 'vcard':
        return Colors.purple;
      case 'product':
        return Colors.orange;
      case 'geo':
        return Colors.redAccent;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getContentTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'url':
        return Icons.link;
      case 'wifi':
        return Icons.wifi;
      case 'vcard':
        return Icons.person;
      case 'product':
        return Icons.shopping_bag;
      case 'geo':
        return Icons.location_on;
      default:
        return Icons.text_snippet;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik & Analisis'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Data',
            onPressed: _loadReport,
          ),
        ],
      ),
      body: FutureBuilder<ScanAnalyticsReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text('Gagal memuat statistik: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadReport,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final report = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _loadReport(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KPI Overview Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Total Pemindaian',
                          value: '${report.totalScans}',
                          icon: Icons.qr_code_scanner,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Kode Favorit',
                          value: '${report.totalFavorites}',
                          icon: Icons.star,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          title: 'QR Dibuat',
                          value: '${report.totalGeneratedQRs}',
                          icon: Icons.qr_code_2,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard(
                          title: 'Folder & Tag',
                          value: '${report.totalFolders} / ${report.totalTags}',
                          icon: Icons.folder,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Periode Waktu Pemindaian
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Hari Ini',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${report.scansToday} scan',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 36,
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '7 Hari Terakhir',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${report.scansThisWeek} scan',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Distribusi Kategori Konten
                  const Text(
                    'Distribusi Kategori Konten',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: report.contentTypeCounts.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('Belum ada data pemindaian.'),
                              ),
                            )
                          : Column(
                              children: report.contentTypeCounts.entries
                                  .map((entry) {
                                final type = entry.key;
                                final count = entry.value;
                                final pct = report.totalScans > 0
                                    ? (count / report.totalScans)
                                    : 0.0;
                                final color = _getContentTypeColor(type);
                                final icon = _getContentTypeIcon(type);

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(icon, size: 18, color: color),
                                          const SizedBox(width: 8),
                                          Text(
                                            type.toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '$count item (${(pct * 100).toStringAsFixed(1)}%)',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: pct,
                                          backgroundColor:
                                              Colors.grey.shade200,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  color),
                                          minHeight: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Distribusi Format Barcode
                  const Text(
                    'Format Barcode Terdeteksi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: report.formatCounts.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('Belum ada format terdeteksi.'),
                              ),
                            )
                          : Column(
                              children:
                                  report.formatCounts.entries.map((entry) {
                                final format = entry.key;
                                final count = entry.value;
                                final pct = report.totalScans > 0
                                    ? (count / report.totalScans)
                                    : 0.0;

                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.deepOrange.shade50,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: Colors
                                                  .deepOrange.shade200),
                                        ),
                                        child: Text(
                                          format,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '$count (${(pct * 100).toStringAsFixed(1)}%)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tombol Salin Laporan
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.share),
                    label: const Text(
                      'Salin Ringkasan Laporan',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _copySummary(report),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.table_chart,
                              color: Colors.green),
                          label: const Text('Ekspor CSV'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _exportCsv,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.code, color: Colors.blue),
                          label: const Text('Backup JSON'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _exportJson,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

