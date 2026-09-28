class ProfileModel {
  const ProfileModel({
    required this.name,
    required this.email,
    this.phone,
    this.dateOfBirth,
    this.photoPath,
  });

  factory ProfileModel.fake() => const ProfileModel(name: 'Demo User', email: 'demo@example.com', phone: '');

  final String name;
  final String email;
  final String? phone;
  final DateTime? dateOfBirth;

  /// A local file path -- this template's fake backend never returns a
  /// remote photo URL, so there's no need for cached_network_image.
  final String? photoPath;

  ProfileModel copyWith({
    String? name,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    String? photoPath,
  }) =>
      ProfileModel(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        photoPath: photoPath ?? this.photoPath,
      );
}
