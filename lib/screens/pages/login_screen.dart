// screens/pages/login_screen.dart

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';

import 'home_admin.dart';
import 'home_pegawai.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _email = '';
  String _password = '';
  bool _loading = false;
  bool _obscurePassword = true;
  bool _skipFingerprintAuth = false;

  @override
  void initState() {
    super.initState();
    _loadSkipFingerprintPreference();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSkipFingerprintPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _skipFingerprintAuth = prefs.getBool('skipFingerprintAuth') ?? false;
    });
  }

  Future<void> _saveSkipFingerprintPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('skipFingerprintAuth', value);
  }

  Future<bool> _authenticateWithFingerprint() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        Fluttertoast.showToast(
          msg: 'Perangkat tidak mendukung biometrik',
          backgroundColor: Colors.orange,
          toastLength: Toast.LENGTH_LONG,
        );
        return false;
      }

      final List<BiometricType> availableBiometrics =
      await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        Fluttertoast.showToast(
          msg: 'Tidak ada biometrik yang terdaftar di perangkat',
          backgroundColor: Colors.orange,
          toastLength: Toast.LENGTH_LONG,
        );
        return false;
      }

      final bool authSuccess = await _localAuth.authenticate(
        localizedReason: 'Autentikasi sidik jari untuk login',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return authSuccess;
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Gagal melakukan autentikasi sidik jari: $e',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
      debugPrint('Fingerprint authentication error: $e');
      return false;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final user = await _auth.loginWithEmailPassword(_email.trim(), _password);

      if (user == null) {
        Fluttertoast.showToast(
          msg: 'Login gagal, periksa kembali email dan password',
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
        return;
      }

      final employeeData = await ApiService.getEmployeeDetailsFromPostgres(user.uid);

      if (employeeData == null) {
        Fluttertoast.showToast(
          msg: 'Data pengguna tidak ditemukan di database pegawai (PostgreSQL).',
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
        await _auth.logout();
        return;
      }

      if (employeeData['biometric_registered'] != true) {
        Fluttertoast.showToast(
          msg: 'Anda belum mendaftarkan autentikasi biometrik. Silakan hubungi admin.',
          backgroundColor: Colors.orange,
          toastLength: Toast.LENGTH_LONG,
        );
        await _auth.logout();
        return;
      }

      bool fingerprintSuccess = true;
      if (!_skipFingerprintAuth) {
        fingerprintSuccess = await _authenticateWithFingerprint();
      } else {
        Fluttertoast.showToast(
          msg: 'Autentikasi sidik jari dilewati.',
          backgroundColor: Theme.of(context).colorScheme.secondary,
          toastLength: Toast.LENGTH_SHORT,
        );
      }

      if (!fingerprintSuccess) {
        Fluttertoast.showToast(
          msg: 'Autentikasi sidik jari diperlukan untuk login',
          backgroundColor: Colors.red,
          toastLength: Toast.LENGTH_LONG,
        );
        await _auth.logout();
        return;
      }

      final String? jabatan = employeeData['jabatan'];
      String targetRole = 'pegawai';
      if (jabatan != null && jabatan.toLowerCase() == 'admin') {
        targetRole = 'admin';
      }
      final String userName = employeeData['nama_pengguna'] ?? 'User';

      Fluttertoast.showToast(
        msg: 'Login berhasil! Selamat datang, $userName',
        backgroundColor: Colors.green,
        toastLength: Toast.LENGTH_LONG,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => targetRole == 'admin'
              ? const HomeAdmin()
              : HomePegawai(userUid: user.uid, initialEmployeeData: employeeData),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login gagal';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Email tidak terdaftar';
          break;
        case 'wrong-password':
          errorMessage = 'Password salah';
          break;
        case 'invalid-email':
          errorMessage = 'Format email tidak valid';
          break;
        case 'user-disabled':
          errorMessage = 'Akun Anda telah dinonaktifkan';
          break;
        case 'too-many-requests':
          errorMessage = 'Terlalu banyak percobaan login. Coba lagi nanti';
          break;
        case 'network-request-failed':
          errorMessage = 'Gagal terhubung ke server. Periksa koneksi internet';
          break;
        case 'invalid-credential':
          errorMessage = 'Email atau password tidak valid';
          break;
        default:
          errorMessage = 'Login gagal: ${e.message}';
      }
      Fluttertoast.showToast(
        msg: errorMessage,
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Terjadi kesalahan tidak terduga: $e',
        backgroundColor: Colors.red,
        toastLength: Toast.LENGTH_LONG,
      );
      debugPrint('Unexpected login error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Lingkaran Dekoratif Top-Left
          Positioned(
            top: -(MediaQuery.of(context).size.width * 0.15),
            left: -(MediaQuery.of(context).size.width * 0.25),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.5,
              height: MediaQuery.of(context).size.width * 0.5,
              decoration: BoxDecoration(
                color: Colors.blue[500]!.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Lingkaran Dekoratif Bottom-Right
          Positioned(
            bottom: -(MediaQuery.of(context).size.width * 0.15),
            right: -(MediaQuery.of(context).size.width * 0.25),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.5,
              height: MediaQuery.of(context).size.width * 0.5,
              decoration: BoxDecoration(
                color: Colors.blue[500]!.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Konten Utama yang Dapat Di-scroll
          Positioned.fill(
            child: SafeArea(
              child: SingleChildScrollView(
                // Mengatur behavior untuk overscroll
                physics: const ClampingScrollPhysics(),
                // IntrinsicHeight masih bisa digunakan, tapi tidak menyelesaikan masalah Spacer
                // Kita bisa menghapusnya jika tidak ada alasan kuat untuk menggunakannya
                // Contoh: Column tidak perlu IntrinsicHeight jika tidak ada anak yang tingginya tergantung dari tinggi intrinsik anak lainnya
                // Tapi untuk saat ini, kita biarkan saja jika Anda memang menginginkannya.
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 7,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/mosip_logo.png',
                            height: 80,
                            width: 80,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.primary.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'MASUK',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Text(
                                      'DAFTAR',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.person),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onChanged: (val) => _email = val,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Email wajib diisi';
                                  }
                                  final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                                  if (!emailRegex.hasMatch(val.trim())) {
                                    return 'Format email tidak valid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: colorScheme.primary, width: 2),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onChanged: (val) => _password = val,
                                onFieldSubmitted: (_) => _login(),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Password wajib diisi';
                                  }
                                  if (val.length < 6) {
                                    return 'Password minimal 6 karakter';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Ini adalah SizedBox.shrink(). Tidak diperlukan lagi GestureDetector terpisah.
                                  const SizedBox.shrink(),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _skipFingerprintAuth,
                                        onChanged: (bool? newValue) {
                                          setState(() {
                                            _skipFingerprintAuth = newValue ?? false;
                                          });
                                          _saveSkipFingerprintPreference(_skipFingerprintAuth);
                                        },
                                        activeColor: colorScheme.primary,
                                      ),
                                      const Text(
                                        'Lewati Sidik Jari',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Fluttertoast.showToast(
                                      msg: 'Fitur reset password akan segera tersedia',
                                      backgroundColor: Colors.blue,
                                    );
                                  },
                                  child: const Text(
                                    'Lupa Password?',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                height: 50,
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: _loading
                                      ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: colorScheme.onPrimary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : const Text(
                                    'MASUK',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              // Hapus Spacer() dan ganti dengan SizedBox jika diperlukan
                              const SizedBox(height: 20), // Memberikan ruang di bagian bawah
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}