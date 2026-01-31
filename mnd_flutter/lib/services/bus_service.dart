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
