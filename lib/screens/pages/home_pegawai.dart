import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart'; // Tidak digunakan di sini, bisa dihapus jika tidak ada kebutuhan lain

import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

// Import halaman menu kamu (sesuaikan path)
import '../menu/check_in.dart';
import '../menu/check_out.dart';
import '../menu/log_activity.dart'; // Digunakan untuk navigasi langsung
import '../menu/profile.dart'; // Mungkin tidak lagi dipakai langsung, tapi biarkan dulu
import '../menu/akun.dart'; // NEW: Import AkunPage
import '../../widgets/custom_bottom_nav_bar.dart';
import '../menu/leave_screen.dart';

class HomePegawai extends StatefulWidget {
  final String? userUid;
  final Map<String, dynamic>? initialEmployeeData;

  const HomePegawai({super.key, this.userUid, this.initialEmployeeData});

  @override
  State<HomePegawai> createState() => _HomePegawaiState();
}

class _HomePegawaiState extends State<HomePegawai> {
  final AuthService _auth = AuthService();

  Map<String, dynamic>? _userData;
  bool _loadingUser = true;
  String? _currentUserId;

  // Daftar path aset untuk banner
  final List<String> _banners = const [
    'assets/banner/banner 1.png',
    'assets/banner/banner 2.png',
    'assets/banner/Banner 3.png',
  ];

  int _currentBottomNavIndex = 0;

  late final List<Widget> _pages; // Deklarasikan sebagai late final

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.userUid;

    if (widget.initialEmployeeData != null) {
      _userData = widget.initialEmployeeData;
      _loadingUser = false;
      print('DEBUG (HomePegawai): Initial user data provided from LoginScreen.');
      if (_currentUserId == null && _userData!['uid'] != null) {
        _currentUserId = _userData!['uid'];
      }
    } else {
      _loadUserData();
    }

    // --- MODIFIKASI: Daftar halaman untuk bottom navigation bar ---
    // Pages ini hanya untuk bottom nav bar. Menu grid akan pushReplacement
    _pages = [
      _buildHomePageContent(), // Indeks 0: Halaman utama (grid menu ada di sini)
      const LeaveScreen(),      // Indeks 1: Halaman Cuti (dipanggil dari bottom nav bar)
      const PlaceholderWidget(text: 'Halaman Notifikasi'),
      const AkunPage(),// Indeks 2: Halaman Notifikasi (contoh)
      // ProfilePage() atau AkunPage() TIDAK di sini jika diakses langsung dari grid
    ];
    // --- AKHIR MODIFIKASI ---
  }

  // Widget builder untuk konten utama HomePegawai
  Widget _buildHomePageContent() {
    final name = _userData?['nama_pengguna'] ?? 'User';
    final position = _userData?['jabatan'] ?? '-';
    final String? photoUrl = _userData?['profile_photo_url'];

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blueAccent,
          child: SafeArea( // Tambahkan SafeArea di sini agar tidak tumpang tindih dengan status bar
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white24,
                  backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl) as ImageProvider<Object>?
                      : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(position, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                // --- NEW FEATURE: Tombol Logout ---
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
                // --- AKHIR NEW FEATURE ---
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Carousel Slider
        CarouselSlider(
          options: CarouselOptions(
              height: 180,
              autoPlay: true,
              enlargeCenterPage: true,
              viewportFraction: 0.9,
              aspectRatio: 16 / 9,
              autoPlayInterval: const Duration(seconds: 5)),
          items: _banners.map((assetPath) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                assetPath,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('DEBUG: Error loading image $assetPath: $error');
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
                  );
                },
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        // === KOREKSI: Navigasi pada Grid Menu ===
        // Menggunakan Navigator.push untuk membuka halaman baru (bukan IndexedStack)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(), // Agar Grid tidak bisa discroll terpisah
              crossAxisCount: 2,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              children: [
                _buildFeatureCard(
                    icon: Icons.login,
                    label: 'CHECK-IN',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInPage()));
                    }),
                _buildFeatureCard(
                    icon: Icons.logout,
                    label: 'CHECK-OUT',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckOutPage()));
                    }),
                _buildFeatureCard(
                    icon: Icons.list_alt,
                    label: 'Log Activity',
                    onTap: () {
                      // --- KOREKSI: Arahkan ke LogActivityPage ---
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LogActivityPage()));
                    }),
                _buildFeatureCard(
                    icon: Icons.person,
                    label: 'Profile', // Mengubah label dari 'PROFILE' menjadi 'AKUN'
                    onTap: () {
                      // --- KOREKSI: Arahkan ke AkunPage ---
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                    }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Fungsi ini tetap sama
  Widget _buildFeatureCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: Colors.blueAccent),
                const SizedBox(height: 12),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Fungsi ini tetap sama
  Future<void> _loadUserData() async {
    setState(() {
      _loadingUser = true;
    });
    try {
      if (_currentUserId == null) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        _currentUserId = prefs.getString('uid');
        print('DEBUG (HomePegawai): UID retrieved from SharedPreferences: $_currentUserId');
      }

      if (_currentUserId == null) {
        print('DEBUG (HomePegawai): UID is null even after checking SharedPreferences, logging out.');
        _logout();
        return;
      }

      final employeeData = await ApiService.getEmployeeDetailsFromPostgres(_currentUserId!);
      print('DEBUG (HomePegawai): Raw employeeData from API: $employeeData');

      if (mounted) {
        setState(() {
          if (employeeData != null) {
            _userData = employeeData;
          } else {
            _userData = null;
            _logout();
          }
          _loadingUser = false;
        });
      }
    } catch (e) {
      print('DEBUG ERROR (HomePegawai): Error loading user data: $e');
      if (mounted) {
        setState(() {
          _loadingUser = false;
        });
        _logout();
      }
    }
  }

  // Fungsi _logout ini sudah ada, hanya perlu memastikan ia memanggil AuthService
  void _logout() async {
    print('DEBUG (HomePegawai): Attempting logout...');
    await _auth.logout(); // Memanggil metode logout dari AuthService
    if (!mounted) return;
    print('DEBUG (HomePegawai): Navigating to LoginScreen after logout.');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  // Fungsi ini tetap sama
  void _onBottomNavItemTapped(int index) {
    setState(() {
      _currentBottomNavIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: IndexedStack(
          index: _currentBottomNavIndex,
          children: _pages, // _pages sudah diinisialisasi di initState
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _currentBottomNavIndex,
        onItemSelected: _onBottomNavItemTapped,
      ),
    );
  }
}

// Widget PlaceholderWidget ini tidak berubah
class PlaceholderWidget extends StatelessWidget {
  final String text;
  const PlaceholderWidget({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}