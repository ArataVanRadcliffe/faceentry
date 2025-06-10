import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // <<< TAMBAH IMPORT INI
import 'dart:io'; // Untuk File (XFile)

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../pages/login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _auth = AuthService();
  Map<String, dynamic>? _employeeData;
  bool _isLoading = true;
  String? _currentUserId;
  final ImagePicker _picker = ImagePicker(); // <<< TAMBAH INI

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('uid');
      print('DEBUG (ProfilePage): UID retrieved from SharedPreferences: $_currentUserId');

      if (_currentUserId == null) {
        print('DEBUG (ProfilePage): No UID found in SharedPreferences. Logging out.');
        _logout();
        return;
      }

      final fetchedData = await ApiService.getEmployeeDetailsFromPostgres(_currentUserId!);
      print('DEBUG (ProfilePage): Raw employeeData from API: $fetchedData');

      if (fetchedData != null) {
        setState(() {
          _employeeData = fetchedData;
          _isLoading = false;
        });
        print('DEBUG (ProfilePage): Profile data loaded successfully.');
      } else {
        print('DEBUG (ProfilePage): Employee data not found for UID: $_currentUserId. Logging out.');
        setState(() {
          _employeeData = null;
          _isLoading = false;
        });
        _logout();
      }
    } catch (e) {
      print('DEBUG ERROR (ProfilePage): Error loading profile data: $e');
      setState(() {
        _isLoading = false;
        _employeeData = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data profil: $e')),
      );
      _logout();
    }
  }

  // --- MODIFIKASI: Metode untuk memilih dan mengunggah gambar profil ---
  Future<void> _pickAndUploadProfilePhoto() async {
    if (_currentUserId == null) {
      Fluttertoast.showToast(msg: 'UID tidak tersedia. Tidak bisa mengunggah foto.');
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80); // Atau ImageSource.camera
      if (image == null) {
        print('DEBUG (ProfilePage): Pemilihan gambar dibatalkan.');
        return;
      }

      setState(() {
        _isLoading = true; // Tampilkan loading saat mengunggah
      });

      final fileBytes = await image.readAsBytes();
      final String filename = image.name;

      print('DEBUG (ProfilePage): Attempting to upload photo for UID: $_currentUserId, filename: $filename');
      // Panggil ApiService untuk mengunggah foto
      await ApiService.uploadProfilePhoto( // Pastikan ApiService.uploadProfilePhoto ada
        uid: _currentUserId!,
        fileBytes: fileBytes,
        filename: filename,
      );

      // Setelah sukses upload, muat ulang data profil untuk mendapatkan URL terbaru
      await _loadProfileData(); // Memanggil ulang untuk mendapatkan URL yang baru dari DB
      Fluttertoast.showToast(msg: 'Foto profil berhasil diunggah!');
    } catch (e) {
      print('DEBUG ERROR (ProfilePage): Error picking or uploading image: $e');
      Fluttertoast.showToast(msg: 'Gagal mengunggah foto profil: $e');
      setState(() {
        _isLoading = false; // Hentikan loading jika ada error
      });
    }
  }
  // --- AKHIR MODIFIKASI ---

  void _logout() async {
    await _auth.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  String _calculateAge(String? tanggalLahirString) {
    if (tanggalLahirString == null || tanggalLahirString.isEmpty) {
      return 'Tidak tersedia';
    }
    try {
      final DateTime dob = DateTime.parse(tanggalLahirString);
      final DateTime now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return '$age Tahun';
    } catch (e) {
      return 'Tidak tersedia';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: const Color(0xFF4A90E2),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Text(
            'PROFILE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_employeeData == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: const Color(0xFF4A90E2),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Text(
            'PROFILE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Data Profil Tidak Ditemukan atau Gagal Dimuat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadProfileData,
                child: const Text('Muat Ulang Profil'),
              ),
            ],
          ),
        ),
      );
    }

    // Ambil URL foto profil dari data pegawai
    final String? profilePhotoUrl = _employeeData!['profile_photo_url'];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A90E2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Header Section with Profile Picture
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF4A90E2),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      // --- MODIFIKASI: Tampilkan NetworkImage jika profilePhotoUrl ada ---
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: const Color(0xFFF5F5F5),
                        backgroundImage: profilePhotoUrl != null && profilePhotoUrl.isNotEmpty
                            ? NetworkImage(profilePhotoUrl) as ImageProvider<Object>?
                            : null, // Jika ada URL, gunakan NetworkImage
                        child: profilePhotoUrl == null || profilePhotoUrl.isEmpty
                            ? const Icon( // Jika tidak ada URL, tampilkan ikon default
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        )
                            : null, // Jika ada URL, tidak tampilkan ikon
                      ),
                    ),
                    // --- MODIFIKASI: Tambahkan GestureDetector untuk edit foto ---
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadProfilePhoto, // Panggil metode upload
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4A90E2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    // --- AKHIR MODIFIKASI ---
                  ],
                ),
              ),
            ),
          ),

          // Profile Information Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileField('Nama Pengguna', _employeeData!['nama_pengguna'] ?? 'Tidak tersedia'),
                  const SizedBox(height: 16),
                  _buildProfileField('Usia', _employeeData!['usia']?.toString() ?? _calculateAge(_employeeData!['tanggal_lahir'])),
                  const SizedBox(height: 16),
                  _buildProfileField('Email', _employeeData!['email'] ?? 'Tidak tersedia', isEmail: true),
                  const SizedBox(height: 16),
                  _buildProfileField('Jabatan', _employeeData!['jabatan'] ?? 'Tidak tersedia'),
                  const SizedBox(height: 16),
                  _buildProfileField('ID Pegawai', _employeeData!['id_pegawai'] ?? 'Tidak tersedia'),
                  const SizedBox(height: 16),
                  _buildProfileField('Alamat', _employeeData!['alamat'] ?? 'Tidak tersedia'),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, String value, {bool isEmail = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isEmail ? Colors.blue[800] : Colors.black87,
              decoration: isEmail ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}