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
