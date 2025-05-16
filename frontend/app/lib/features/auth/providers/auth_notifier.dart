import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/auth_state.dart';
import '../data/services/auth_service.dart';
import '../../../../../features/auth/data/services/token_storage_service.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final TokenStorageService _tokenStorage; // (A) 토큰 스토리지 주입

  AuthNotifier(this._authService, this._tokenStorage) : super(AuthState.initial()) {
    _initAutoLogin(); // (B) 생성자에서 자동로그인 시도
  }

  /// 앱 시작 시점 자동로그인
  Future<void> _initAutoLogin() async {
    // 1) 로컬에서 Refresh Token 읽기
    final storedRefresh = await _tokenStorage.readRefreshToken();

    if (storedRefresh != null) {
      // 2) state에 반영
      state = state.copyWith(refreshToken: storedRefresh);

      // 3) refreshAccessToken() 시도
      await refreshAccessToken();

      if (!state.isLoggedIn) {
        await _tokenStorage.deleteRefreshToken();
      }
    }
  }

  Future<void> loginUser(String username, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _authService.loginUser(
        username: username,
        password: password,
      );

      final statusCode = result['statusCode'] as int?;
      if (statusCode == 200) {
        final accessToken = result['accessToken'] as String?;
        final refreshToken = result['refreshToken'] as String?;

        state = state.copyWith(
          isLoading: false,
          isLoggedIn: (accessToken != null),
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        if (refreshToken != null) {
          await _tokenStorage.writeRefreshToken(refreshToken);
        }

      } else {
        // 로그인 실패 시, detail 필드만 추출
        final errorRaw = result['error'];
        String errorMessage;

        try {
          final parsed = jsonDecode(errorRaw);
          errorMessage = parsed['detail'] ?? '로그인 실패';
        } catch (_) {
          errorMessage = errorRaw.toString();
        }

        state = state.copyWith(
          isLoading: false,
          isLoggedIn: false,
          errorMessage: '로그인 실패: $errorMessage',
        );
      }

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        errorMessage: '로그인 중 오류: $e',
      );
    }
  }


  /// (2) 토큰 리프레시
  Future<void> refreshAccessToken() async {
    final currentRefresh = state.refreshToken;
    if (currentRefresh == null) {
      // 로컬에 Refresh Token이 아예 없으면 그냥 종료
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.refreshAccessToken(refreshToken: currentRefresh);
    final statusCode = result['statusCode'] as int?;

    if (statusCode == 200) {
      final newAccess = result['accessToken'] as String?;
      final newRefresh = result['refreshToken'] as String?;

      state = state.copyWith(
        isLoading: false,
        isLoggedIn: (newAccess != null),
        accessToken: newAccess,
        refreshToken: newRefresh,
      );

      // (D) 새로 받은 refreshToken도 저장
      if (newRefresh != null) {
        await _tokenStorage.writeRefreshToken(newRefresh);
      }

    } else {
      final error = result['error'];
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        errorMessage: '토큰 갱신 실패: $error',
      );
    }
  }

  /// (3) 로그아웃
  Future<void> logout() async {
    final accessToken = state.accessToken;

    if (accessToken == null) {
      print('[AuthNotifier] accessToken 없음 → 서버 로그아웃 생략');
    } else {
      await _authService.logout(accessToken: accessToken);
    }

    await _tokenStorage.deleteRefreshToken();
    state = AuthState.initial();
  }

  Future<Register> register(RegisterRequest request) async {
    try {
      final result = await _authService.register(request);

      if (result.success) {
        print('[AuthNotifier] 회원가입 성공: ${result.message}');
      } else {
        print('[AuthNotifier] 회원가입 실패: ${result.error}');
      }

      return result;
    } catch (e) {
      return Register.failure('회원가입 처리 중 예외 발생: $e');
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _authService.requestPasswordReset(email);
    final statusCode = result['statusCode'] as int?;

    if (statusCode == 202) {
      state = state.copyWith(isLoading: false);
      return {'success': true, 'message': result['message']};
    } else {
      final error = result['error'] ?? '비밀번호 재설정 요청 실패';
      state = state.copyWith(isLoading: false, errorMessage: error);
      return {'success': false, 'error': error};
    }
  }

}
