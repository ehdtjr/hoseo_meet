import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user.dart';
import '../data/services/user_service.dart';

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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await userService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }


  Future<void> reportUser({
    required int reportedUserId,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await userService.reportUser(
        reported_user_id: reportedUserId,
        reason: reason,
      );

      state = state.copyWith(isLoading: false);
    } catch (e) {
      String parsedMessage = '알 수 없는 오류가 발생했습니다.';

      final msg = e.toString();
      final jsonStart = msg.indexOf('{');
      if (jsonStart != -1) {
        try {
          final jsonString = msg.substring(jsonStart);
          final decoded = jsonDecode(jsonString);
          if (decoded is Map && decoded['detail'] != null) {
            parsedMessage = decoded['detail'].toString();
          }
        } catch (_) {}
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: parsedMessage,
      );
      rethrow;
    }
  }


  // 프로필 초기화(로그아웃 시점 등)
  void clearProfile() {
    state = const UserProfileState();
  }
}
