// screens/checkin/barcodecheckin.dart

import '../menu/check_in.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Pastikan package ini terinstal (di pubspec.yaml)

class BarcodeCheckIn extends StatelessWidget {
  final String uid;

  const BarcodeCheckIn({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        QrImageView(
          data: uid, // Data yang akan di-encode ke QR Code adalah UID
          version: QrVersions.auto,
          size: 200.0,
          gapless: false,
        ),
        const SizedBox(height: 10),
        Text(
          'UID Anda: $uid',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}