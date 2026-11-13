import 'package:flutter/material.dart';
import 'package:flutterqrscan/pages/qr_generator_page.dart';
import 'package:flutterqrscan/pages/scan_history_page.dart';
import 'package:flutterqrscan/pages/scanner_page.dart';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR-Scanner',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
      ),
      home: HomePage(),
    ));

class HomePage extends StatefulWidget {
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  String result = "Tekan tombol Scan di bawah untuk memulai pemindaian kamera.";

  Future<void> _scanQR() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (scanned != null && scanned.isNotEmpty) {
      setState(() {
        result = scanned;
      });
    }
  }

  Future<void> _scanBatch() async {
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScannerPage(initialBatchMode: true),
      ),
    );
    if (scanned != null && scanned.isNotEmpty) {
      setState(() {
        result = scanned;
      });
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanHistoryPage()),
    );
  }

  void _openGenerator() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QRGeneratorPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Scanner"),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.dynamic_feed),
            tooltip: 'Batch Scan (Berkelanjutan)',
            onPressed: _scanBatch,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Buat QR Code',
            onPressed: _openGenerator,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Scan',
            onPressed: _openHistory,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.deepOrange),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.qr_code_scanner, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'QR & Barcode Scanner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Offline & Encrypted SQLite',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scanner Kamera'),
              subtitle: const Text('Pemindai modern dengan viewfinder'),
              onTap: () {
                Navigator.of(context).pop();
                _scanQR();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dynamic_feed, color: Colors.amber),
              title: const Text('Batch Scanner (Berkelanjutan)'),
              subtitle: const Text('Pindai banyak barcode tanpa henti'),
              onTap: () {
                Navigator.of(context).pop();
                _scanBatch();
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_2),
              title: const Text('Buat QR Code'),
              subtitle: const Text('Generator dengan kustomisasi warna'),
              onTap: () {
                Navigator.of(context).pop();
                _openGenerator();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Riwayat Scan'),
              subtitle: const Text('Pencarian, folder, dan tag'),
              onTap: () {
                Navigator.of(context).pop();
                _openHistory();
              },
            ),
            const Divider(),
            const AboutListTile(
              icon: Icon(Icons.info_outline),
              applicationName: 'QR-Scanner',
              applicationVersion: '1.2.0 (Fase 2)',
              applicationLegalese: 'MIT License • Encrypted with SQLCipher',
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: Colors.deepOrange.shade600,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hasil Pemindaian Terakhir:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SelectableText(
                  result,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.dynamic_feed, color: Colors.deepOrange),
                label: const Text('Mulai Mode Batch Scan'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  side: const BorderSide(color: Colors.deepOrange),
                ),
                onPressed: _scanBatch,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt),
        label: const Text("Scan Kamera"),
        onPressed: _scanQR,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
