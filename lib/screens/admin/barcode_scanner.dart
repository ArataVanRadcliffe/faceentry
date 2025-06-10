import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Tetap diperlukan untuk Firebase Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Untuk mendapatkan UID admin yang login (jika diperlukan)

import '../../services/api_service.dart'; // Untuk berkomunikasi dengan backend Flask

class BarcodeScannerPage extends StatefulWidget {
  final String scanType; // 'check_in' atau 'check_out'
  const BarcodeScannerPage({super.key, required this.scanType});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessingScan = false;

  Future<void> _processScannedUid(String uid) async {
    if (_isProcessingScan) return;

    setState(() {
      _isProcessingScan = true;
    });

    try {
      // 1. Dapatkan nama pengguna untuk log (opsional, tapi bagus untuk konteks)
      String? employeeName;
      try {
        final employeeData = await ApiService.getEmployeeDetailsFromPostgres(uid);
        employeeName = employeeData?['nama_pengguna'];
      } catch (e) {
        debugPrint('Failed to fetch employee name for log: $e');
        // Lanjutkan saja meskipun nama pegawai tidak berhasil diambil, ini tidak kritikal
      }

      // 2. Kirim log ke backend Flask (PostgreSQL)
      await ApiService.addCheckInOutLog(
        uid: uid,
        eventType: widget.scanType, // Menggunakan tipe scan dari widget ('check_in' atau 'check_out')
        status: 'success_scan', // Status awal setelah berhasil dipindai oleh admin
        employeeName: employeeName,
        distance: null, // Tidak ada data jarak dari pemindaian barcode
      );

      Fluttertoast.showToast(msg: 'UID $uid (${widget.scanType}) berhasil discan dan dicatat!');
      debugPrint('UID $uid successfully sent to Flask log as ${widget.scanType}.');

      // --- NEW: Tambahkan logika untuk mengupdate Firebase Firestore ---
      // Ini adalah bagian yang akan mengirim sinyal ke aplikasi pegawai

      // Dapatkan UID admin yang sedang login untuk dicatat siapa yang melakukan scan
      String? adminUid = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance
          .collection('checkin_requests')
          .doc(uid) // Dokumen dengan ID = UID pegawai yang discan
          .set({
        'status': 'scanned', // Status yang akan didengarkan oleh aplikasi pegawai
        'timestamp': DateTime.now().millisecondsSinceEpoch, // Timestamp baru untuk memicu listener
        'event_type': widget.scanType, // Teruskan 'check_in' atau 'check_out'
        'admin_uid': adminUid, // Opsional: siapa admin yang melakukan scan
        'admin_name': FirebaseAuth.instance.currentUser?.displayName ?? 'Admin Tidak Dikenal', // Opsional
      }, SetOptions(merge: true)); // Gunakan merge agar tidak menimpa field lain

      Fluttertoast.showToast(msg: 'Sinyal ke pegawai berhasil dikirim via Firestore!');
      debugPrint('Firestore updated: status=scanned, timestamp=${DateTime.now().millisecondsSinceEpoch}, event_type=${widget.scanType} for UID: $uid');
      // --- AKHIR NEW ---

    } catch (e) {
      Fluttertoast.showToast(msg: 'Gagal memproses scan untuk UID $uid: $e');
      debugPrint('Error processing scanned UID: $e');
    } finally {
      setState(() {
        _isProcessingScan = false;
      });
      // Selalu kembali ke halaman sebelumnya setelah proses scan, terlepas dari sukses atau gagal
      // Anda mungkin ingin menampilkan pesan error lebih dulu jika proses update Firestore gagal
      cameraController.stop(); // Hentikan kamera setelah proses selesai
      if (!context.mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Barcode untuk ${widget.scanType == 'check_in' ? 'Check-In' : 'Check-Out'}'),
        centerTitle: true,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) async { // Tambahkan 'async' di sini
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  debugPrint('Barcode found! ${barcode.rawValue}');
                  if (barcode.rawValue != null && !_isProcessingScan) {
                    await _processScannedUid(barcode.rawValue!); // Panggil dengan await
                  }
                }
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: _isProcessingScan
                  ? const CircularProgressIndicator()
                  : Text(
                'Arahkan kamera ke Barcode karyawan untuk ${widget.scanType == 'check_in' ? 'Check-In' : 'Check-Out'}',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          )
        ],
      ),
    );
  }
}