import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<User?> loginWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // --- FIX: Simpan UID ke SharedPreferences setelah login berhasil ---
      if (userCredential.user != null) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('uid', userCredential.user!.uid);
        print('DEBUG (AuthService): UID ${userCredential.user!.uid} saved to SharedPreferences.');
      }
      // --- AKHIR FIX ---

      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('General Login Error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('uid'); // Hapus UID saat logout
    await _firebaseAuth.signOut();
    print('DEBUG (AuthService): UID removed from SharedPreferences. User logged out.');
  }

  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  Future<String?> getUidFromPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('uid');
  }
}