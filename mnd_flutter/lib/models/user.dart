class User {
  final String id;
  final String email;
  final String createdAt;
  final String? lastLogin;

  User({
    required this.id,
    required this.email,
    required this.createdAt,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      createdAt: json['createdAt'],
      lastLogin: json['lastLogin'],
    );
  }
}
