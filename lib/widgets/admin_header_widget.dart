
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AdminHeaderWidget extends StatefulWidget {
  const AdminHeaderWidget({super.key});

  @override
  State<AdminHeaderWidget> createState() => _AdminHeaderWidgetState();
}

class _AdminHeaderWidgetState extends State<AdminHeaderWidget> {
  // 1. State sekarang dikelola di dalam widget ini sendiri
  String? _userName;
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 2. Widget ini memanggil datanya sendiri saat pertama kali dibuat
    _loadHeaderData();
  }

  // 3. Logika untuk memuat data dipindahkan ke sini
  Future<void> _loadHeaderData() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getString('uid');

      if (currentUserId != null) {
        final userData = await ApiService.getEmployeeDetailsFromPostgres(currentUserId);
        if (mounted) { // Pastikan widget masih ada di tree
          setState(() {
            if (userData != null) {
              _userName = userData['nama_pengguna'] ?? 'Nama Tidak Tersedia';
              _userRole = userData['jabatan'] ?? 'Jabatan Tidak Tersedia';
            } else {
              _userName = 'Data Tidak Ditemukan';
              _userRole = 'Data Tidak Ditemukan';
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userName = 'Login Ulang';
            _userRole = 'Diperlukan';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = 'Error Memuat';
          _userRole = 'Data';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 4. Build method hanya mengembalikan UI untuk header
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      decoration: const BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [ BoxShadow( color: Colors.black26, blurRadius: 10, offset: Offset(0, 5), ), ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 40, color: Colors.blueAccent),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'Memuat...',
                  style: const TextStyle( color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _userRole ?? 'Memuat...',
                  style: TextStyle( color: Colors.white.withOpacity(0.8), fontSize: 14, ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}