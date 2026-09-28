class User {
  const User({required this.id, required this.name, required this.email, required this.token});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        token: json['token'] as String,
      );

  factory User.fake({String? name, String? email}) => User(
        id: 'demo-user-1',
        name: name ?? 'Demo User',
        email: email ?? 'demo@example.com',
        token: 'fake-token-${DateTime.now().millisecondsSinceEpoch}',
      );

  final String id;
  final String name;
  final String email;
  final String token;

  User copyWith({String? name, String? email}) => User(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        token: token,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'token': token};
}
