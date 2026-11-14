// lib/services/smart_action_service.dart
// -------------------------------------------------------------------
// Service for parsing scanned barcodes/QR codes into structured payloads
// and executing contextual smart actions (Browser, Wi-Fi, Phone, Mail,
// Maps, Contacts, Product Search) with action logging.
// -------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterqrscan/services/scan_service.dart';
import 'package:url_launcher/url_launcher.dart';

enum SmartContentType {
  url,
  wifi,
  vcard,
  email,
  phone,
  sms,
  geo,
  product,
  text,
}

class SmartActionItem {
  final String label;
  final IconData icon;
  final Color? color;
  final String actionType;
  final String target;
  final bool isPrimary;

  const SmartActionItem({
    required this.label,
    required this.icon,
    required this.actionType,
    required this.target,
    this.color,
    this.isPrimary = false,
  });
}

class ParsedScanPayload {
  final SmartContentType type;
  final String rawValue;
  final String displayTitle;
  final String displaySubtitle;
  final Map<String, String> attributes;
  final List<SmartActionItem> actions;

  const ParsedScanPayload({
    required this.type,
    required this.rawValue,
    required this.displayTitle,
    required this.displaySubtitle,
    required this.attributes,
    required this.actions,
  });
}

class SmartActionService {
  SmartActionService._([ScanService? scanService])
      : _scanService = scanService ?? ScanService.instance;

  factory SmartActionService.forTesting([ScanService? scanService]) {
    return SmartActionService._(scanService);
  }

  static final SmartActionService instance = SmartActionService._();

  final ScanService _scanService;

  /// Parses raw scan string into structured payload and contextual actions.
  ParsedScanPayload parse(String rawValue, [String? barcodeFormat]) {
    final trimmed = rawValue.trim();

    // 1. URL
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('www.')) {
      final url = trimmed.startsWith('www.') ? 'https://$trimmed' : trimmed;
      return ParsedScanPayload(
        type: SmartContentType.url,
        rawValue: rawValue,
        displayTitle: 'Tautan Web (URL)',
        displaySubtitle: url,
        attributes: {'URL': url},
        actions: [
          SmartActionItem(
            label: 'Buka di Browser',
            icon: Icons.open_in_browser,
            actionType: 'open_url',
            target: url,
            color: Colors.blue,
            isPrimary: true,
          ),
          SmartActionItem(
            label: 'Salin Tautan',
            icon: Icons.copy,
            actionType: 'copy',
            target: url,
          ),
        ],
      );
    }

    // 2. Wi-Fi URI (WIFI:S:MySSID;T:WPA;P:MyPassword;H:false;;)
    if (trimmed.startsWith('WIFI:')) {
      final attrs = <String, String>{};
      final content = trimmed.substring(5);
      final parts = content.split(';');

      String ssid = '';
      String password = '';
      String authType = 'WPA/WPA2';

      for (final p in parts) {
        if (p.startsWith('S:')) {
          ssid = p.substring(2);
          attrs['Nama Jaringan (SSID)'] = ssid;
        } else if (p.startsWith('P:')) {
          password = p.substring(2);
          attrs['Kata Sandi'] = password;
        } else if (p.startsWith('T:')) {
          authType = p.substring(2);
          attrs['Keamanan'] = authType;
        } else if (p.startsWith('H:')) {
          attrs['Jaringan Tersembunyi'] = p.substring(2) == 'true' ? 'Ya' : 'Tidak';
        }
      }

      final actions = <SmartActionItem>[];
      if (password.isNotEmpty) {
        actions.add(
          SmartActionItem(
            label: 'Salin Kata Sandi',
            icon: Icons.lock_open,
            actionType: 'copy_password',
            target: password,
            color: Colors.teal,
            isPrimary: true,
          ),
        );
      }
      if (ssid.isNotEmpty) {
        actions.add(
          SmartActionItem(
            label: 'Salin SSID',
            icon: Icons.wifi,
            actionType: 'copy_ssid',
            target: ssid,
          ),
        );
      }

      return ParsedScanPayload(
        type: SmartContentType.wifi,
        rawValue: rawValue,
        displayTitle: 'Jaringan Wi-Fi: $ssid',
        displaySubtitle: 'Keamanan: $authType',
        attributes: attrs,
        actions: actions,
      );
    }

    // 3. vCard Contact (BEGIN:VCARD...END:VCARD)
    if (trimmed.startsWith('BEGIN:VCARD')) {
      final attrs = <String, String>{};
      final lines = trimmed.split('\n');

      String name = '';
      String phone = '';
      String email = '';
      String org = '';

      for (final line in lines) {
        final l = line.trim();
        if (l.startsWith('FN:')) {
          name = l.substring(3);
          attrs['Nama Lengkap'] = name;
        } else if (l.startsWith('N:') && name.isEmpty) {
          name = l.substring(2).replaceAll(';', ' ').trim();
          attrs['Nama'] = name;
        } else if (l.startsWith('TEL')) {
          final idx = l.indexOf(':');
          if (idx != -1) {
            phone = l.substring(idx + 1);
            attrs['Nomor Telepon'] = phone;
          }
        } else if (l.startsWith('EMAIL')) {
          final idx = l.indexOf(':');
          if (idx != -1) {
            email = l.substring(idx + 1);
            attrs['Email'] = email;
          }
        } else if (l.startsWith('ORG:')) {
          org = l.substring(4);
          attrs['Organisasi/Perusahaan'] = org;
        }
      }

      final actions = <SmartActionItem>[];
      if (phone.isNotEmpty) {
        actions.add(
          SmartActionItem(
            label: 'Hubungi Telepon',
            icon: Icons.call,
            actionType: 'call',
            target: 'tel:$phone',
            color: Colors.green,
            isPrimary: true,
          ),
        );
        actions.add(
          SmartActionItem(
            label: 'Kirim SMS',
            icon: Icons.message,
            actionType: 'send_sms',
            target: 'sms:$phone',
          ),
        );
      }
      if (email.isNotEmpty) {
        actions.add(
          SmartActionItem(
            label: 'Kirim Email',
            icon: Icons.email,
            actionType: 'send_email',
            target: 'mailto:$email',
            color: Colors.blue,
          ),
        );
      }

      return ParsedScanPayload(
        type: SmartContentType.vcard,
        rawValue: rawValue,
        displayTitle: name.isNotEmpty ? 'Kontak: $name' : 'Kartu Kontak (vCard)',
        displaySubtitle: org.isNotEmpty ? org : (phone.isNotEmpty ? phone : email),
        attributes: attrs,
        actions: actions,
      );
    }

    // 4. Phone Number (tel:+628...)
    if (trimmed.startsWith('tel:')) {
      final phone = trimmed.substring(4);
      return ParsedScanPayload(
        type: SmartContentType.phone,
        rawValue: rawValue,
        displayTitle: 'Nomor Telepon',
        displaySubtitle: phone,
        attributes: {'Nomor': phone},
        actions: [
          SmartActionItem(
            label: 'Hubungi Nomor',
            icon: Icons.call,
            actionType: 'call',
            target: trimmed,
            color: Colors.green,
            isPrimary: true,
          ),
          SmartActionItem(
            label: 'Kirim SMS',
            icon: Icons.message,
            actionType: 'send_sms',
            target: 'sms:$phone',
          ),
          SmartActionItem(
            label: 'Salin Nomor',
            icon: Icons.copy,
            actionType: 'copy',
            target: phone,
          ),
        ],
      );
    }

    // 5. SMS (smsto:0812...:pesan atau sms:0812...)
    if (trimmed.startsWith('smsto:') || trimmed.startsWith('sms:')) {
      String phone = '';
      String message = '';
      if (trimmed.startsWith('smsto:')) {
        final rest = trimmed.substring(6);
        final idx = rest.indexOf(':');
        if (idx != -1) {
          phone = rest.substring(0, idx);
          message = rest.substring(idx + 1);
        } else {
          phone = rest;
        }
      } else {
        final uri = Uri.tryParse(trimmed);
        phone = uri?.path ?? '';
        message = uri?.queryParameters['body'] ?? '';
      }

      return ParsedScanPayload(
        type: SmartContentType.sms,
        rawValue: rawValue,
        displayTitle: 'Pesan SMS',
        displaySubtitle: 'Ke: $phone',
        attributes: {
          'Tujuan': phone,
          if (message.isNotEmpty) 'Isi Pesan': message,
        },
        actions: [
          SmartActionItem(
            label: 'Kirim SMS',
            icon: Icons.send,
            actionType: 'send_sms',
            target: 'sms:$phone${message.isNotEmpty ? '?body=${Uri.encodeComponent(message)}' : ''}',
            color: Colors.teal,
            isPrimary: true,
          ),
          SmartActionItem(
            label: 'Salin Nomor',
            icon: Icons.copy,
            actionType: 'copy',
            target: phone,
          ),
        ],
      );
    }

    // 6. Email (mailto:user@domain.com atau MATMSG:TO:...;)
    if (trimmed.startsWith('mailto:') || trimmed.startsWith('MATMSG:')) {
      String email = '';
      String subject = '';
      String body = '';

      if (trimmed.startsWith('mailto:')) {
        final uri = Uri.tryParse(trimmed);
        email = uri?.path ?? '';
        subject = uri?.queryParameters['subject'] ?? '';
        body = uri?.queryParameters['body'] ?? '';
      } else {
        // MATMSG:TO:user@example.com;SUB:Hello;BODY:World;;
        final parts = trimmed.substring(7).split(';');
        for (final p in parts) {
          if (p.startsWith('TO:')) email = p.substring(3);
          if (p.startsWith('SUB:')) subject = p.substring(4);
          if (p.startsWith('BODY:')) body = p.substring(5);
        }
      }

      final targetUri = 'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';

      return ParsedScanPayload(
        type: SmartContentType.email,
        rawValue: rawValue,
        displayTitle: 'Alamat Email',
        displaySubtitle: email,
        attributes: {
          'Penerima': email,
          if (subject.isNotEmpty) 'Subjek': subject,
          if (body.isNotEmpty) 'Isi Pesan': body,
        },
        actions: [
          SmartActionItem(
            label: 'Kirim Email',
            icon: Icons.email,
            actionType: 'send_email',
            target: targetUri,
            color: Colors.blue,
            isPrimary: true,
          ),
          SmartActionItem(
            label: 'Salin Email',
            icon: Icons.copy,
            actionType: 'copy',
            target: email,
          ),
        ],
      );
    }

    // 7. Geo Location (geo:-6.200000,106.816666)
    if (trimmed.startsWith('geo:')) {
      final coords = trimmed.substring(4).split('?').first;
      final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$coords';
      return ParsedScanPayload(
        type: SmartContentType.geo,
        rawValue: rawValue,
        displayTitle: 'Lokasi Geografis (GPS)',
        displaySubtitle: coords,
        attributes: {'Koordinat': coords},
        actions: [
          SmartActionItem(
            label: 'Buka di Google Maps',
            icon: Icons.map,
            actionType: 'open_map',
            target: mapUrl,
            color: Colors.redAccent,
            isPrimary: true,
          ),
          SmartActionItem(
            label: 'Salin Koordinat',
            icon: Icons.copy,
            actionType: 'copy',
            target: coords,
          ),
        ],
      );
    }

    // 8. Product Barcode (EAN-13, EAN-8, UPC, atau angka 8-14 digit)
    final isBarcode = (barcodeFormat != null &&
            (barcodeFormat.contains('EAN') ||
                barcodeFormat.contains('UPC') ||
                barcodeFormat.contains('128'))) ||
        RegExp(r'^\d{8,14}$').hasMatch(trimmed);

    if (isBarcode) {
      final searchUrl = 'https://www.google.com/search?q=$trimmed';
      return ParsedScanPayload(
        type: SmartContentType.product,
        rawValue: rawValue,
        displayTitle: 'Kode Produk / Barang',
        displaySubtitle: '${barcodeFormat ?? "BARCODE"}: $trimmed',
        attributes: {
          'Kode Barcode': trimmed,
          'Format': barcodeFormat ?? 'EAN/UPC',
        },
        actions: [
          SmartActionItem(
            label: 'Cari Produk di Google',
            icon: Icons.search,
            actionType: 'search_product',
            target: searchUrl,
            color: Colors.orange,
            isPrimary: true,
          ),
          SmartActionItem(
            label: 'Salin Barcode',
            icon: Icons.copy,
            actionType: 'copy',
            target: trimmed,
          ),
        ],
      );
    }

    // 9. Plain Text (Fallback)
    return ParsedScanPayload(
      type: SmartContentType.text,
      rawValue: rawValue,
      displayTitle: 'Teks Biasa',
      displaySubtitle: trimmed.length > 50 ? '${trimmed.substring(0, 50)}...' : trimmed,
      attributes: {'Panjang Karakter': '${trimmed.length}'},
      actions: [
        SmartActionItem(
          label: 'Salin Teks',
          icon: Icons.copy,
          actionType: 'copy',
          target: trimmed,
          isPrimary: true,
        ),
      ],
    );
  }

  /// Executes smart action item (launch external URL or copy to clipboard) and logs action to DB.
  Future<void> executeAction({
    required BuildContext context,
    required SmartActionItem action,
    String? scanId,
  }) async {
    // 1. Copy actions
    if (action.actionType.startsWith('copy')) {
      await Clipboard.setData(ClipboardData(text: action.target));
      if (scanId != null) {
        await _scanService.logAction(scanId: scanId, actionType: action.actionType);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${action.label} berhasil disalin ke clipboard!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 2. URL, Phone, SMS, Email, Maps, Search actions via url_launcher
    final uri = Uri.tryParse(action.target);
    if (uri == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target aksi tidak valid.')),
      );
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched && scanId != null) {
        await _scanService.logAction(scanId: scanId, actionType: action.actionType);
      } else if (!launched) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka aplikasi untuk aksi: ${action.label}')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menjalankan aksi: $e')),
      );
    }
  }
}
