import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async => await _auth.canCheckBiometrics;

  Future<List<BiometricType>> getAvailableBiometrics() async =>
      await _auth.getAvailableBiometrics();

  Future<bool> authenticate({String reason = 'Autentikasi diperlukan'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('Error saat autentikasi biometrik: $e');
      return false;
    }
  }
}
