import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  String? _error;
  
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _authService.isLoggedIn;
  User? get user => _authService.currentUser;
  String? get error => _error;
  AuthService get authService => _authService;

  Future<void> init() async {
    await _authService.init();
    notifyListeners();
  }

  Future<bool> sendMagicLink(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.sendMagicLink(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyToken(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.verifyMagicLink(token);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
