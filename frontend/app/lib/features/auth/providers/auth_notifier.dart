import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/auth_state.dart';
import '../data/services/login_service.dart';
import '../../../../../features/auth/data/services/token_storage_service.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final TokenStorageService _tokenStorage; // (A) 토큰 스토리지 주입

  AuthNotifier(this._authService, this._tokenStorage) : super(AuthState.initial()) {
    _initAutoLogin(); // (B) 생성자에서 자동로그인 시도
  }

  /// 앱 시작 시점 자동로그인
  Future<void> _initAutoLogin() async {
    // 1) 로컬에 Refresh Token이 있는지 체크
    final storedRefresh = await _tokenStorage.readRefreshToken();
    if (storedRefresh != null) {
      // 2) state에 반영
      state = state.copyWith(refreshToken: storedRefresh);

      // 3) refreshAccessToken() 시도
      await refreshAccessToken();
      // 만약 실패하면 state.errorMessage에 설정됨 → UI에서 처리
    }
  }

  /// (1) 로그인
  Future<void> loginUser(String username, String password) async {
    // 로딩 시작
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // AuthService가 Map<String, dynamic> 형태로 결과를 반환
      final result = await _authService.loginUser(
        username: username,
        password: password,
      );

      final statusCode = result['statusCode'] as int?;
      if (statusCode == 200) {
        // 토큰 추출
        final accessToken = result['accessToken'] as String?;
        final refreshToken = result['refreshToken'] as String?;

        // 상태 업데이트
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: (accessToken != null),
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        // (C) Refresh Token 저장
        if (refreshToken != null) {
          await _tokenStorage.writeRefreshToken(refreshToken);
        }

      } else {
        // 로그인 실패
        final error = result['error'];
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: false,
          errorMessage: '로그인 실패: $error',
        );
      }
    } catch (e) {
      // 예외 (네트워크 등)
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
    // (E) 스토리지에서 Refresh Token 삭제
    await _tokenStorage.deleteRefreshToken();
    // 상태를 초기화
    state = AuthState.initial();
  }
}
