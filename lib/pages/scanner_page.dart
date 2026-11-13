// lib/pages/scanner_page.dart
// -------------------------------------------------------------------
// Modern camera scanner interface powered by mobile_scanner with
// custom viewfinder overlay, flash toggle, camera switch, single scan
// and continuous Batch Scanning mode.
// -------------------------------------------------------------------
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterqrscan/pages/scan_history_page.dart';
import 'package:flutterqrscan/services/scan_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerPage extends StatefulWidget {
  final bool initialBatchMode;

  const ScannerPage({
    Key? key,
    this.initialBatchMode = false,
  }) : super(key: key);

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _controller;
  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  late bool _isBatchMode;
  bool _isProcessingSingle = false;
  String? _lastScannedValue;
  DateTime? _lastScannedTime;

  // Batch scan session list
  final List<Map<String, dynamic>> _batchItems = [];
  String? _transientFeedback;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _isBatchMode = widget.initialBatchMode;

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
    _feedbackTimer?.cancel();
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
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    final now = DateTime.now();

    // -------------------------------------------------------------
    // BATCH SCAN MODE: Continuous scan with duplicate prevention
    // -------------------------------------------------------------
    if (_isBatchMode) {
      if (_lastScannedValue == rawValue &&
          _lastScannedTime != null &&
          now.difference(_lastScannedTime!).inMilliseconds < 1500) {
        return; // debounce duplicate scan
      }

      _lastScannedValue = rawValue;
      _lastScannedTime = now;

      HapticFeedback.lightImpact();

      final formatName = barcode.format.name.toUpperCase();
      final contentType = _detectContentType(rawValue);

      // Persist to encrypted local database
      try {
        await ScanService.instance.insertScan(
          rawValue: rawValue,
          barcodeFormat: formatName,
          contentType: contentType,
        );
      } catch (_) {}

      setState(() {
        _batchItems.insert(0, {
          'rawValue': rawValue,
          'format': formatName,
          'contentType': contentType,
          'time': now,
        });
        _transientFeedback = '✓ [#${_batchItems.length}] $rawValue';
      });

      _feedbackTimer?.cancel();
      _feedbackTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _transientFeedback = null;
          });
        }
      });

      return;
    }

    // -------------------------------------------------------------
    // SINGLE SCAN MODE: Modal presentation
    // -------------------------------------------------------------
    if (_isProcessingSingle) return;

    setState(() {
      _isProcessingSingle = true;
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
    } catch (_) {}

    if (!mounted) return;
    _showSingleResultBottomSheet(rawValue, formatName, contentType);
  }

  void _showSingleResultBottomSheet(
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
                          _isProcessingSingle = false;
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

  void _showBatchTrayBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.dynamic_feed,
                              color: Colors.deepOrange),
                          const SizedBox(width: 8),
                          Text(
                            'Sesi Batch (${_batchItems.length} item)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _batchItems.isEmpty
                            ? null
                            : () {
                                final allText = _batchItems
                                    .map((e) => e['rawValue'])
                                    .join('\n');
                                Clipboard.setData(ClipboardData(text: allText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Semua item batch disalin ke clipboard')),
                                );
                              },
                        child: const Text('Salin Semua'),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_batchItems.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Belum ada barcode yang dipindai dalam sesi ini.\nArahkan kamera ke barcode untuk memindai.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: _batchItems.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _batchItems[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.deepOrange.shade100,
                              child: Text(
                                '${_batchItems.length - index}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              item['rawValue'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${item['format']} • ${item['contentType']}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: item['rawValue']));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Item disalin')),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                    },
                    child: const Text(
                      'Lanjut Memindai',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
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
                  constraints.maxHeight / 2 - 40,
                ),
                width: scanBoxSize,
                height: scanBoxSize,
              );

              return Stack(
                children: [
                  CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _ViewfinderOverlayPainter(
                      scanRect: scanRect,
                      isBatchMode: _isBatchMode,
                    ),
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
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                _isBatchMode
                                    ? Colors.amberAccent
                                    : Colors.deepOrangeAccent,
                                _isBatchMode
                                    ? Colors.amber
                                    : Colors.deepOrange,
                                _isBatchMode
                                    ? Colors.amberAccent
                                    : Colors.deepOrangeAccent,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isBatchMode
                                        ? Colors.amber
                                        : Colors.deepOrange)
                                    .withOpacity(0.6),
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

          // 3. Top Control Bar & Mode Switcher
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.of(context)
                              .pop(_lastScannedValue ??
                                  (_batchItems.isNotEmpty
                                      ? '${_batchItems.length} item tersimpan'
                                      : null)),
                        ),
                      ),

                      // Segmented Mode Switcher (Standar vs Batch)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isBatchMode = false;
                                  _isProcessingSingle = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: !_isBatchMode
                                      ? Colors.deepOrange
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.qr_code,
                                        size: 14, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('Standar',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isBatchMode = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _isBatchMode
                                      ? Colors.amber.shade700
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.dynamic_feed,
                                        size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    const Text('Batch',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                    if (_batchItems.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.black45,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${_batchItems.length}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                                backgroundColor: isTorchOn
                                    ? Colors.deepOrange
                                    : Colors.black45,
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
                          const SizedBox(width: 8),
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

                  // Transient feedback badge
                  if (_transientFeedback != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        _transientFeedback!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 4. Bottom Control Bar (Batch Tray or Single Mode Hint)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _isBatchMode
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade600),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _showBatchTrayBottomSheet,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${_batchItems.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'Mode Batch Aktif',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Ketuk untuk lihat daftar',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Selesai'),
                          onPressed: () {
                            Navigator.of(context).pop(
                              _batchItems.isNotEmpty
                                  ? '${_batchItems.length} item terpindai dalam sesi batch'
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
  final bool isBatchMode;

  _ViewfinderOverlayPainter({
    required this.scanRect,
    this.isBatchMode = false,
  });

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
      ..color = isBatchMode ? Colors.amber : Colors.deepOrange
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
    return oldDelegate.scanRect != scanRect ||
        oldDelegate.isBatchMode != isBatchMode;
  }
}
