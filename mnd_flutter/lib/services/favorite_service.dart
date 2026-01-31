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
