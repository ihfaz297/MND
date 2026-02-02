import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/route_option.dart';
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
  static const Color bus = Color(0xFF4285F4); // Google Blue
  static const Color local = Color(0xFFFF9800); // Orange
  static const Color walk = Color(0xFF4CAF50); // Green
  static const Color startMarker = Color(0xFF4CAF50);
  static const Color endMarker = Color(0xFFF44336);
}

class RouteMapScreen extends StatefulWidget {
  final RouteOption routeOption;

  const RouteMapScreen({
    super.key,
    required this.routeOption,
  });

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
      final List<_StopPosition> allStopPositions = [];
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
            allStopPositions.add(_StopPosition(
              position: directions.startLocation,
              nodeId: leg.from,
            ));
          }
          allStopPositions.add(_StopPosition(
            position: directions.endLocation,
            nodeId: leg.to,
          ));

          // Expand bounds
          if (totalBounds == null) {
            totalBounds = directions.bounds;
          } else {
            totalBounds = LatLngBounds(
              southwest: LatLng(
                totalBounds.southwest.latitude <
                        directions.bounds.southwest.latitude
                    ? totalBounds.southwest.latitude
                    : directions.bounds.southwest.latitude,
                totalBounds.southwest.longitude <
                        directions.bounds.southwest.longitude
                    ? totalBounds.southwest.longitude
                    : directions.bounds.southwest.longitude,
              ),
              northeast: LatLng(
                totalBounds.northeast.latitude >
                        directions.bounds.northeast.latitude
                    ? totalBounds.northeast.latitude
                    : directions.bounds.northeast.latitude,
                totalBounds.northeast.longitude >
                        directions.bounds.northeast.longitude
                    ? totalBounds.northeast.longitude
                    : directions.bounds.northeast.longitude,
              ),
            );
          }
        } else {
          print(
              'Failed to get directions for: $originAddress -> $destinationAddress');
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // Create markers
      final Set<Marker> markers = {};
      for (int i = 0; i < allStopPositions.length; i++) {
        final isStart = i == 0;
        final isEnd = i == allStopPositions.length - 1;
        final stop = allStopPositions[i];

        markers.add(
          Marker(
            markerId: MarkerId('stop_$i'),
            position: stop.position,
            icon: isStart
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
                : (isEnd
                    ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
                    : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)),
            infoWindow: InfoWindow(
              title: isStart ? 'Start' : (isEnd ? 'End' : 'Stop ${i + 1}'),
              snippet: stop.nodeId,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadRoutePolylines,
                      child: const Text('Retry'),
                    ),
                  ],
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

/// Helper class to store stop position with node ID
class _StopPosition {
  final LatLng position;
  final String nodeId;

  _StopPosition({required this.position, required this.nodeId});
}
