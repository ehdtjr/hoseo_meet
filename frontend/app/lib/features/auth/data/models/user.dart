class User {
  final int id;
  final String name;
  final String gender;
  final String profile;

  User({
    required this.id,
    required this.name,
    required this.gender,
    required this.profile,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      profile: json['profile'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'gender': gender,
      'profile': profile,
    };
  }

  @override
  String toString() => 'User(id:$id, name:$name, gender:$gender, profile:$profile)';
}

class UserProfile {
  final int id;
  final String email;
  final bool isActive;
  final bool isSuperuser;
  final bool isVerified;
  final String name;
  final String gender;
  final String profile;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.isActive,
    required this.isSuperuser,
    required this.isVerified,
    required this.name,
    required this.gender,
    required this.profile,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      name: json['name'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      profile: json['profile'] as String? ?? '',
      createdAt: (json['created_at'] != null)
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'is_active': isActive,
      'is_superuser': isSuperuser,
      'is_verified': isVerified,
      'name': name,
      'gender': gender,
      'profile': profile,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() => 'UserProfile('
      'id:$id, email:$email, active:$isActive, superuser:$isSuperuser, '
      'verified:$isVerified, name:$name, gender:$gender, profile:$profile, createdAt:$createdAt)';
}

/// 3) UserProfileState - 내 프로필 로딩/에러/데이터 관리
class UserProfileState {
  final bool isLoading;
  final String? errorMessage;

  final UserProfile? userProfile;

  const UserProfileState({
    this.isLoading = false,
    this.errorMessage,
    this.userProfile,
  });

  UserProfileState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserProfile? userProfile,
  }) {
    return UserProfileState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      userProfile: userProfile ?? this.userProfile,
    );
  }

  @override
  String toString() {
    return 'UserProfileState('
        'isLoading:$isLoading, '
        'errorMessage:$errorMessage, '
        'userProfile:$userProfile)';
  }
}