class BusSchedule {
  final String routeId;
  final String routeName;
  final String departure;
  final int minutesUntil;
  final String destination;

  BusSchedule({
    required this.routeId,
    required this.routeName,
    required this.departure,
    required this.minutesUntil,
    required this.destination,
  });

  factory BusSchedule.fromJson(Map<String, dynamic> json) {
    return BusSchedule(
      routeId: json['route_id'],
      routeName: json['route_name'],
      departure: json['departure'],
      minutesUntil: json['minutesUntil'],
      destination: json['destination'],
    );
  }
}
