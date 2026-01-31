import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  final http.Client _client = http.Client();
  
  /// Get auth token from storage
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Build headers with optional auth
  Future<Map<String, String>> _buildHeaders({bool requireAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    final token = await _getAuthToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else if (requireAuth) {
      throw Exception('Authentication required');
    }
    
    return headers;
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? params,
    bool requireAuth = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint')
        .replace(queryParameters: params);
    
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.get(uri, headers: headers)
          .timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Request failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool requireAuth = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.post(
        uri,
        headers: headers,
        body: json.encode(body),
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Request failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  Future<void> delete(String endpoint, {bool requireAuth = true}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    
    try {
      final headers = await _buildHeaders(requireAuth: requireAuth);
      final response = await _client.delete(uri, headers: headers)
          .timeout(ApiConfig.timeout);
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        if (response.statusCode == 401) {
          throw Exception('Session expired. Please login again.');
        }
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Delete failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
