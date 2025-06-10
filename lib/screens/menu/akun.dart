// screens/menu/akun.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Digunakan untuk mendapatkan UID
import 'package:fluttertoast/fluttertoast.dart'; // Untuk notifikasi toast
import 'package:shared_preferences/shared_preferences.dart'; // Untuk mendapatkan UID dari prefs

import '../../services/auth_service.dart'; // Import AuthService Anda
import '../../services/api_service.dart'; // Import ApiService Anda
import '../pages/login_screen.dart'; // Import halaman login Anda

class AkunPage extends StatefulWidget {
  const AkunPage({super.key});

  @override
  State<AkunPage> createState() => _AkunPageState();
}

class _AkunPageState extends State<AkunPage> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _currentUid;

  // TextEditingController untuk input (jika diizinkan untuk diedit)
  final TextEditingController _namaPenggunaController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _kataSandiController = TextEditingController();
  final TextEditingController _konfirmasiKataSandiController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      _currentUid = await _authService.getUidFromPrefs(); // Ambil UID dari SharedPreferences
      debugPrint('AkunPage: UID dari SharedPreferences: $_currentUid');

      if (_currentUid != null) {
        final employeeData = await ApiService.getEmployeeDetailsFromPostgres(_currentUid!);
        debugPrint('AkunPage: Data pegawai dari API: $employeeData');

        if (mounted) {
          setState(() {
            _userData = employeeData;
            _namaPenggunaController.text = _userData?['nama_pengguna'] ?? 'Tidak Diketahui';
            _emailController.text = _userData?['email'] ?? 'Tidak Diketahui';
            _kataSandiController.text = '••••••••'; // Kata sandi tidak ditampilkan
            _konfirmasiKataSandiController.text = '••••••••'; // Kata sandi tidak ditampilkan
          });
        }
      } else {
        Fluttertoast.showToast(msg: 'UID tidak ditemukan. Mohon login ulang.');
        debugPrint('AkunPage: UID null, mengarahkan ke login.');
        _logout(); // Arahkan ke logout jika UID tidak ada
        return;
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Gagal memuat data pengguna: $e');
      debugPrint('AkunPage ERROR: Gagal memuat data pengguna: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    debugPrint('AkunPage: Melakukan logout...');
    try {
      await _authService.logout(); // Panggil fungsi logout dari AuthService
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()), // Kembali ke LoginScreen
              (route) => false, // Hapus semua route sebelumnya dari stack
        );
        Fluttertoast.showToast(msg: 'Anda telah berhasil logout.');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Gagal logout: $e');
      debugPrint('AkunPage ERROR: Gagal logout: $e');
    }
  }

  // Widget pembangun untuk setiap item informasi profil
  Widget _buildProfileInfoItem({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
    VoidCallback? onTap, // Tambahkan onTap untuk interaksi
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: GestureDetector( // Menggunakan GestureDetector agar bisa di-tap
        onTap: onTap,
        child: AbsorbPointer( // Mencegah keyboard muncul jika bukan untuk diedit
          absorbing: onTap != null, // Jika ada onTap, tidak bisa diedit secara langsung
          child: TextField(
            controller: controller,
            readOnly: onTap != null || controller == _kataSandiController || controller == _konfirmasiKataSandiController, // Set readOnly
            obscureText: obscureText,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: Colors.blueAccent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _namaPenggunaController.dispose();
    _emailController.dispose();
    _kataSandiController.dispose();
    _konfirmasiKataSandiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AKUN'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Kembali ke halaman sebelumnya (HomePegawai)
          },
        ),
        // Tidak perlu tombol logout di AppBar AkunPage jika sudah ada di HomePegawai
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Bagian Foto Profil (dari gambar referensi)
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blueAccent,
              backgroundImage: (_userData?['profile_photo_url'] != null && _userData!['profile_photo_url'].isNotEmpty)
                  ? NetworkImage(_userData!['profile_photo_url']) as ImageProvider<Object>?
                  : null,
              child: (_userData?['profile_photo_url'] == null || _userData!['profile_photo_url'].isEmpty)
                  ? const Icon(Icons.person, size: 80, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 20),
            // Item Informasi Profil
            _buildProfileInfoItem(
              label: 'Nama Pengguna',
              controller: _namaPenggunaController,
              icon: Icons.person,
              // onTap: () { /* TODO: Implementasi edit nama pengguna */ },
            ),
            _buildProfileInfoItem(
              label: 'Email',
              controller: _emailController,
              icon: Icons.email,
              // onTap: () { /* TODO: Implementasi edit email */ },
            ),
            _buildProfileInfoItem(
              label: 'Kata Sandi',
              controller: _kataSandiController,
              icon: Icons.lock,
              obscureText: true,
              onTap: () {
                // TODO: Implementasi navigasi ke halaman ubah kata sandi
                Fluttertoast.showToast(msg: 'Fitur ubah kata sandi belum diimplementasikan.');
              },
            ),
            _buildProfileInfoItem(
              label: 'Konfirmasi Kata Sandi',
              controller: _konfirmasiKataSandiController,
              icon: Icons.lock,
              obscureText: true,
              onTap: () {
                Fluttertoast.showToast(msg: 'Fitur ubah kata sandi belum diimplementasikan.');
              },
            ),
            _buildProfileInfoItem(
              label: 'Bahasa',
              controller: TextEditingController(text: 'Indonesia'), // Contoh hardcode bahasa
              icon: Icons.language,
              onTap: () {
                // TODO: Implementasi dialog atau halaman pilihan bahasa
                Fluttertoast.showToast(msg: 'Fitur pilihan bahasa belum diimplementasikan.');
              },
            ),
            // Tombol Keluar (Logout)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Keluar', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), // Lebar penuh
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: Colors.redAccent, // Warna merah untuk tombol keluar
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      // Bottom navigation bar akan ditangani oleh parent HomePegawai jika AkunPage diakses dari IndexedStack
      // Jika diakses via push, maka bottom nav bar tidak akan terlihat di halaman ini secara default.
      // Berdasarkan gambar referensi, bottom nav bar tetap ada, jadi AkunPage mungkin ada di IndexedStack.
      // Namun, instruksi terakhir adalah push ke AkunPage, jadi saya menganggap ini sebagai halaman terpisah.
      // Jika Anda ingin bottom nav bar tetap ada di AkunPage, Anda perlu menyertakan CustomBottomNavBar di sini juga.
      // Untuk saat ini, saya akan mengabaikan bottom nav bar di sini.
    );
  }
}