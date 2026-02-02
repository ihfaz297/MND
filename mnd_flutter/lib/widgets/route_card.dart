import 'package:flutter/material.dart';
import '../models/route_option.dart';
import '../screens/route_map/route_map_screen.dart';

class RouteCard extends StatelessWidget {
  final RouteOption route;
  final VoidCallback? onFavorite;

  const RouteCard({
    super.key,
    required this.route,
    this.onFavorite,
  });

  void _openRouteMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RouteMapScreen(routeOption: route),
      ),
    );
  }

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
                Expanded(
                  child: Text(
                    route.label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Map button
                IconButton(
                  icon: Icon(Icons.map_outlined, color: Colors.blue),
                  tooltip: 'View on Map',
                  onPressed: () => _openRouteMap(context),
                ),
                if (onFavorite != null)
                  IconButton(
                    icon: Icon(Icons.favorite_border),
                    onPressed: onFavorite,
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
                    color: leg.mode == 'bus' ? Colors.blue : Colors.orange,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${leg.from} → ${leg.to}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  if (leg.departure != null)
                    Text(
                      '${leg.departure} - ${leg.arrival}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
