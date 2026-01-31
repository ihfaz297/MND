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
