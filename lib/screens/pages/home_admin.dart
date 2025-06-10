import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

import '../pages/login_screen.dart';
import '../admin/barcode_scanner.dart';
import '../admin/admin_leave_management_screen.dart';
import '../menu/log_activity.dart';

import '../../widgets/custom_bottom_nav_bar.dart';
import '../../widgets/admin_header_widget.dart'; // <- 1. Impor widget baru

class HomeAdmin extends StatefulWidget {
  const HomeAdmin({super.key});

  @override
  State<HomeAdmin> createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  // 2. Perhatikan, semua state untuk data user sudah dihapus, jadi lebih bersih
  final AuthService _auth = AuthService();
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // 3. Tidak ada lagi panggilan _loadUserData() di sini

    _pages = [
      _buildAdminDashboard(),
      const AdminLeaveManagementScreen(),
      const NotificationAdminPage(),
      const ProfileAdminPage(),
    ];
  }

  void _logout() async {
    await _auth.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Dashboard Admin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemTapped,
      ),
    );
  }

  // 4. Perhatikan betapa sederhananya fungsi ini sekarang
  Widget _buildAdminDashboard() {
    return Column(
      children: [
        // Cukup panggil widget header baru kita di sini
        const AdminHeaderWidget(),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 25.0, 16.0, 0),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.1,
              children: [
                _buildMenuItem( context, icon: Icons.qr_code_scanner, label: 'SCAN CHECK-IN', onTap: () { Navigator.push( context, MaterialPageRoute( builder: (context) => const BarcodeScannerPage(scanType: 'check_in')), ); }, ),
                _buildMenuItem( context, icon: Icons.qr_code_scanner, label: 'SCAN CHECK-OUT', onTap: () { Navigator.push( context, MaterialPageRoute( builder: (context) => const BarcodeScannerPage(scanType: 'check_out')), ); }, ),
                _buildMenuItem( context, icon: Icons.approval, label: 'APPROVAL', onTap: () { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Fitur Approval akan datang!')), ); }, ),
                _buildMenuItem( context, icon: Icons.summarize, label: 'REPORT', onTap: () { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Fitur Report akan datang!')), ); }, ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container( padding: const EdgeInsets.all(15), decoration: BoxDecoration( color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle, ), child: Icon(icon, size: 40, color: Colors.blueAccent), ),
            const SizedBox(height: 10),
            Text( label, textAlign: TextAlign.center, style: const TextStyle( fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, ), ),
          ],
        ),
      ),
    );
  }
}

// Placeholder pages (tetap sama)
class NotificationAdminPage extends StatelessWidget {
  const NotificationAdminPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Halaman Notifikasi Admin', style: TextStyle(fontSize: 24)),);
  }
}

class ProfileAdminPage extends StatelessWidget {
  const ProfileAdminPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Halaman Profil Admin', style: TextStyle(fontSize: 24)),);
  }
}