import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected; // Callback saat item diklik

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  // Daftar ikon dan label untuk navigasi
  final List<Map<String, dynamic>> _navItems = const [
    {'icon': Icons.home, 'label': 'Home'},
    {'icon': Icons.calendar_today, 'label': 'Log'}, // Ganti ikon atau label sesuai kebutuhan
    {'icon': Icons.notifications, 'label': 'Notifikasi'},
    {'icon': Icons.settings, 'label': 'Profile'}, // Ganti ikon atau label sesuai kebutuhan
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70 + (MediaQuery.of(context).padding.bottom), // Tinggi dasar + padding bawah (safe area)
      decoration: BoxDecoration(
        color: Colors.blueAccent, // Warna latar belakang bar
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30), // Border radius di pojok kiri atas
          topRight: Radius.circular(30), // Border radius di pojok kanan atas
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, -3), // Shadow ke atas
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navItems.length, (index) {
          bool isSelected = index == widget.selectedIndex;
          // Tinggi "naik" saat dipilih
          double translateY = isSelected ? -15.0 : 0.0;
          double iconSize = isSelected ? 35.0 : 30.0; // Ukuran ikon saat dipilih
          Color iconColor = isSelected ? Colors.blueAccent : Colors.white; // Warna ikon saat dipilih

          return GestureDetector(
            onTap: () {
              widget.onItemSelected(index); // Panggil callback saat item diklik
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300), // Durasi animasi
              curve: Curves.easeInOut, // Jenis kurva animasi
              transform: Matrix4.translationValues(0, translateY, 0), // Efek naik
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: isSelected ? const EdgeInsets.all(8.0) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _navItems[index]['icon'],
                      color: iconColor,
                      size: iconSize,
                    ),
                  ),
                  // Jika Anda ingin label teks di bawah ikon (opsional)
                  // if (!isSelected) // Tampilkan label hanya jika tidak dipilih (seperti di gambar, tetapi tidak naik)
                  //   Text(
                  //     _navItems[index]['label'],
                  //     style: const TextStyle(color: Colors.white, fontSize: 12),
                  //   ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}