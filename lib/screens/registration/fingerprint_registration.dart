// screens/registration/fingerprint_registration.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart'; // TAMBAHKAN INI

import '../../services/firestore_service.dart';
import '../../services/api_service.dart';
import '../pages/home_admin.dart';
import '../pages/home_pegawai.dart';
import 'dart:typed_data'; // Tambahkan untuk Uint8List

class FingerprintRegistration extends StatefulWidget {
  final String uid; // Masih akan kosong/null di sini, akan didapatkan setelah Firebase Auth
  final String role;
  final String name;
  final String email;
  final String idUser;
  final String password; // TAMBAHKAN INI
  final String? jabatan;
  final String? tanggalLahir;
  final int? usia;
  final String? alamat;
  final Uint8List? faceImageBytes; // TAMBAHKAN INI UNTUK GAMBAR WAJAH

  const FingerprintRegistration({
    Key? key,
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    required this.idUser,
    required this.password, // TAMBAHKAN INI
    this.jabatan,
    this.tanggalLahir,
    this.usia,
    this.alamat,
    this.faceImageBytes, // TAMBAHKAN INI
  }) : super(key: key);

  @override
  State<FingerprintRegistration> createState() => _FingerprintRegistrationState();
}

class _FingerprintRegistrationState extends State<FingerprintRegistration> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirestoreService _db = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance; // Inisialisasi Firebase Auth

  bool _loading = false;

  Future<bool> _authenticateFingerprint() async {
    try {
      if (!await _localAuth.canCheckBiometrics) {
        Fluttertoast.showToast(msg: 'Perangkat tidak mendukung biometrik');
        return false;
      }

      final bioList = await _localAuth.getAvailableBiometrics();
      if (bioList.isEmpty) {
        Fluttertoast.showToast(msg: 'Tidak ada metode biometrik yang tersedia');
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: 'Autentikasi sidik jari untuk pendaftaran',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on Exception catch (e) { // Tangkap Exception, bukan hanya Error
      Fluttertoast.showToast(msg: 'Gagal melakukan autentikasi sidik jari');
      debugPrint('Error fingerprint auth: $e');
      return false;
    }
  }

  Future<void> _registerFingerprint() async {
    setState(() => _loading = true);
    try {
      final success = await _authenticateFingerprint();
      if (!success) {
        Fluttertoast.showToast(msg: 'Autentikasi fingerprint gagal');
        setState(() => _loading = false);
        return;
      }

      // --- TAHAP KRUSIAL: REGISTRASI FIREBASE AUTH DAN KE API/POSTGRESQL ---
      // 1. Daftar ke Firebase Authentication
      debugPrint('Attempting Firebase Auth registration...');
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: widget.email.trim(),
        password: widget.password.trim(),
      );
      String? uid = userCredential.user?.uid;

      if (uid == null) {
        throw Exception("Failed to get UID from Firebase after registration.");
      }
      debugPrint('Firebase Auth successful, UID: $uid');

      // 2. Kirim SEMUA data profil LENGKAP + gambar wajah ke API/PostgreSQL
      debugPrint('Attempting to register full employee data to backend...');
      await ApiService.registerEmployeeData(
        uid: uid,
        name: widget.name,
        idUser: widget.idUser,
        role: widget.role,
        email: widget.email,
        password: widget.password, // Kirim password juga jika backend membutuhkannya (meskipun Firebase sudah menghandle)
        jabatan: widget.jabatan,
        tanggalLahir: widget.tanggalLahir,
        usia: widget.usia,
        alamat: widget.alamat,
        faceImageBytes: widget.faceImageBytes, // GAMBAR WAJAH DIKIRIM DI SINI!
      );
      debugPrint('Employee data and face image registered to backend.');

      // 3. Update status biometricRegistered di Firestore
      debugPrint('Updating Firestore with biometric registration status...');
      await _db.saveUserData(uid, { // Gunakan UID yang valid
        'biometricRegistered': true,
        'biometricRegistrationDate': DateTime.now().toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        // Anda juga bisa menyimpan data profil lain di Firestore jika diinginkan
        // 'nama_pengguna': widget.name, 'email': widget.email, ...
      });
      debugPrint('Firestore updated successfully.');

      Fluttertoast.showToast(msg: 'Fingerprint dan data berhasil didaftarkan');

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
          widget.role == 'admin' ? const HomeAdmin() : const HomePegawai(),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Email ini sudah terdaftar di Firebase.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password terlalu lemah.';
      } else {
        errorMessage = 'Registrasi Firebase gagal: ${e.message}';
      }
      Fluttertoast.showToast(msg: errorMessage, backgroundColor: Colors.red);
      debugPrint('Firebase Auth registration error: $e');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Terjadi kesalahan saat registrasi: $e', backgroundColor: Colors.red);
      debugPrint('Fingerprint or final registration error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrasi Fingerprint'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fingerprint, size: 100, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                'Daftarkan Sidik Jari Anda',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                onPressed: _registerFingerprint,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Mulai Registrasi Fingerprint'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}