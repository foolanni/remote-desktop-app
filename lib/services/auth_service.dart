import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class AuthService extends ChangeNotifier {
  final _auth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _biometricEnabled = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get biometricEnabled => _biometricEnabled;

  Future<bool> checkBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      final available = await checkBiometricAvailable();
      if (!available || !_biometricEnabled) {
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }
      final result = await _auth.authenticate(
        localizedReason: '请验证身份以访问远程连接',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      _isAuthenticated = result;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Auth error: $e');
      _isAuthenticated = true; // 降级：认证失败时允许访问
      notifyListeners();
      return true;
    }
  }

  void setBiometricEnabled(bool enabled) {
    _biometricEnabled = enabled;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }
}
