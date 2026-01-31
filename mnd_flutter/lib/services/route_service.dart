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
