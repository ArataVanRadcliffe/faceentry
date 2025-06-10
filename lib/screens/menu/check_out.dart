import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

// Import ini akan diperlukan jika Anda ingin langsung logout jika UID tidak ditemukan
import '../pages/login_screen.dart';

class CheckOutPage extends StatefulWidget {
  const CheckOutPage({super.key});

  @override
  State<CheckOutPage> createState() => _CheckOutPageState();
}

class _CheckOutPageState extends State<CheckOutPage> {
  String? _userUid;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserUid();
  }

  Future<void> _loadUserUid() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');
    if (mounted) {
      setState(() {
        _userUid = uid;
        _isLoading = false;
      });
    }
    if (_userUid == null) {
      Fluttertoast.showToast(msg: 'UID pengguna tidak ditemukan. Silakan login ulang.');
      // Opsi: Arahkan ke halaman login jika tidak ada UID
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-Out Karyawan'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userUid == null
          ? const Center(
        child: Text(
          'Tidak dapat menampilkan Barcode. UID pengguna tidak tersedia.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.red),
        ),
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Pindai QR Code Ini untuk Check-Out',
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
              child: BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: _userUid!,
                width: 200,
                height: 200,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'UID Anda: $_userUid',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}