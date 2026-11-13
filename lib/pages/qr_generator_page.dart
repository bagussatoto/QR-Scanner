// lib/pages/qr_generator_page.dart
// -------------------------------------------------------------------
// Page to customize, preview, and save newly generated QR codes.
// -------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterqrscan/database/database.dart';
import 'package:flutterqrscan/services/qr_generator_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRGeneratorPage extends StatefulWidget {
  const QRGeneratorPage({Key? key}) : super(key: key);

  @override
  State<QRGeneratorPage> createState() => _QRGeneratorPageState();
}

class _QRGeneratorPageState extends State<QRGeneratorPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _payloadController = TextEditingController();
  final QRGeneratorService _service = QRGeneratorService.instance;

  late TabController _tabController;

  String _selectedType = 'text'; // url | text | wifi | vcard
  Color _fgColor = Colors.black;
  Color _bgColor = Colors.white;
  int _errorCorrectionLevel = QrErrorCorrectLevel.M;
  String _errorCorrectionLabel = 'M';

  final List<Map<String, dynamic>> _fgColors = [
    {'name': 'Hitam', 'color': Colors.black, 'hex': '#000000'},
    {'name': 'Oranye', 'color': Colors.deepOrange, 'hex': '#FF5722'},
    {'name': 'Biru', 'color': const Color(0xFF1976D2), 'hex': '#1976D2'},
    {'name': 'Hijau', 'color': const Color(0xFF388E3C), 'hex': '#388E3C'},
    {'name': 'Ungu', 'color': const Color(0xFF7B1FA2), 'hex': '#7B1FA2'},
  ];

  final List<Map<String, dynamic>> _bgColors = [
    {'name': 'Putih', 'color': Colors.white, 'hex': '#FFFFFF'},
    {'name': 'Abu Lembut', 'color': const Color(0xFFF5F5F5), 'hex': '#F5F5F5'},
    {'name': 'Krem', 'color': const Color(0xFFFFFDE7), 'hex': '#FFFDE7'},
  ];

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _payloadController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _applyTypeTemplate(String type) {
    setState(() {
      _selectedType = type;
      if (type == 'url' && _payloadController.text.isEmpty) {
        _payloadController.text = 'https://';
      } else if (type == 'wifi') {
        _payloadController.text = 'WIFI:S:NamaWiFi;T:WPA;P:KataSandi;;';
      } else if (type == 'vcard') {
        _payloadController.text =
            'BEGIN:VCARD\nVERSION:3.0\nFN:Bagus Satoto\nTEL:+6281234567890\nEMAIL:bagus@example.com\nEND:VCARD';
      }
    });
  }

  Future<void> _saveQRCode() async {
    final text = _payloadController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan konten QR terlebih dahulu')),
      );
      return;
    }

    try {
      await _service.insertGeneratedQR(
        payload: text,
        contentType: _selectedType,
        fgColorHex: _colorToHex(_fgColor),
        bgColorHex: _colorToHex(_bgColor),
        errorCorrection: _errorCorrectionLabel,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode QR berhasil disimpan ke basis data!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Teks disalin ke clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Generator'),
        backgroundColor: Colors.deepOrange,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'Buat Baru'),
            Tab(icon: Icon(Icons.list_alt), text: 'Riwayat Dibuat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneratorTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildGeneratorTab() {
    final payload = _payloadController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // QR Preview Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: payload.isEmpty
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2,
                                  size: 72, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'Ketik teks untuk melihat QR',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          )
                        : QrImageView(
                            data: payload,
                            version: QrVersions.auto,
                            size: 200.0,
                            backgroundColor: _bgColor,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: _fgColor,
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: _fgColor,
                            ),
                            errorCorrectionLevel: _errorCorrectionLevel,
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(
                        label: Text('Tipe: $_selectedType'),
                        backgroundColor: Colors.deepOrange.shade50,
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('Koreksi: $_errorCorrectionLabel'),
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tipe Payload Chips
          const Text('Kategori Konten:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Teks'),
                selected: _selectedType == 'text',
                onSelected: (_) => _applyTypeTemplate('text'),
              ),
              ChoiceChip(
                label: const Text('URL'),
                selected: _selectedType == 'url',
                onSelected: (_) => _applyTypeTemplate('url'),
              ),
              ChoiceChip(
                label: const Text('Wi-Fi'),
                selected: _selectedType == 'wifi',
                onSelected: (_) => _applyTypeTemplate('wifi'),
              ),
              ChoiceChip(
                label: const Text('vCard'),
                selected: _selectedType == 'vcard',
                onSelected: (_) => _applyTypeTemplate('vcard'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Input Konten
          TextField(
            controller: _payloadController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Konten / Payload QR',
              hintText: 'Tulis tautan atau teks di sini...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _payloadController.clear();
                  setState(() {});
                },
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Warna Depan (Foreground)
          const Text('Warna Kode QR (Foreground):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: _fgColors.map((item) {
              final color = item['color'] as Color;
              final isSelected = _fgColor == color;
              return GestureDetector(
                onTap: () => setState(() => _fgColor = color),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.deepOrange : Colors.grey.shade400,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Level Koreksi Eror
          const Text('Tingkat Toleransi Eror (Error Correction):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildCorrectionRadio('L (7%)', QrErrorCorrectLevel.L, 'L'),
              _buildCorrectionRadio('M (15%)', QrErrorCorrectLevel.M, 'M'),
              _buildCorrectionRadio('Q (25%)', QrErrorCorrectLevel.Q, 'Q'),
              _buildCorrectionRadio('H (30%)', QrErrorCorrectLevel.H, 'H'),
            ],
          ),
          const SizedBox(height: 20),

          // Tombol Aksi
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Simpan QR',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  onPressed: _saveQRCode,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
                icon: const Icon(Icons.copy),
                label: const Text('Salin'),
                onPressed: payload.isEmpty
                    ? null
                    : () => _copyToClipboard(payload),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectionRadio(String label, int value, String code) {
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _errorCorrectionLevel = value;
            _errorCorrectionLabel = code;
          });
        },
        child: Row(
          children: [
            Radio<int>(
              value: value,
              groupValue: _errorCorrectionLevel,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _errorCorrectionLevel = val;
                    _errorCorrectionLabel = code;
                  });
                }
              },
            ),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<QRGeneratedData>>(
      stream: _service.watchGeneratedQRs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text('Belum ada QR Code yang dibuat',
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final item = list[index];
            return ListTile(
              leading: Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: item.payload,
                  version: QrVersions.auto,
                  size: 40.0,
                ),
              ),
              title: Text(
                item.payload,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Tipe: ${item.contentType} • Koreksi: ${item.errorCorrection}\n${item.createdAt.toString().substring(0, 16)}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Salin Konten',
                    onPressed: () => _copyToClipboard(item.payload),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.red),
                    tooltip: 'Hapus',
                    onPressed: () async {
                      await _service.deleteGeneratedQR(item.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('QR Code telah dihapus')),
                      );
                    },
                  ),
                ],
              ),
              onTap: () {
                _payloadController.text = item.payload;
                setState(() {
                  _selectedType = item.contentType;
                });
                _tabController.animateTo(0);
              },
            );
          },
        );
      },
    );
  }
}

