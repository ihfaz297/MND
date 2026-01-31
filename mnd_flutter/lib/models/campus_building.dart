class CampusBuilding {
  final String id;
  final String name;
  final String type;

  CampusBuilding({required this.id, required this.name, required this.type});

  factory CampusBuilding.fromJson(Map<String, dynamic> json) {
    return CampusBuilding(
      id: json['id'],
      name: json['name'],
      type: json['type'],
    );
  }
}
