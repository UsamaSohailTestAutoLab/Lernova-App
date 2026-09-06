class LeaderboardEntry {
  final String id;
  final String name;
  final String avatarSeed;
  final int weeklyXp;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.id,
    required this.name,
    required this.avatarSeed,
    required this.weeklyXp,
    this.isCurrentUser = false,
  });

  LeaderboardEntry copyWith({int? weeklyXp}) {
    return LeaderboardEntry(
      id: id,
      name: name,
      avatarSeed: avatarSeed,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      isCurrentUser: isCurrentUser,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarSeed': avatarSeed,
        'weeklyXp': weeklyXp,
        'isCurrentUser': isCurrentUser,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarSeed: json['avatarSeed'] as String,
      weeklyXp: json['weeklyXp'] as int,
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }
}
