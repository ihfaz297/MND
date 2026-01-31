class RouteLeg {
  final String mode;
  final String from;
  final String to;
  final String? departure;
  final String? arrival;
  final int? durationMin;
  final int cost;
  final String? routeId;

  RouteLeg({
    required this.mode,
    required this.from,
    required this.to,
    this.departure,
    this.arrival,
    this.durationMin,
    required this.cost,
    this.routeId,
  });

  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    return RouteLeg(
      mode: json['mode'],
      from: json['from'],
      to: json['to'],
      departure: json['departure'],
      arrival: json['arrival'],
      durationMin: json['durationMin'],
      cost: json['cost'] ?? 0,
      routeId: json['route_id'],
    );
  }
}
