# MND Mobile App - Flutter Development Guide

**Project:** Student-Friendly Bus Routing App for SUST Campus  
**Backend API:** `http://192.168.31.219:3000/api` (or localhost:3000)  
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
  static const String baseUrl = 'http://192.168.31.219:3000/api';
  
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
                    color: leg.mode == 'bus' ? Colors.blue : Col
