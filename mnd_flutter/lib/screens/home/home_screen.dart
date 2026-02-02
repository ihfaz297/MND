import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/favorite.dart';
import '../../models/node.dart';
import '../../models/route_option.dart';
import '../../providers/auth_provider.dart';
import '../../services/favorite_service.dart';
import '../../services/route_service.dart';
import '../../widgets/route_card.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final RouteService _routeService = RouteService();
  final FavoriteService _favoriteService = FavoriteService();

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
      if (!mounted) return;
      setState(() {
        _nodes = nodes;
        _loadingNodes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingNodes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load locations: $e')),
      );
    }
  }

  Future<void> _searchRoutes() async {
    if (!_formKey.currentState!.validate()) {
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
      if (!mounted) return;
      setState(() {
        _routes = routes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to find routes: $e')),
      );
    }
  }

  Future<void> _addFavorite(RouteOption route) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      // Re-check login status after attempting login
      if (!mounted || !auth.isLoggedIn) return;
    }

    try {
      final favorite = Favorite(
        id: 'temp', // Server will assign ID
        label: route.label,
        from: _nodes.firstWhere((n) => n.id == _fromNode).name,
        to: _nodes.firstWhere((n) => n.id == _toNode).name,
        defaultTime: _time,
      );
      
      await _favoriteService.addFavorite(favorite);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${route.label}" to favorites'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              // TODO: Navigate to favorites screen
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add favorite: $e')),
      );
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(_time.split(':')[0]),
        minute: int.parse(_time.split(':')[1]),
      ),
    );
    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (!mounted) return;
      setState(() {
        _time = formattedTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MND - Route Planner'),
        elevation: 0,
      ),
      body: _loadingNodes
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Form
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withAlpha(25),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // From Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
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
                          validator: (value) => value == null ? 'Please select an origin' : null,
                        ),
                        const SizedBox(height: 12),
                        
                        // To Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
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
                          validator: (value) => value == null ? 'Please select a destination' : null,
                        ),
                        const SizedBox(height: 12),
                        
                        // Time Input
                        TextFormField(
                          readOnly: true,
                          controller: TextEditingController(text: _time),
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: Icon(Icons.access_time),
                          ),
                          onTap: _selectTime,
                        ),
                        const SizedBox(height: 16),
                        
                        // Search Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _searchRoutes,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Find Routes', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Results
                Expanded(
                  child: _routes.isEmpty
                      ? Center(
                          child: Text(
                            _loading ? 'Searching...' : 'No routes found',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _routes.length,
                          itemBuilder: (context, index) {
                            final route = _routes[index];
                            return RouteCard(
                              route: route,
                              onFavorite: auth.isLoggedIn ? () => _addFavorite(route) : null,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
