class Favorite {
  final String id;
  final String label;
  final String from;
  final String to;
  final String defaultTime;

  Favorite({
    required this.id,
    required this.label,
    required this.from,
    required this.to,
    required this.defaultTime,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'],
      label: json['label'],
      from: json['from'],
      to: json['to'],
      defaultTime: json['defaultTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'from': from,
      'to': to,
      'defaultTime': defaultTime,
    };
  }
}
