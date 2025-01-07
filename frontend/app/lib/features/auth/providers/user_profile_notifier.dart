import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/auth/data/services/user_service.dart';

import '../data/models/user.dart';

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final UserService userService;

  UserProfileNotifier({required this.userService}) : super(const UserProfileState());

  // 내 정보 불러오기
  Future<void> fetchUserProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final userProfile = await userService.getUserProfile();
      state = state.copyWith(
        isLoading: false,
        userProfile: userProfile,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '프로필 불러오기 실패: $e',
      );
    }
  }

  // 프로필 초기화(로그아웃 시점 등)
  void clearProfile() {
    state = const UserProfileState();
  }
}
