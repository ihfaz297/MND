# FINAL FEATURE: Route Map Visualization

## CLASSIFICATION: IMPLEMENTATION DIRECTIVE
## PRIORITY: CRITICAL
## TARGET: Gemini Agent (Android Studio)

---

## 1. EXECUTIVE SUMMARY

**Feature Name:** Route Map Visualization Screen

**Trigger:** User taps the favorite/view button on a `RouteCard` widget

**Behavior:** Navigate to a dedicated full-screen map page displaying the selected route with polylines, differentiated by transport mode (bus = blue, local/CNG = orange, walking = green)

**Exit:** Back button returns user to the previous screen (HomeScreen or FavoritesScreen)

---

## 2. FEATURE SPECIFICATION

### 2.1 User Flow
```
HomeScreen
    └── RouteCard (displays route summary)
            └── [User taps map/view button]
                    └── Navigator.push() → RouteMapScreen
                            └── Google Map with polylines
                            └── Route stops as markers
                            └── Statistics overlay (distance, duration)
                            └── [User taps back button]
                                    └── Navigator.pop() → HomeScreen
```

### 2.2 Visual Requirements

| Element | Specification |
|---------|---------------|
| Map Style | Dark mode (matching app theme) |
| Bus Route Polyline | Color: `#4285F4` (Google Blue), Weight: 6px, Opacity: 85% |
| Local/CNG Polyline | Color: `#FF9800` (Orange), Weight: 6px, Opacity: 85% |
| Walking Polyline | Color: `#4CAF50` (Green), Weight: 6px, Opacity: 85% |
| Start Marker | Green circle with "A" label |
| End Marker | Red circle with "B" label |
| Intermediate Stops | White circle markers, smaller size |
| Statistics Card | Floating card showing total distance + estimated duration |

---

## 3. TECHNICAL ARCHITECTURE

### 3.1 New Files to Create

```
lib/
├── screens/
│   └── route_map/
│       └── route_map_screen.dart    # NEW: Main map screen widget
├── services/
│   └── directions_service.dart      # NEW: Google Directions API client
├── widgets/
│   └── route_map_widgets.dart       # NEW: Map-related widgets (stats card, legend)
```

### 3.2 Files to Modify

```
lib/
├── widgets/
│   └── route_card.dart              # MODIFY: Add navigation to map screen
├── pubspec.yaml                     # MODIFY: Add google_maps_flutter dependency
├── config/
│   └── api_config.dart              # MODIFY: Add Google Directions API key config
```

### 3.3 Platform Configuration Required

**Android:** `android/app/src/main/AndroidManifest.xml`
**iOS:** `ios/Runner/AppDelegate.swift` and `ios/Runner/Info.plist`

---

## 4. IMPLEMENTATION INSTRUCTIONS

### 4.1 STEP 1: Add Dependencies

**File:** `pubspec.yaml`

Add under `dependencies:`:
```yaml
dependencies:
  # ... existing dependencies ...
  google_maps_flutter: ^2.5.0
  flutter_polyline_points: ^2.0.0
```

Run: `flutter pub get`

---

### 4.2 STEP 2: Configure API Key

**File:** `lib/config/api_config.dart`

Add a new constant for the Directions API key:
```dart
class ApiConfig {
  // ... existing code ...
  
  // Google Maps API Key (same key, ensure Directions API is enabled)
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
}
```

**CRITICAL:** The API key MUST have the following APIs enabled in Google Cloud Console:
- Maps SDK for Android
- Maps SDK for iOS
- Directions API

---

### 4.3 STEP 3: Android Platform Configuration

**File:** `android/app/src/main/AndroidManifest.xml`

Add inside `<application>` tag:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

Add permissions (if not present):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

---

### 4.4 STEP 4: iOS Platform Configuration

**File:** `ios/Runner/AppDelegate.swift`

Add import and API key:
```swift
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**File:** `ios/Runner/Info.plist`

Add:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to show your position on the map.</string>
```

---

### 4.5 STEP 5: Create Directions Service

**File:** `lib/services/directions_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config/api_config.dart';

class DirectionsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';

  /// Fetches directions between two addresses and returns polyline points
  /// 
  /// [origin] - Starting address (e.g., "Tilagor, Sylhet, Bangladesh")
  /// [destination] - Ending address (e.g., "Ambarkhana, Sylhet, Bangladesh")
  /// 
  /// Returns a DirectionsResult containing:
  /// - List of LatLng points for polyline
  /// - Total distance in meters
  /// - Total duration in seconds
  /// - Bounds for camera positioning
  static Future<DirectionsResult?> getDirections({
    required String origin,
    required String destination,
  }) async {
    final url = Uri.parse(
      '$_baseUrl?origin=${Uri.encodeComponent(origin)}'
      '&destination=${Uri.encodeComponent(destination)}'
      '&mode=driving'
      '&key=${ApiConfig.googleMapsApiKey}',
    );

    try {
      final response = await http.get(url);
      
      if (response.statusCode != 200) {
        print('Directions API error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      
      if (data['status'] != 'OK') {
        print('Directions API status: ${data['status']}');
        return null;
      }

      final route = data['routes'][0];
      final leg = route['legs'][0];
      
      // Decode polyline
      final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
      
      // Extract bounds
      final bounds = route['bounds'];
      final northeast = LatLng(
        bounds['northeast']['lat'].toDouble(),
        bounds['northeast']['lng'].toDouble(),
      );
      final southwest = LatLng(
        bounds['southwest']['lat'].toDouble(),
        bounds['southwest']['lng'].toDouble(),
      );

      return DirectionsResult(
        polylinePoints: polylinePoints,
        distanceMeters: leg['distance']['value'],
        distanceText: leg['distance']['text'],
        durationSeconds: leg['duration']['value'],
        durationText: leg['duration']['text'],
        startLocation: LatLng(
          leg['start_location']['lat'].toDouble(),
          leg['start_location']['lng'].toDouble(),
        ),
        endLocation: LatLng(
          leg['end_location']['lat'].toDouble(),
          leg['end_location']['lng'].toDouble(),
        ),
        bounds: LatLngBounds(southwest: southwest, northeast: northeast),
      );
    } catch (e) {
      print('Directions API exception: $e');
      return null;
    }
  }

  /// Decodes Google's encoded polyline format into LatLng points
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

/// Data class containing directions result
class DirectionsResult {
  final List<LatLng> polylinePoints;
  final int distanceMeters;
  final String distanceText;
  final int durationSeconds;
  final String durationText;
  final LatLng startLocation;
  final LatLng endLocation;
  final LatLngBounds bounds;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceMeters,
    required this.distanceText,
    required this.durationSeconds,
    required this.durationText,
    required this.startLocation,
    required this.endLocation,
    required this.bounds,
  });
}
```

---

### 4.6 STEP 6: Create Route Map Screen

**File:** `lib/screens/route_map/route_map_screen.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_option.dart';
import '../../models/route_leg.dart';
import '../../services/directions_service.dart';

/// Node address mapping - matches backend nodes.json
const Map<String, String> nodeAddresses = {
  'TILAGOR': 'Tilagor, Sylhet, Bangladesh',
  'SHIBGONJ': 'Shibgonj, Sylhet, Bangladesh',
  'NAIORPUL': 'Naiorpul, Sylhet, Bangladesh',
  'KUMARPARA': 'Kumarpara, Sylhet, Bangladesh',
  'SHAHI_EIDGAH': 'Shahi Eidgah, Sylhet, Bangladesh',
  'AMBARKHANA': 'Ambarkhana, Sylhet, Bangladesh',
  'SUBIDBAZAR': 'Subidbazar, Sylhet, Bangladesh',
  'PATHANTULA': 'Pathantula, Sylhet, Bangladesh',
  'MODINA_MARKET': 'Modina Market, Sylhet, Bangladesh',
  'CAMPUS': 'Shahjalal University of Science and Technology, Sylhet, Bangladesh',
  'CHOWHATTA': 'Chowhatta, Sylhet, Bangladesh',
  'JAIL_RD': 'Jail Road, Sylhet, Bangladesh',
  'NAYASARAK': 'Nayasarak, Sylhet, Bangladesh',
  'RIKABI_BAZAR': 'Rikabi Bazar, Sylhet, Bangladesh',
  'LAKKATURA': 'Lakkatura, Sylhet, Bangladesh',
  'SHEIKHGHAT': 'Sheikhghat, Sylhet, Bangladesh',
  'LAMABAZAR': 'Lamabazar, Sylhet, Bangladesh',
  'MEDICAL': 'Sylhet MAG Osmani Medical College Hospital, Sylhet, Bangladesh',
  'ZINDABAZAR': 'Zindabazar, Sylhet, Bangladesh',
};

/// Color constants for different transport modes
class RouteColors {
  static const Color bus = Color(0xFF4285F4);      // Google Blue
  static const Color local = Color(0xFFFF9800);    // Orange
  static const Color walk = Color(0xFF4CAF50);     // Green
  static const Color startMarker = Color(0xFF4CAF50);
  static const Color endMarker = Color(0xFFF44336);
  static const Color intermediateMarker = Colors.white;
}

class RouteMapScreen extends StatefulWidget {
  final RouteOption routeOption;

  const RouteMapScreen({
    Key? key,
    required this.routeOption,
  }) : super(key: key);

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  
  bool _isLoading = true;
  String? _errorMessage;
  
  int _totalDistanceMeters = 0;
  int _totalDurationSeconds = 0;

  // Initial camera position (Sylhet area)
  static const LatLng _sylhetCenter = LatLng(24.9178, 91.8320);

  @override
  void initState() {
    super.initState();
    _loadRoutePolylines();
  }

  /// Converts a node ID to its Google Maps address
  String _getNodeAddress(String nodeId) {
    return nodeAddresses[nodeId] ?? '$nodeId, Sylhet, Bangladesh';
  }

  /// Returns the appropriate color for a transport mode
  Color _getModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'bus':
        return RouteColors.bus;
      case 'local':
      case 'cng':
        return RouteColors.local;
      case 'walk':
      case 'walking':
        return RouteColors.walk;
      default:
        return RouteColors.bus;
    }
  }

  /// Main method to load all polylines for the route
  Future<void> _loadRoutePolylines() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<LatLng> allStopPositions = [];
      final List<String> allStopIds = [];
      final Set<Polyline> polylines = {};
      
      int polylineIdCounter = 0;
      LatLngBounds? totalBounds;

      // Process each leg of the route
      for (final leg in widget.routeOption.legs) {
        final color = _getModeColor(leg.mode);
        
        // Get the origin and destination addresses for this leg
        final originAddress = _getNodeAddress(leg.from);
        final destinationAddress = _getNodeAddress(leg.to);

        // Fetch directions from Google API
        final directions = await DirectionsService.getDirections(
          origin: originAddress,
          destination: destinationAddress,
        );

        if (directions != null) {
          // Add polyline for this leg
          polylines.add(
            Polyline(
              polylineId: PolylineId('leg_$polylineIdCounter'),
              points: directions.polylinePoints,
              color: color,
              width: 6,
              patterns: leg.mode.toLowerCase() == 'walk' 
                  ? [PatternItem.dot, PatternItem.gap(10)] 
                  : [],
            ),
          );
          
          polylineIdCounter++;
          
          // Track total distance and duration
          _totalDistanceMeters += directions.distanceMeters;
          _totalDurationSeconds += directions.durationSeconds;
          
          // Track positions for markers
          if (allStopPositions.isEmpty) {
            allStopPositions.add(directions.startLocation);
            allStopIds.add(leg.from);
          }
          allStopPositions.add(directions.endLocation);
          allStopIds.add(leg.to);
          
          // Expand bounds
          if (totalBounds == null) {
            totalBounds = directions.bounds;
          } else {
            totalBounds = LatLngBounds(
              southwest: LatLng(
                totalBounds.southwest.latitude < directions.bounds.southwest.latitude
                    ? totalBounds.southwest.latitude
                    : directions.bounds.southwest.latitude,
                totalBounds.southwest.longitude < directions.bounds.southwest.longitude
                    ? totalBounds.southwest.longitude
                    : directions.bounds.southwest.longitude,
              ),
              northeast: LatLng(
                totalBounds.northeast.latitude > directions.bounds.northeast.latitude
                    ? totalBounds.northeast.latitude
                    : directions.bounds.northeast.latitude,
                totalBounds.northeast.longitude > directions.bounds.northeast.longitude
                    ? totalBounds.northeast.longitude
                    : directions.bounds.northeast.longitude,
              ),
            );
          }
        } else {
          print('Failed to get directions for: $originAddress -> $destinationAddress');
        }
        
        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // Create markers
      final Set<Marker> markers = {};
      for (int i = 0; i < allStopPositions.length; i++) {
        final isStart = i == 0;
        final isEnd = i == allStopPositions.length - 1;
        final stopId = allStopIds[i];
        
        markers.add(
          Marker(
            markerId: MarkerId('stop_$i'),
            position: allStopPositions[i],
            icon: await _createMarkerIcon(isStart, isEnd),
            infoWindow: InfoWindow(
              title: isStart ? 'Start' : (isEnd ? 'End' : 'Stop ${i + 1}'),
              snippet: stopId,
            ),
          ),
        );
      }

      setState(() {
        _polylines = polylines;
        _markers = markers;
        _isLoading = false;
      });

      // Animate camera to fit bounds
      if (totalBounds != null) {
        final controller = await _mapController.future;
        controller.animateCamera(
          CameraUpdate.newLatLngBounds(totalBounds, 60),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load route: $e';
      });
    }
  }

  /// Creates a custom marker icon based on position in route
  Future<BitmapDescriptor> _createMarkerIcon(bool isStart, bool isEnd) async {
    if (isStart) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    } else if (isEnd) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  /// Formats duration in seconds to human-readable string
  String _formatDuration(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m';
    } else {
      return '${seconds ~/ 60} min';
    }
  }

  /// Formats distance in meters to human-readable string
  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    } else {
      return '$meters m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routeOption.label),
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _sylhetCenter,
              zoom: 12,
            ),
            onMapCreated: (controller) {
              _mapController.complete(controller);
              // Apply dark map style
              controller.setMapStyle(_darkMapStyle);
            },
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
          ),
          
          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading route...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          
          // Error message
          if (_errorMessage != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          
          // Statistics card (bottom)
          if (!_isLoading && _errorMessage == null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildStatsCard(),
            ),
          
          // Legend (top right)
          if (!_isLoading && _errorMessage == null)
            Positioned(
              top: 16,
              right: 16,
              child: _buildLegend(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 8,
      color: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.straighten,
              value: _formatDistance(_totalDistanceMeters),
              label: 'Distance',
            ),
            Container(
              height: 40,
              width: 1,
              color: Colors.grey.shade700,
            ),
            _buildStatItem(
              icon: Icons.access_time,
              value: _formatDuration(_totalDurationSeconds),
              label: 'Duration',
            ),
            Container(
              height: 40,
              width: 1,
              color: Colors.grey.shade700,
            ),
            _buildStatItem(
              icon: Icons.swap_horiz,
              value: '${widget.routeOption.transfers}',
              label: 'Transfers',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.cyan, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Card(
      elevation: 8,
      color: Colors.grey.shade900.withOpacity(0.9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Legend',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _buildLegendItem(RouteColors.bus, 'Bus'),
            _buildLegendItem(RouteColors.local, 'Local/CNG'),
            _buildLegendItem(RouteColors.walk, 'Walking'),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Dark map style JSON
  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
    {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
    {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
    {"featureType": "poi", "elementType": "labels", "stylers": [{"visibility": "off"}]}
  ]
  ''';
}
```

---

### 4.7 STEP 7: Modify RouteCard Widget

**File:** `lib/widgets/route_card.dart`

**LOCATE** the existing button/icon that triggers the favorite action or add a new "View Map" button.

**ADD** the following import at the top:
```dart
import '../screens/route_map/route_map_screen.dart';
```

**ADD** a method or modify the existing onTap handler to navigate:
```dart
void _openRouteMap(BuildContext context, RouteOption routeOption) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => RouteMapScreen(routeOption: routeOption),
    ),
  );
}
```

**EXAMPLE** button widget to add inside the RouteCard:
```dart
IconButton(
  icon: const Icon(Icons.map_outlined),
  tooltip: 'View on Map',
  onPressed: () => _openRouteMap(context, routeOption),
)
```

---

## 5. DATA FLOW DIAGRAM

```
┌─────────────────────────────────────────────────────────────────────┐
│                          RouteCard Widget                           │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │  RouteOption {                                               │   │
│  │    label: "Fastest Route"                                    │   │
│  │    legs: [                                                   │   │
│  │      RouteLeg { from: "TILAGOR", to: "AMBARKHANA", mode: "bus" }  │
│  │      RouteLeg { from: "AMBARKHANA", to: "CAMPUS", mode: "bus" }   │
│  │    ]                                                         │   │
│  │  }                                                           │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│                    [User taps Map button]                           │
│                              │                                      │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Navigator.push()                               │
│              RouteMapScreen(routeOption: routeOption)               │
└──────────────────────────────┼──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       RouteMapScreen                                │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  _loadRoutePolylines()                                        │  │
│  │                                                               │  │
│  │  FOR EACH leg IN routeOption.legs:                           │  │
│  │    │                                                         │  │
│  │    ▼                                                         │  │
│  │  ┌─────────────────────────────────────────────────────────┐ │  │
│  │  │  originAddress = nodeAddresses[leg.from]                │ │  │
│  │  │  destAddress = nodeAddresses[leg.to]                    │ │  │
│  │  │                                                         │ │  │
│  │  │  DirectionsService.getDirections(                       │ │  │
│  │  │    origin: "Tilagor, Sylhet, Bangladesh",              │ │  │
│  │  │    destination: "Ambarkhana, Sylhet, Bangladesh"       │ │  │
│  │  │  )                                                      │ │  │
│  │  └────────────────────────┬────────────────────────────────┘ │  │
│  │                           │                                   │  │
│  │                           ▼                                   │  │
│  │  ┌─────────────────────────────────────────────────────────┐ │  │
│  │  │  Google Directions API                                  │ │  │
│  │  │  GET /maps/api/directions/json                         │ │  │
│  │  │    ?origin=Tilagor,Sylhet,Bangladesh                   │ │  │
│  │  │    &destination=Ambarkhana,Sylhet,Bangladesh           │ │  │
│  │  │    &mode=driving                                        │ │  │
│  │  │    &key=API_KEY                                         │ │  │
│  │  └────────────────────────┬────────────────────────────────┘ │  │
│  │                           │                                   │  │
│  │                           ▼                                   │  │
│  │  ┌─────────────────────────────────────────────────────────┐ │  │
│  │  │  RESPONSE:                                              │ │  │
│  │  │  {                                                      │ │  │
│  │  │    routes: [{                                           │ │  │
│  │  │      overview_polyline: { points: "encoded_string" }   │ │  │
│  │  │      bounds: { northeast: {...}, southwest: {...} }    │ │  │
│  │  │      legs: [{ distance: {...}, duration: {...} }]      │ │  │
│  │  │    }]                                                   │ │  │
│  │  │  }                                                      │ │  │
│  │  └────────────────────────┬────────────────────────────────┘ │  │
│  │                           │                                   │  │
│  │                           ▼                                   │  │
│  │  ┌─────────────────────────────────────────────────────────┐ │  │
│  │  │  _decodePolyline(encoded_string)                        │ │  │
│  │  │  → List<LatLng> points                                  │ │  │
│  │  │                                                         │ │  │
│  │  │  Create Polyline(                                       │ │  │
│  │  │    points: points,                                      │ │  │
│  │  │    color: _getModeColor(leg.mode), // blue/orange/green │ │  │
│  │  │    width: 6                                             │ │  │
│  │  │  )                                                      │ │  │
│  │  └─────────────────────────────────────────────────────────┘ │  │
│  │                                                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    GoogleMap Widget                           │  │
│  │  ┌────────────────────────────────────────────────────────┐  │  │
│  │  │  polylines: { Polyline1, Polyline2, ... }              │  │  │
│  │  │  markers: { StartMarker(green), EndMarker(red), ... }  │  │  │
│  │  └────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 6. NODE ADDRESS MAPPING REFERENCE

**CRITICAL:** These addresses MUST match the backend `nodes.json` file exactly.

| Node ID | Google Maps Address |
|---------|---------------------|
| `TILAGOR` | Tilagor, Sylhet, Bangladesh |
| `SHIBGONJ` | Shibgonj, Sylhet, Bangladesh |
| `NAIORPUL` | Naiorpul, Sylhet, Bangladesh |
| `KUMARPARA` | Kumarpara, Sylhet, Bangladesh |
| `SHAHI_EIDGAH` | Shahi Eidgah, Sylhet, Bangladesh |
| `AMBARKHANA` | Ambarkhana, Sylhet, Bangladesh |
| `SUBIDBAZAR` | Subidbazar, Sylhet, Bangladesh |
| `PATHANTULA` | Pathantula, Sylhet, Bangladesh |
| `MODINA_MARKET` | Modina Market, Sylhet, Bangladesh |
| `CAMPUS` | Shahjalal University of Science and Technology, Sylhet, Bangladesh |
| `CHOWHATTA` | Chowhatta, Sylhet, Bangladesh |
| `JAIL_RD` | Jail Road, Sylhet, Bangladesh |
| `NAYASARAK` | Nayasarak, Sylhet, Bangladesh |
| `RIKABI_BAZAR` | Rikabi Bazar, Sylhet, Bangladesh |
| `LAKKATURA` | Lakkatura, Sylhet, Bangladesh |
| `SHEIKHGHAT` | Sheikhghat, Sylhet, Bangladesh |
| `LAMABAZAR` | Lamabazar, Sylhet, Bangladesh |
| `MEDICAL` | Sylhet MAG Osmani Medical College Hospital, Sylhet, Bangladesh |
| `ZINDABAZAR` | Zindabazar, Sylhet, Bangladesh |

---

## 7. COLOR CODING SPECIFICATION

```dart
// Transport Mode → Polyline Color Mapping
switch (leg.mode.toLowerCase()) {
  case 'bus':
    return Color(0xFF4285F4);  // #4285F4 - Google Blue
  case 'local':
  case 'cng':
    return Color(0xFFFF9800);  // #FF9800 - Orange
  case 'walk':
  case 'walking':
    return Color(0xFF4CAF50);  // #4CAF50 - Green
  default:
    return Color(0xFF4285F4);  // Default to bus color
}
```

---

## 8. ERROR HANDLING REQUIREMENTS

1. **API Key Missing/Invalid**
   - Display error message: "Map service unavailable. Please check API configuration."
   - Log error to console for debugging

2. **Network Error**
   - Display error message: "Unable to load route. Check internet connection."
   - Provide retry button

3. **Directions API Returns No Results**
   - Log which segment failed
   - Continue drawing remaining segments
   - Display partial route with warning

4. **Rate Limiting**
   - Implement 150ms delay between consecutive API calls
   - If 429 error received, implement exponential backoff

---

## 9. TESTING CHECKLIST

- [ ] Map loads with dark theme
- [ ] Bus route polyline renders in blue (#4285F4)
- [ ] Local/CNG route polyline renders in orange (#FF9800)
- [ ] Walking route polyline renders in green (#4CAF50) with dotted pattern
- [ ] Start marker is green
- [ ] End marker is red
- [ ] Intermediate stop markers are visible
- [ ] Statistics card shows correct distance and duration
- [ ] Legend displays correctly
- [ ] Back button returns to previous screen
- [ ] Camera automatically fits all polylines in view
- [ ] Multi-leg routes with different modes show distinct colors
- [ ] Loading indicator appears while fetching directions
- [ ] Error messages display appropriately on failure

---

## 10. REFERENCE IMPLEMENTATION

A working HTML/JavaScript prototype demonstrating this exact functionality exists at:

**File:** `/workspaces/MND/test_directions_polyline.html`

This file demonstrates:
- Google Directions API integration
- Polyline decoding and rendering
- Multi-mode color coding
- Marker placement
- Statistics calculation

Use this as a visual reference for the expected behavior.

---

## 11. EXECUTION ORDER

1. ✅ Add dependencies to `pubspec.yaml`
2. ✅ Run `flutter pub get`
3. ✅ Configure Android `AndroidManifest.xml`
4. ✅ Configure iOS `AppDelegate.swift` and `Info.plist`
5. ✅ Add API key to `api_config.dart`
6. ✅ Create `directions_service.dart`
7. ✅ Create `route_map_screen.dart`
8. ✅ Modify `route_card.dart` to add map navigation button
9. ✅ Test on Android emulator/device
10. ✅ Test on iOS simulator/device (if applicable)

---

## END OF DIRECTIVE

**Classification:** IMPLEMENTATION COMPLETE
**Verification:** Test all checklist items before marking feature as done
