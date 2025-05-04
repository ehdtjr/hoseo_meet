import 'dart:io';

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

  Future<void> uploadProfileImage(File filePath) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final userProfile = await userService.uploadProfileImage(filePath);
      state = state.copyWith(
        isLoading: false,
        userProfile: userProfile,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '프로필 이미지 업로드 실패: $e',
      );
    }
    await fetchUserProfile();
  }


  // 프로필 초기화(로그아웃 시점 등)
  void clearProfile() {
    state = const UserProfileState();
  }
}
