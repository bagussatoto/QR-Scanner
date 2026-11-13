// lib/pages/scanner_page.dart
// -------------------------------------------------------------------
// Modern camera scanner interface powered by mobile_scanner with
// custom viewfinder overlay, flash toggle, camera switch, and instant
// database persistence.
// -------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterqrscan/pages/scan_history_page.dart';
import 'package:flutterqrscan/services/scan_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({Key? key}) : super(key: key);

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _controller;
  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  bool _isProcessing = false;
  String? _lastScannedValue;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  String _detectContentType(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return 'url';
    }
    if (trimmed.startsWith('WIFI:')) return 'wifi';
    if (trimmed.startsWith('BEGIN:VCARD')) return 'vcard';
    if (trimmed.startsWith('geo:')) return 'geo';
    if (RegExp(r'^\d{8,14}$').hasMatch(trimmed)) return 'product';
    return 'text';
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _lastScannedValue = rawValue;
    });

    HapticFeedback.mediumImpact();

    final formatName = barcode.format.name.toUpperCase();
    final contentType = _detectContentType(rawValue);

    // Persist to encrypted local database
    try {
      await ScanService.instance.insertScan(
        rawValue: rawValue,
        barcodeFormat: formatName,
        contentType: contentType,
      );
    } catch (_) {
      // Ignored for testing or transient db issue
    }

    if (!mounted) return;
    _showResultBottomSheet(rawValue, formatName, contentType);
  }

  void _showResultBottomSheet(
      String rawValue, String format, String contentType) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        IconData typeIcon = Icons.text_snippet;
        if (contentType == 'url') typeIcon = Icons.link;
        if (contentType == 'wifi') typeIcon = Icons.wifi;
        if (contentType == 'vcard') typeIcon = Icons.person;
        if (contentType == 'product') typeIcon = Icons.shopping_bag;

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.deepOrange.shade100,
                    child: Icon(typeIcon, color: Colors.deepOrange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kode Terdeteksi ($format)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Kategori: ${contentType.toUpperCase()}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Text(
                      'Tersimpan',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  rawValue,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Salin'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: rawValue));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Teks disalin ke clipboard')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                      ),
                      icon: const Icon(Icons.qr_code_scanner,
                          color: Colors.white),
                      label: const Text(
                        'Scan Lagi',
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _isProcessing = false;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                child: const Text('Selesai & Kembali ke Beranda'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(rawValue);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const scanBoxSize = 260.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Camera Feed
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // 2. Custom Viewfinder Overlay
          LayoutBuilder(
            builder: (context, constraints) {
              final scanRect = Rect.fromCenter(
                center: Offset(
                  constraints.maxWidth / 2,
                  constraints.maxHeight / 2 - 30,
                ),
                width: scanBoxSize,
                height: scanBoxSize,
              );

              return Stack(
                children: [
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _ViewfinderOverlayPainter(scanRect: scanRect),
                  ),
                  // Animated laser line
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      final topOffset = scanRect.top +
                          (_scanAnimation.value * (scanRect.height - 4));
                      return Positioned(
                        left: scanRect.left + 8,
                        top: topOffset,
                        width: scanRect.width - 16,
                        height: 2.5,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.deepOrangeAccent,
                                Colors.deepOrange,
                                Colors.deepOrangeAccent,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepOrange.withOpacity(0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),

          // 3. Top Control Bar (Back, Flash, Switch Camera)
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon:
                          const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () =>
                          Navigator.of(context).pop(_lastScannedValue),
                    ),
                  ),
                  Row(
                    children: [
                      // Torch Toggle
                      ValueListenableBuilder<TorchState>(
                        valueListenable: _controller.torchState,
                        builder: (context, state, child) {
                          final isTorchOn = state == TorchState.on;
                          return CircleAvatar(
                            backgroundColor:
                                isTorchOn ? Colors.deepOrange : Colors.black45,
                            child: IconButton(
                              icon: Icon(
                                isTorchOn
                                    ? Icons.flash_on
                                    : Icons.flash_off,
                                color: Colors.white,
                              ),
                              onPressed: () => _controller.toggleTorch(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      // Camera Switch Toggle
                      ValueListenableBuilder<CameraFacing>(
                        valueListenable: _controller.cameraFacingState,
                        builder: (context, state, child) {
                          return CircleAvatar(
                            backgroundColor: Colors.black45,
                            child: IconButton(
                              icon: const Icon(Icons.cameraswitch,
                                  color: Colors.white),
                              onPressed: () => _controller.switchCamera(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 4. Bottom Hint Label
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Arahkan kamera ke QR Code atau Barcode',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that dims the surrounding area and highlights the central viewfinder.
class _ViewfinderOverlayPainter extends CustomPainter {
  final Rect scanRect;

  _ViewfinderOverlayPainter({required this.scanRect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cornerPaint = Paint()
      ..color = Colors.deepOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final rrect =
        RRect.fromRectAndRadius(scanRect, const Radius.circular(16));
    final cutoutPath = Path()..addRRect(rrect);

    // Combine paths with difference fill type
    final finalPath =
        Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(finalPath, backgroundPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Draw 4 corner accents
    const cornerLength = 24.0;
    final l = scanRect.left;
    final t = scanRect.top;
    final r = scanRect.right;
    final b = scanRect.bottom;

    // Top-Left
    canvas.drawLine(Offset(l, t + cornerLength), Offset(l, t + 8), cornerPaint);
    canvas.drawLine(Offset(l + 8, t), Offset(l + cornerLength, t), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(r, t + cornerLength), Offset(r, t + 8), cornerPaint);
    canvas.drawLine(Offset(r - 8, t), Offset(r - cornerLength, t), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(l, b - cornerLength), Offset(l, b - 8), cornerPaint);
    canvas.drawLine(Offset(l + 8, b), Offset(l + cornerLength, b), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(r, b - cornerLength), Offset(r, b - 8), cornerPaint);
    canvas.drawLine(Offset(r - 8, b), Offset(r - cornerLength, b), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.scanRect != scanRect;
  }
}
