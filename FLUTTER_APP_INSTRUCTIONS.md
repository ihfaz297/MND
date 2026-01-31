# MND Mobile App - Flutter Development Guide

**Project:** Student-Friendly Bus Routing App for SUST Campus  
**Backend API:** `http://192.168.31.119:3000/api` (or localhost:3000)  
**Target:** Android/iOS Students  
**Timeline:** MVP Launch with 5 core features

---

## 📋 Table of Contents
1. [Project Setup](#project-setup)
2. [Dependencies](#dependencies)
3. [Folder Structure](#folder-structure)
4. [API Integration](#api-integration)
5. [Feature Implementation](#feature-implementation)
6. [UI/UX Guidelines](#uiux-guidelines)
7. [State Management](#state-management)
8. [Testing & Deployment](#testing--deployment)

---

## 1. Project Setup

### Create Flutter Project
```bash
flutter create mnd_app
cd mnd_app
```

### Configuration

**pubspec.yaml** - Update SDK constraints:
```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
```

**AndroidManifest.xml** - Add internet permission:
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

**iOS Info.plist** - Add network permission:
```xml
<!-- ios/Runner/Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## 2. Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.1.1              # Simple state management
  
  # Networking
  http: ^1.1.0                  # HTTP requests
  dio: ^5.4.0                   # Advanced HTTP client (optional, use one)
  
  # Storage
  shared_preferences: ^2.2.2    # Local storage for auth tokens, favorites
  sqflite: ^2.3.0               # Local database (optional for offline)
  
  # UI Components
  google_fonts: ^6.1.0          # Custom fonts
  flutter_svg: ^2.0.9           # SVG support
  shimmer: ^3.0.0               # Loading animations
  
  # Maps (if implementing campus map)
  google_maps_flutter: ^2.5.0   # Optional for campus navigation
  
  # Utilities
  intl: ^0.18.1                 # Date/time formatting
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

Run:
```bash
flutter pub get
```

---

## 3. Folder Structure

```
lib/
├── main.dart
├── config/
│   ├── api_config.dart          # API URLs, constants
│   └── app_theme.dart           # Theme colors, styles
├── models/
│   ├── node.dart                # Location model
│   ├── route_option.dart        # Route result model
│   ├── route_leg.dart           # Route segment model
│   ├── favorite.dart            # Saved route model
│   ├── bus_schedule.dart        # Upcoming bus model
│   └── campus_building.dart     # Campus location model
├── services/
│   ├── api_service.dart         # Base API client
│   ├── auth_service.dart        # Authentication
│   ├── route_service.dart       # Route planning API
│   ├── favorite_service.dart    # Favorites API
│   ├── bus_service.dart         # Bus schedule API
│   └── campus_service.dart      # Campus navigation API
├── providers/
│   ├── auth_provider.dart       # User state
│   ├── route_provider.dart      # Route search state
│   └── favorite_provider.dart   # Favorites state
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/
│   │   └── home_screen.dart     # Main route search
│   ├── favorites/
│   │   └── favorites_screen.dart
│   ├── buses/
│   │   └── upcoming_buses_screen.dart
│   ├── campus/
│   │   └── campus_nav_screen.dart
│   └── profile/
│       └── profile_screen.dart
├── widgets/
│   ├── route_card.dart          # Route option display
│   ├── route_leg_item.dart      # Route segment display
│   ├── location_picker.dart     # From/To selector
│   └── custom_button.dart       # Reusable button
└── utils/
    ├── time_utils.dart          # Time parsing helpers
    └── constants.dart           # App constants
```

---

## 4. API Integration

### API Configuration

**lib/config/api_config.dart:**
```dart
class ApiConfig {
  // Change to your backend IP
  static const String baseUrl = 'http://192.168.31.119:3000/api';
  
  // For emulator testing (Android)
  // static const String baseUrl = 'http://10.0.2.2:3000/api';
  
  // For iOS simulator
  // static const String baseUrl = 'http://localhost:3000/api';
  
  static const Duration timeout = Duration(seconds: 30);
}
```

### Base API Service

**lib/services/api_service.dart:**
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  final http.Client _client = http.Client();
  
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? params}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint').replace(queryParameters: params);
    
    try {
      final response = await _client.get(uri).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to post data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
  
  Future<void> delete(String endpoint) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    
    try {
      final response = await _client.delete(uri).timeout(ApiConfig.timeout);
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
```

---

## 5. Feature Implementation

### Feature 1: Route Planning (Main Screen)

**lib/models/node.dart:**
```dart
class Node {
  final String id;
  final String name;
  final String type;

  Node({required this.id, required this.name, required this.type});

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'],
      name: json['name'],
      type: json['type'],
    );
  }
}
```

**lib/models/route_leg.dart:**
```dart
class RouteLeg {
  final String mode;
  final String from;
  final String to;
  final String? departure;
  final String? arrival;
  final int? durationMin;
  final int cost;
  final String? routeId;

  RouteLeg({
    required this.mode,
    required this.from,
    required this.to,
    this.departure,
    this.arrival,
    this.durationMin,
    required this.cost,
    this.routeId,
  });

  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    return RouteLeg(
      mode: json['mode'],
      from: json['from'],
      to: json['to'],
      departure: json['departure'],
      arrival: json['arrival'],
      durationMin: json['durationMin'],
      cost: json['cost'] ?? 0,
      routeId: json['route_id'],
    );
  }
}
```

**lib/models/route_option.dart:**
```dart
import 'route_leg.dart';

class RouteOption {
  final String label;
  final String category;
  final int totalTimeMin;
  final int totalCost;
  final int transfers;
  final int localTimeMin;
  final int localDistanceMeters;
  final List<RouteLeg> legs;

  RouteOption({
    required this.label,
    required this.category,
    required this.totalTimeMin,
    required this.totalCost,
    required this.transfers,
    required this.localTimeMin,
    required this.localDistanceMeters,
    required this.legs,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      label: json['label'],
      category: json['category'],
      totalTimeMin: json['totalTimeMin'],
      totalCost: json['totalCost'],
      transfers: json['transfers'],
      localTimeMin: json['localTimeMin'],
      localDistanceMeters: json['localDistanceMeters'],
      legs: (json['legs'] as List).map((leg) => RouteLeg.fromJson(leg)).toList(),
    );
  }
}
```

**lib/services/route_service.dart:**
```dart
import '../models/node.dart';
import '../models/route_option.dart';
import 'api_service.dart';

class RouteService {
  final ApiService _api = ApiService();

  Future<List<Node>> getNodes() async {
    final data = await _api.get('/nodes');
    return (data['nodes'] as List).map((node) => Node.fromJson(node)).toList();
  }

  Future<List<RouteOption>> planRoute({
    required String from,
    required String to,
    required String time,
  }) async {
    final data = await _api.get('/routes', params: {
      'from': from,
      'to': to,
      'time': time,
    });
    
    return (data['options'] as List)
        .map((option) => RouteOption.fromJson(option))
        .toList();
  }
}
```

**lib/screens/home/home_screen.dart:**
```dart
import 'package:flutter/material.dart';
import '../../models/node.dart';
import '../../models/route_option.dart';
import '../../services/route_service.dart';
import '../../widgets/route_card.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RouteService _routeService = RouteService();
  
  List<Node> _nodes = [];
  List<RouteOption> _routes = [];
  
  String? _fromNode;
  String? _toNode;
  String _time = '08:30';
  
  bool _loading = false;
  bool _loadingNodes = true;

  @override
  void initState() {
    super.initState();
    _loadNodes();
  }

  Future<void> _loadNodes() async {
    try {
      final nodes = await _routeService.getNodes();
      setState(() {
        _nodes = nodes;
        _loadingNodes = false;
      });
    } catch (e) {
      setState(() => _loadingNodes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load locations: $e')),
      );
    }
  }

  Future<void> _searchRoutes() async {
    if (_fromNode == null || _toNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select origin and destination')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _routes = [];
    });

    try {
      final routes = await _routeService.planRoute(
        from: _fromNode!,
        to: _toNode!,
        time: _time,
      );
      setState(() {
        _routes = routes;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to find routes: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MND - Route Planner'),
        elevation: 0,
      ),
      body: _loadingNodes
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Form
                Container(
                  padding: EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Column(
                    children: [
                      // From Dropdown
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'From',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _fromNode,
                        items: _nodes.map((node) {
                          return DropdownMenuItem(
                            value: node.id,
                            child: Text(node.name),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _fromNode = value),
                      ),
                      SizedBox(height: 12),
                      
                      // To Dropdown
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'To',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _toNode,
                        items: _nodes.map((node) {
                          return DropdownMenuItem(
                            value: node.id,
                            child: Text(node.name),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _toNode = value),
                      ),
                      SizedBox(height: 12),
                      
                      // Time Input
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Time (HH:MM)',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        initialValue: _time,
                        onChanged: (value) => setState(() => _time = value),
                      ),
                      SizedBox(height: 16),
                      
                      // Search Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _searchRoutes,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _loading
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('Find Routes', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Results
                Expanded(
                  child: _routes.isEmpty
                      ? Center(
                          child: Text(
                            _loading ? 'Searching...' : 'No routes found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _routes.length,
                          itemBuilder: (context, index) {
                            return RouteCard(route: _routes[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
```

**lib/widgets/route_card.dart:**
```dart
import 'package:flutter/material.dart';
import '../models/route_option.dart';

class RouteCard extends StatelessWidget {
  final RouteOption route;

  const RouteCard({required this.route});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  route.label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: route.category == 'fastest'
                        ? Colors.green.withOpacity(0.2)
                        : Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    route.category.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            
            // Stats
            Row(
              children: [
                _buildStat(Icons.access_time, '${route.totalTimeMin} min'),
                SizedBox(width: 16),
                _buildStat(Icons.currency_rupee, '৳${route.totalCost}'),
                SizedBox(width: 16),
                _buildStat(Icons.transfer_within_a_station, '${route.transfers}'),
              ],
            ),
            
            if (route.localTimeMin > 0) ...[
              SizedBox(height: 8),
              Text(
                'Includes ${route.localTimeMin} min walking/local',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            
            SizedBox(height: 12),
            Divider(),
            
            // Legs
            ...route.legs.map((leg) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    leg.mode == 'bus' ? Icons.directions_bus : Icons.directions_walk,
                    size: 20,
                    color: leg.mode == 'bus' ? Colors.blue : Colors.orange,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${leg.from} → ${leg.to}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  if (leg.departure != null)
                    Text(
                      '${leg.departure} - ${leg.arrival}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
```

---

### Feature 2: Saved Routes (Favorites)

**lib/models/favorite.dart:**
```dart
class Favorite {
  final String id;
  final String label;
  final String from;
  final String to;
  final String defaultTime;

  Favorite({
    required this.id,
    required this.label,
    required this.from,
    required this.to,
    required this.defaultTime,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'],
      label: json['label'],
      from: json['from'],
      to: json['to'],
      defaultTime: json['defaultTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'from': from,
      'to': to,
      'defaultTime': defaultTime,
    };
  }
}
```

**lib/services/favorite_service.dart:**
```dart
import '../models/favorite.dart';
import 'api_service.dart';

class FavoriteService {
  final ApiService _api = ApiService();

  Future<List<Favorite>> getFavorites() async {
    final data = await _api.get('/favorites');
    return (data['favorites'] as List)
        .map((fav) => Favorite.fromJson(fav))
        .toList();
  }

  Future<Favorite> addFavorite(Favorite favorite) async {
    final data = await _api.post('/favorites', favorite.toJson());
    return Favorite.fromJson(data);
  }

  Future<void> deleteFavorite(String id) async {
    await _api.delete('/favorites/$id');
  }
}
```

---

### Feature 3: Upcoming Buses

**lib/models/bus_schedule.dart:**
```dart
class BusSchedule {
  final String routeId;
  final String routeName;
  final String departure;
  final int minutesUntil;
  final String destination;

  BusSchedule({
    required this.routeId,
    required this.routeName,
    required this.departure,
    required this.minutesUntil,
    required this.destination,
  });

  factory BusSchedule.fromJson(Map<String, dynamic> json) {
    return BusSchedule(
      routeId: json['route_id'],
      routeName: json['route_name'],
      departure: json['departure'],
      minutesUntil: json['minutesUntil'],
      destination: json['destination'],
    );
  }
}
```

**lib/services/bus_service.dart:**
```dart
import '../models/bus_schedule.dart';
import 'api_service.dart';

class BusService {
  final ApiService _api = ApiService();

  Future<List<BusSchedule>> getUpcomingBuses(String from, {int limit = 5}) async {
    final data = await _api.get('/buses/upcoming', params: {
      'from': from,
      'limit': limit.toString(),
    });
    
    return (data['buses'] as List)
        .map((bus) => BusSchedule.fromJson(bus))
        .toList();
  }
}
```

---

### Feature 4: Authentication (Magic Links)

**lib/models/user.dart:**
```dart
class User {
  final String id;
  final String email;
  final String createdAt;
  final String? lastLogin;

  User({
    required this.id,
    required this.email,
    required this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      createdAt: json['createdAt'],
      lastLogin: json['lastLogin'],
    );
  }
}
```

**lib/services/auth_service.dart:**
```dart
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
```

**lib/providers/auth_provider.dart:**
```dart
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
```

**lib/screens/auth/login_screen.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _linkSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.sendMagicLink(email);
    
    if (success) {
      setState(() => _linkSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Magic link sent! Check your email.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Failed to send link'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter the token')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.verifyToken(token);
    
    if (success) {
      Navigator.of(context).pop(); // Return to previous screen
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Verification failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Icon(
                  Icons.directions_bus,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(height: 16),
                Text(
                  'MND Bus Router',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Sign in to save your favorite routes',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48),

                // Email Input
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'student@university.edu',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  enabled: !_linkSent,
                ),
                SizedBox(height: 16),

                // Send Link Button
                if (!_linkSent) ...[
                  ElevatedButton(
                    onPressed: auth.isLoading ? null : _sendMagicLink,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: auth.isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Send Magic Link', style: TextStyle(fontSize: 16)),
                  ),
                ],

                // Token Input (after link sent)
                if (_linkSent) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'Check your email!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'We sent a login link to ${_emailController.text}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  
                  Text(
                    'Or paste your token manually:',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  
                  TextField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      labelText: 'Token',
                      hintText: 'Paste token from email',
                      prefixIcon: Icon(Icons.key),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  ElevatedButton(
                    onPressed: auth.isLoading ? null : _verifyToken,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: auth.isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Verify & Login', style: TextStyle(fontSize: 16)),
                  ),
                  SizedBox(height: 16),
                  
                  TextButton(
                    onPressed: () => setState(() => _linkSent = false),
                    child: Text('Use a different email'),
                  ),
                ],

                SizedBox(height: 24),
                
                // Skip Button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Skip for now'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

---

### Feature 5: Complete Screens

**lib/screens/favorites/favorites_screen.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/favorite.dart';
import '../../providers/auth_provider.dart';
import '../../services/favorite_service.dart';
import '../auth/login_screen.dart';

class FavoritesScreen extends StatefulWidget {
  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoriteService _favoriteService = FavoriteService();
  List<Favorite> _favorites = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    if (!auth.isLoggedIn) {
      setState(() {
        _loading = false;
        _error = 'Please login to see your favorites';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final favorites = await _favoriteService.getFavorites();
      setState(() {
        _favorites = favorites;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteFavorite(Favorite favorite) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Favorite?'),
        content: Text('Remove "${favorite.label}" from favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _favoriteService.deleteFavorite(favorite.id);
        _loadFavorites();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Favorite removed')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Saved Routes'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: !auth.isLoggedIn
          ? _buildLoginPrompt()
          : _loading
              ? Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildError()
                  : _favorites.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Login to Save Routes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Save your frequent routes for quick access',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                ).then((_) => _loadFavorites());
              },
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red),
          SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadFavorites,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Saved Routes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Search for routes and tap the heart to save them',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _favorites.length,
        itemBuilder: (ctx, index) {
          final favorite = _favorites[index];
          return Card(
            margin: EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor,
                child: Icon(Icons.favorite, color: Colors.white),
              ),
              title: Text(
                favorite.label,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${favorite.from} → ${favorite.to}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    favorite.defaultTime,
                    style: TextStyle(color: Colors.grey),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteFavorite(favorite),
                  ),
                ],
              ),
              onTap: () {
                // TODO: Navigate to route search with pre-filled from/to
              },
            ),
          );
        },
      ),
    );
  }
}
```

**lib/screens/buses/upcoming_buses_screen.dart:**
```dart
import 'package:flutter/material.dart';
import '../../models/bus_schedule.dart';
import '../../models/node.dart';
import '../../services/bus_service.dart';
import '../../services/route_service.dart';

class UpcomingBusesScreen extends StatefulWidget {
  @override
  _UpcomingBusesScreenState createState() => _UpcomingBusesScreenState();
}

class _UpcomingBusesScreenState extends State<UpcomingBusesScreen> {
  final BusService _busService = BusService();
  final RouteService _routeService = RouteService();
  
  List<Node> _nodes = [];
  List<BusSchedule> _buses = [];
  String? _selectedStop;
  bool _loadingNodes = true;
  bool _loadingBuses = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNodes();
  }

  Future<void> _loadNodes() async {
    try {
      final nodes = await _routeService.getNodes();
      setState(() {
        _nodes = nodes;
        _loadingNodes = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingNodes = false;
      });
    }
  }

  Future<void> _loadBuses() async {
    if (_selectedStop == null) return;

    setState(() {
      _loadingBuses = true;
      _error = null;
    });

    try {
      final buses = await _busService.getUpcomingBuses(_selectedStop!, limit: 10);
      setState(() {
        _buses = buses;
        _loadingBuses = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingBuses = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'arriving':
        return Colors.green;
      case 'soon':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upcoming Buses'),
      ),
      body: _loadingNodes
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Stop Selector
                Container(
                  padding: EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Select Your Stop',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        value: _selectedStop,
                        items: _nodes.map((node) {
                          return DropdownMenuItem(
                            value: node.id,
                            child: Text(node.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedStop = value);
                          _loadBuses();
                        },
                      ),
                    ],
                  ),
                ),

                // Bus List
                Expanded(
                  child: _selectedStop == null
                      ? _buildSelectPrompt()
                      : _loadingBuses
                          ? Center(child: CircularProgressIndicator())
                          : _error != null
                              ? _buildError()
                              : _buses.isEmpty
                                  ? _buildNoBuses()
                                  : _buildBusList(),
                ),
              ],
            ),
    );
  }

  Widget _buildSelectPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Select a Stop',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Choose your location to see upcoming buses',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red),
          SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBuses,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBuses() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Buses Right Now',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Check back later or try a different stop',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBusList() {
    return RefreshIndicator(
      onRefresh: _loadBuses,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _buses.length,
        itemBuilder: (ctx, index) {
          final bus = _buses[index];
          final statusColor = _getStatusColor(
            bus.minutesUntil == 0 ? 'arriving' : bus.minutesUntil <= 5 ? 'soon' : 'scheduled'
          );

          return Card(
            margin: EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // Bus Icon & Time
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_bus, color: statusColor),
                        Text(
                          bus.minutesUntil == 0 ? 'NOW' : '${bus.minutesUntil}m',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),

                  // Route Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bus.routeName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'To: ${bus.destination}',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // Departure Time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        bus.departure,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bus.minutesUntil == 0 
                              ? 'Arriving' 
                              : bus.minutesUntil <= 5 
                                  ? 'Soon' 
                                  : 'Scheduled',
                          style: TextStyle(
                            fontSize: 10,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

**lib/screens/profile/profile_screen.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          if (!auth.isLoggedIn) {
            return _buildLoggedOut(context);
          }
          return _buildLoggedIn(context, auth);
        },
      ),
    );
  }

  Widget _buildLoggedOut(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, size: 100, color: Colors.grey),
            SizedBox(height: 24),
            Text(
              'Not Logged In',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Login to access your profile and saved routes',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                );
              },
              icon: Icon(Icons.login),
              label: Text('Login'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedIn(BuildContext context, AuthProvider auth) {
    final user = auth.user!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).primaryColor,
            child: Text(
              user.email[0].toUpperCase(),
              style: TextStyle(fontSize: 40, color: Colors.white),
            ),
          ),
          SizedBox(height: 16),

          // Email
          Text(
            user.email,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),

          // Member Since
          Text(
            'Member since ${_formatDate(user.createdAt)}',
            style: TextStyle(color: Colors.grey),
          ),
          
          SizedBox(height: 32),
          Divider(),
          SizedBox(height: 16),

          // Menu Items
          _buildMenuItem(
            context,
            icon: Icons.favorite,
            title: 'Saved Routes',
            subtitle: 'View your favorite routes',
            onTap: () {
              // Navigate to favorites tab
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.history,
            title: 'Recent Searches',
            subtitle: 'View your search history',
            onTap: () {},
          ),
          _buildMenuItem(
            context,
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Manage bus alerts',
            onTap: () {},
          ),
          _buildMenuItem(
            context,
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'App preferences',
            onTap: () {},
          ),

          SizedBox(height: 32),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Logout'),
                    content: Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await auth.logout();
                }
              },
              icon: Icon(Icons.logout, color: Colors.red),
              label: Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
      trailing: Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
```

---

### Feature 6: Main App with Bottom Navigation

**lib/main.dart (Complete):**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/favorites/favorites_screen.dart';
import 'screens/buses/upcoming_buses_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize auth
  final authProvider = AuthProvider();
  await authProvider.init();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MND - Student Bus Router',
      theme: AppTheme.lightTheme,
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    HomeScreen(),
    UpcomingBusesScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Routes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Buses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
```

---

### Updated API Service (Auth-aware)

**lib/services/api_service.dart (Updated):**
```dart
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
```

**lib/services/favorite_service.dart (Updated with Auth):**
```dart
import '../models/favorite.dart';
import 'api_service.dart';

class FavoriteService {
  final ApiService _api = ApiService();

  Future<List<Favorite>> getFavorites() async {
    final data = await _api.get('/favorites', requireAuth: true);
    return (data['favorites'] as List)
        .map((fav) => Favorite.fromJson(fav))
        .toList();
  }

  Future<Favorite> addFavorite(Favorite favorite) async {
    final data = await _api.post('/favorites', favorite.toJson(), requireAuth: true);
    return Favorite.fromJson(data['favorite']);
  }

  Future<void> deleteFavorite(String id) async {
    await _api.delete('/favorites/$id', requireAuth: true);
  }
}
```

### Design Principles
- **Student-friendly**: Simple, clear, colorful
- **Quick access**: Favorites on home screen
- **Offline-ready**: Cache last search, show message when offline
- **Cost-conscious**: Always show costs prominently

### Color Scheme (Suggestion)
```dart
// lib/config/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: Color(0xFF2196F3),      // Blue
    secondaryHeaderColor: Color(0xFF4CAF50), // Green
    scaffoldBackgroundColor: Color(0xFFF5F5F5),
    
    colorScheme: ColorScheme.light(
      primary: Color(0xFF2196F3),
      secondary: Color(0xFF4CAF50),
      error: Color(0xFFE53935),
    ),
    
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF2196F3),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
}
```

---

## 7. State Management

Use **Provider** for simplicity:

**lib/main.dart:**
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/route_provider.dart';
import 'screens/home/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RouteProvider()),
        // Add more providers as needed
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MND - Student Bus Router',
      theme: AppTheme.lightTheme,
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

---

## 8. Testing & Deployment

### Test on Device
```bash
# Connect Android device via USB or start emulator
flutter devices

# Run on device
flutter run

# For network testing, ensure device is on same WiFi as backend
```

### Build Release APK
```bash
# Build APK
flutter build apk --release

# APK location: build/app/outputs/flutter-apk/app-release.apk
```

### Backend Connection Issues?
- **Android Emulator**: Use `http://10.0.2.2:3000` instead of `localhost`
- **Physical Device**: Use your PC's IP `http://192.168.31.119:3000`
- **Check firewall**: Windows Defender might block connections

---

## 🚀 Quick Start Checklist

1. ✅ Create Flutter project
2. ✅ Add dependencies to pubspec.yaml
3. ✅ Set up folder structure
4. ✅ Configure API base URL in `api_config.dart`
5. ✅ Implement models (Node, RouteOption, RouteLeg)
6. ✅ Build API service layer
7. ✅ Create HomeScreen with route search
8. ✅ Test backend connectivity
9. ✅ Implement remaining features (Favorites, Buses, etc.)
10. ✅ Build and deploy

---

## 📞 Backend API Endpoints Reference

### ✅ Core Endpoints (Ready)
- `GET /api/health` - Health check & system status
- `GET /api/nodes` - All campus locations
- `GET /api/routes/list` - All available bus routes
- `GET /api/routes?from=X&to=Y&time=HH:MM` - Plan optimal route

### ✅ Authentication - Magic Links (Ready)
- `POST /api/auth/send-link` - Request magic login link via email
- `GET /api/auth/verify?token=xyz` - Verify magic link & auto-login
- `POST /api/auth/logout` - Logout and invalidate token
- `GET /api/profile` - Get authenticated user data

### ✅ User Favorites (Ready - Requires Auth)
- `POST /api/favorites` - Save a favorite route
- `GET /api/favorites` - Retrieve user's saved routes
- `PUT /api/favorites/:id` - Update favorite label/time
- `DELETE /api/favorites/:id` - Remove favorite route

### ✅ Real-Time Bus Information (Ready)
- `GET /api/buses/upcoming?from=X&limit=5` - Get next buses from location
- `GET /api/buses/schedule/:routeId` - Get full schedule for a route
- `GET /api/routes/:routeId` - Get detailed route information

### 🌐 Direct Google API Access

**For seamless data flow, the Flutter app can access Google services directly without backend routing:**
- **Google Maps API** - For campus map visualization & directions
- **Google Distance Matrix API** - For accurate travel time estimates
- **Google Places API** - For location autocomplete & building search

**Benefits:**
- Reduced backend load
- Faster app response times
- Real-time data accuracy
- Less API latency

**Implementation Note:** Configure API keys directly in Flutter app config. Backend can provide cached data as fallback.

---

## 🎯 MVP Feature Priority

**Phase 1 (Week 1):**
1. Route search (HomeScreen) ✅ Backend ready
2. Display route results with legs

**Phase 2 (Week 2):**
3. Saved routes (Favorites)
4. Upcoming buses schedule

**Phase 3 (Week 3):**
5. Campus navigation
6. Polish UI/UX

---

**Ready to code? Start with setting up the project and testing the existing `/api/routes` endpoint!**
