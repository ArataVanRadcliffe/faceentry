// screens/pages/check_in.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:faceentry/screens/checkin/barcodecheckin.dart';
import 'package:faceentry/screens/checkin/facecheckin.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  String? _currentUid;
  String _checkInStatus = 'Memuat...';
  StreamSubscription<DocumentSnapshot>? _checkInRequestSubscription;

  bool _isNavigatingToFaceCheckIn = false;

  // NEW: Variabel untuk mengontrol tampilan tombol
  bool _showContinueButton = false;
  String _detectedEventType = 'check_in'; // Akan menyimpan event_type yang diterima dari admin

  @override
  void initState() {
    super.initState();
    debugPrint('CheckInPage initState: Memulai.');
    _getCurrentUserUid();
  }

  void _getCurrentUserUid() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUid = user.uid;
      debugPrint('CheckInPage: UID pengguna saat ini: $_currentUid');
      setState(() {
        _checkInStatus = 'UID ditemukan: ${_currentUid}. Menunggu Admin Scan.';
        _showContinueButton = false; // Pastikan tombol tersembunyi di awal
      });
      _listenForAdminSignal(user.uid);
    } else {
      Fluttertoast.showToast(msg: 'Anda harus login untuk melakukan check-in.');
      if (mounted) {
        setState(() {
          _checkInStatus = 'Error: Anda harus login.';
          _showContinueButton = false;
        });
      }
      debugPrint('CheckInPage: User tidak login, _currentUid null.');
    }
  }

  void _listenForAdminSignal(String uid) {
    _checkInRequestSubscription?.cancel();
    _checkInRequestSubscription = null;

    debugPrint('CheckInPage: Memulai mendengarkan sinyal admin untuk UID: $uid');

    FirebaseFirestore.instance.collection('checkin_requests').doc(uid).set({
      'status': 'waiting',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'user_name': FirebaseAuth.instance.currentUser?.displayName ?? 'Pengguna',
      'last_processed_timestamp': 0,
      'event_type': 'check_in', // Default ke check_in
    }, SetOptions(merge: true)).catchError((e) {
      debugPrint('CheckInPage ERROR: Gagal menginisialisasi dokumen Firestore: $e');
      Fluttertoast.showToast(msg: 'Gagal inisialisasi Firestore: $e');
    });

    _checkInRequestSubscription = FirebaseFirestore.instance
        .collection('checkin_requests')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) {
        debugPrint('CheckInPage: Widget tidak lagi mounted, mengabaikan sinyal Firestore.');
        return;
      }

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final String status = data['status'] ?? 'waiting';
        final int timestamp = data['timestamp'] ?? 0;
        final int lastProcessedTimestamp = data['last_processed_timestamp'] ?? 0;
        final String eventTypeFromAdmin = data['event_type'] ?? 'check_in'; // Default ke check_in

        debugPrint('CheckInPage Firestore Update: UID=$uid, status=$status, timestamp=$timestamp, last_processed_timestamp=$lastProcessedTimestamp, event_type_from_admin=$eventTypeFromAdmin');

        if (status == 'scanned' && timestamp > lastProcessedTimestamp) {
          debugPrint('CheckInPage: Sinyal "scanned" baru diterima! Timestamp: $timestamp > $lastProcessedTimestamp');
          setState(() {
            _checkInStatus = 'Barcode berhasil discan oleh Admin! Silakan Lanjutkan.';
            _showContinueButton = true; // Tampilkan tombol
            _detectedEventType = eventTypeFromAdmin; // Simpan eventType
          });

          // Penting: Update last_processed_timestamp di Firestore
          _updateProcessedTimestamp(uid, timestamp).then((_) {
            debugPrint('CheckInPage: last_processed_timestamp berhasil diupdate di Firestore.');
            // Tidak memicu navigasi otomatis di sini, hanya tampilkan tombol
          }).catchError((e) {
            debugPrint('CheckInPage ERROR: Gagal update last_processed_timestamp: $e');
            Fluttertoast.showToast(msg: 'Gagal memperbarui status proses di database.');
            if(mounted) setState(() => _showContinueButton = false); // Sembunyikan tombol jika ada error
          });
        } else if (status == 'waiting') {
          debugPrint('CheckInPage: Status direset menjadi waiting.');
          setState(() {
            _checkInStatus = 'Menunggu Admin Scan';
            _showContinueButton = false; // Sembunyikan tombol
          });
        } else if (status == 'scanned' && timestamp <= lastProcessedTimestamp) {
          debugPrint('CheckInPage: Sinyal "scanned" diterima tapi sudah diproses (timestamp tidak lebih baru).');
          setState(() {
            _checkInStatus = 'Barcode sudah discan dan sedang menunggu verifikasi wajah.';
            _showContinueButton = true; // Tetap tampilkan tombol jika sudah pernah discan
            _detectedEventType = eventTypeFromAdmin; // Perbarui eventType
          });
        }
      } else {
        debugPrint('CheckInPage: Dokumen checkin_requests/$uid tidak ada atau kosong, menginisialisasi ulang.');
        FirebaseFirestore.instance.collection('checkin_requests').doc(uid).set({
          'status': 'waiting',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'user_name': FirebaseAuth.instance.currentUser?.displayName ?? 'Pengguna',
          'last_processed_timestamp': 0,
          'event_type': 'check_in',
        }, SetOptions(merge: true)).catchError((e) {
          debugPrint('CheckInPage ERROR: Gagal inisialisasi ulang dokumen Firestore di else block: $e');
          Fluttertoast.showToast(msg: 'Gagal inisialisasi ulang Firestore: $e');
        });
        setState(() {
          _checkInStatus = 'Menunggu Admin Scan';
          _showContinueButton = false;
        });
      }
    }, onError: (error) {
      debugPrint('CheckInPage ERROR: Error listening for admin signal: $error');
      Fluttertoast.showToast(msg: 'Gagal mendengarkan sinyal admin: $error');
      if (mounted) {
        setState(() {
          _checkInStatus = 'Error mendengarkan sinyal: $error';
          _showContinueButton = false;
        });
      }
    });
  }

  Future<void> _updateProcessedTimestamp(String uid, int timestamp) async {
    try {
      await FirebaseFirestore.instance.collection('checkin_requests').doc(uid).set({
        'last_processed_timestamp': timestamp,
      }, SetOptions(merge: true));
      debugPrint('CheckInPage: last_processed_timestamp berhasil diperbarui untuk UID: $uid ke: $timestamp');
    } catch (e) {
      debugPrint('CheckInPage ERROR: Error updating processed timestamp in Firestore: $e');
    }
  }

  void _navigateToFaceCheckIn(String eventType) {
    debugPrint('CheckInPage: _navigateToFaceCheckIn dipanggil. Current _isNavigatingToFaceCheckIn: $_isNavigatingToFaceCheckIn');

    if (!mounted) {
      debugPrint('CheckInPage ERROR: _navigateToFaceCheckIn dipanggil saat widget tidak mounted. Aborting navigation.');
      return;
    }

    if (!_isNavigatingToFaceCheckIn) {
      debugPrint('CheckInPage: Memulai navigasi ke FaceCheckIn untuk UID: $_currentUid dengan eventType: $eventType.');

      _isNavigatingToFaceCheckIn = true; // Set flag di awal navigasi

      // Batalkan listener untuk mencegah update yang tidak perlu setelah navigasi
      _checkInRequestSubscription?.cancel();
      _checkInRequestSubscription = null;

      if (_currentUid != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => FaceCheckIn(
            uid: _currentUid!,
            eventType: eventType,
          )),
        ).then((_) {
          debugPrint('CheckInPage: Navigasi dari FaceCheckIn selesai, mereset flag.');
          _isNavigatingToFaceCheckIn = false;
          // Opsi: Jika ingin user bisa scan lagi setelah kembali dari FaceCheckIn
          // _listenForAdminSignal(_currentUid!);
        }).catchError((e) {
          debugPrint('CheckInPage ERROR: Navigator.pushReplacement failed: $e');
          Fluttertoast.showToast(msg: 'Gagal membuka layar verifikasi wajah: $e');
          _isNavigatingToFaceCheckIn = false; // Reset flag jika gagal navigasi
        });
      } else {
        Fluttertoast.showToast(msg: 'UID tidak tersedia untuk verifikasi wajah.');
        debugPrint('CheckInPage ERROR: _currentUid is null when trying to navigate to FaceCheckIn.');
        _isNavigatingToFaceCheckIn = false; // Reset flag jika gagal navigasi
      }
    } else {
      debugPrint('CheckInPage: Navigasi ke FaceCheckIn sudah dalam proses atau sudah terjadi, diabaikan (dari dalam _navigateToFaceCheckIn).');
    }
  }

  @override
  void dispose() {
    debugPrint('CheckInPage dispose: Membatalkan listener Firestore.');
    _checkInRequestSubscription?.cancel();
    _checkInRequestSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Check-In')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-In Karyawan'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Tunjukkan QR Code ini kepada Admin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: BarcodeCheckIn(uid: _currentUid!),
            ),
            const SizedBox(height: 30),
            Text(
              _checkInStatus,
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: _checkInStatus.contains('berhasil discan') ? Colors.green : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // NEW: Tombol "Lanjut Verifikasi Wajah" hanya muncul jika showContinueButton true
            if (_showContinueButton)
              ElevatedButton.icon(
                onPressed: () {
                  debugPrint('CheckInPage: Tombol "Lanjut Verifikasi Wajah" ditekan.');
                  _navigateToFaceCheckIn(_detectedEventType); // Memanggil fungsi navigasi
                },
                icon: const Icon(Icons.face),
                label: const Text('Lanjut Verifikasi Wajah'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            // Tombol Coba Lagi untuk error/loading
            if (_checkInStatus.contains('Error') || _checkInStatus.contains('Gagal'))
              ElevatedButton(
                onPressed: () {
                  debugPrint('CheckInPage: Tombol Coba Lagi ditekan.');
                  _isNavigatingToFaceCheckIn = false;
                  _showContinueButton = false; // Sembunyikan tombol lanjutan
                  _getCurrentUserUid();
                },
                child: const Text('Coba Lagi'),
              ),
            if (_checkInStatus.contains('Memuat') || _checkInStatus.contains('Menunggu Admin Scan'))
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}