class Node {
  final String id;
  final String name;
  final String type;

  Node({required this.id, required this.name, required this.type});

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'],
      name: json['name'],
      type: json['type'],
    );
  }
}
