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
