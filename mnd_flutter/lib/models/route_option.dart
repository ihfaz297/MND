import 'route_leg.dart';

class RouteOption {
  final String label;
  final String category;
  final int totalTimeMin;
  final int totalCost;
  final int transfers;
  final int localTimeMin;
  final int localDistanceMeters;
  final List<RouteLeg> legs;

  RouteOption({
    required this.label,
    required this.category,
    required this.totalTimeMin,
    required this.totalCost,
    required this.transfers,
    required this.localTimeMin,
    required this.localDistanceMeters,
    required this.legs,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      label: json['label'],
      category: json['category'],
      totalTimeMin: json['totalTimeMin'],
      totalCost: json['totalCost'],
      transfers: json['transfers'],
      localTimeMin: json['localTimeMin'],
      localDistanceMeters: json['localDistanceMeters'],
      legs: (json['legs'] as List).map((leg) => RouteLeg.fromJson(leg)).toList(),
    );
  }
}
