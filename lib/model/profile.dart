class Profile {
  final String name;
  final String bio;
  final int points;
  final String avatarUrl;

  Profile({
    required this.name,
    required this.bio,
    required this.points,
    required this.avatarUrl,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
    name: map['name'] ?? '',
    bio: map['bio'] ?? '',
    points: map['points'] ?? 0,
    avatarUrl: map['avatar_url'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'bio': bio,
    'points': points,
    'avatar_url': avatarUrl,
  };
}
