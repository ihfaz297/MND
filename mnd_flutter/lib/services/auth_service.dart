import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  
  String? _authToken;
  User? _currentUser;

  String? get authToken => _authToken;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _authToken != null;

  /// Initialize auth state from local storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_tokenKey);
    
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      _currentUser = User.fromJson(json.decode(userData));
    }
  }

  /// Request magic link for email
  Future<Map<String, dynamic>> sendMagicLink(String email) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/send-link');
    
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Failed to send magic link');
    }
  }

  /// Verify magic link token and login
  Future<User> verifyMagicLink(String token) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/verify?token=$token');
    
    final response = await http.get(uri).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      _authToken = data['authToken'];
      _currentUser = User.fromJson(data['user']);
      
      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _authToken!);
      await prefs.setString(_userKey, json.encode(data['user']));
      
      return _currentUser!;
    } else {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Verification failed');
    }
  }

  /// Get current user profile
  Future<User> getProfile() async {
    if (_authToken == null) throw Exception('Not logged in');
    
    final uri = Uri.parse('${ApiConfig.baseUrl}/profile');
    
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_authToken'},
    ).timeout(ApiConfig.timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _currentUser = User.fromJson(data['user']);
      return _currentUser!;
    } else if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired');
    } else {
      throw Exception('Failed to get profile');
    }
  }

  /// Logout and clear local data
  Future<void> logout() async {
    if (_authToken != null) {
      try {
        final uri = Uri.parse('${ApiConfig.baseUrl}/auth/logout');
        await http.post(
          uri,
          headers: {'Authorization': 'Bearer $_authToken'},
        );
      } catch (_) {}
    }
    
    _authToken = null;
    _currentUser = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Get auth headers for API requests
  Map<String, String> get authHeaders {
    if (_authToken == null) return {};
    return {'Authorization': 'Bearer $_authToken'};
  }
}
