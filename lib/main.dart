import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:faceentry/screens/pages/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Absensi Biometrik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue, // Ini akan memberikan palet biru standar.
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue)
            .copyWith(
          primary: Colors.blue[800], // sedikit lebih gelap untuk primary (agar teks putih terlihat bagus)
          secondary: Colors.blueAccent[700], // Warna aksen yang cerah
        ),
        useMaterial3: true, // Tetap gunakan Material 3
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const RegisterScreen(),
    );
  }
}