class Profile {
  final String name;
  final String bio;
  final int points;
  final String avatar;

  Profile({
    required this.name,
    required this.bio,
    required this.points,
    required this.avatar,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    name: map['name'] ?? '',
    bio: map['bio'] ?? '',
    points: map['points'] ?? 0,
    avatar: map['avatar'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'bio': bio,
    'points': points,
    'avatar': avatar,
  };
}
