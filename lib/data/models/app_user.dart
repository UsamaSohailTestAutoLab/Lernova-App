import '../../core/constants/app_enums.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String avatarSeed;
  final DateTime joinedAt;
  final String? selectedLanguageId;
  final String? currentCourseId;
  final LearningGoal learningGoal;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarSeed,
    required this.joinedAt,
    this.selectedLanguageId,
    this.currentCourseId,
    this.learningGoal = LearningGoal.regular,
  });

  AppUser copyWith({
    String? name,
    String? email,
    String? avatarSeed,
    String? selectedLanguageId,
    String? currentCourseId,
    LearningGoal? learningGoal,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      joinedAt: joinedAt,
      selectedLanguageId: selectedLanguageId ?? this.selectedLanguageId,
      currentCourseId: currentCourseId ?? this.currentCourseId,
      learningGoal: learningGoal ?? this.learningGoal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarSeed': avatarSeed,
        'joinedAt': joinedAt.toIso8601String(),
        'selectedLanguageId': selectedLanguageId,
        'currentCourseId': currentCourseId,
        'learningGoal': learningGoal.name,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarSeed: json['avatarSeed'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      selectedLanguageId: json['selectedLanguageId'] as String?,
      currentCourseId: json['currentCourseId'] as String?,
      learningGoal: LearningGoal.values.byName(
        json['learningGoal'] as String? ?? 'regular',
      ),
    );
  }
}
