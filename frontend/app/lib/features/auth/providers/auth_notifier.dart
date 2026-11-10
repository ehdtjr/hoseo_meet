import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/auth_state.dart';
import '../data/services/auth_service.dart';
import '../../../../../features/auth/data/services/token_storage_service.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final TokenStorageService _tokenStorage;
  late final Future<void> initialization;
  Future<void>? _refreshTask;
  Future<void> _storageTask = Future.value();
  int _sessionRevision = 0;

  /// Changes on account replacement/logout, but not ordinary token rotation.
  int get sessionRevision => _sessionRevision;

  AuthNotifier(this._authService, this._tokenStorage)
      : super(AuthState.initial()) {
    initialization = _initAutoLogin();
  }

  bool _isCurrent(int revision) => mounted && revision == _sessionRevision;

  // All storage mutations share one queue. Clears must run even when a later
  // login changes revision; that login's write is queued after the clear.
  Future<void> _queueStorage(Future<void> Function() operation) {
    final task = _storageTask.then((_) => operation());
    _storageTask = task.catchError((Object _) {});
    return task;
  }

  Future<void> _store(int revision, Future<void> Function() operation) =>
      _queueStorage(() async {
        if (_isCurrent(revision)) await operation();
      });

  Future<void> _initAutoLogin() async {
    final revision = _sessionRevision;
    final storedRefresh = await _tokenStorage.readRefreshToken();
    if (!_isCurrent(revision) || storedRefresh == null) return;
    state = state.copyWith(refreshToken: storedRefresh);
    await refreshAccessToken();
  }

  bool get _hasUsableAccessToken {
    if (!state.isLoggedIn || state.accessToken == null) return false;
    try {
      final parts = state.accessToken!.split('.');
      final payload = jsonDecode(
              utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
          as Map<String, dynamic>;
      final expiry = payload['exp'] as num?;
      return expiry != null &&
          expiry * 1000 > DateTime.now().millisecondsSinceEpoch + 30000;
    } catch (_) {
      // An opaque credential has no client-readable expiry. HTTP 401 remains
      // authoritative; never log out merely because local decoding failed.
      return true;
    }
  }

  /// Gate foreground recovery and socket handshakes on current credentials.
  Future<bool> ensureValidSession() async {
    await initialization;
    if (!mounted) return false;
    final pending = _refreshTask;
    if (pending != null) {
      await pending;
      return mounted && _hasUsableAccessToken;
    }
    if (!mounted) return false;
    if (_hasUsableAccessToken) return true;
    await refreshAccessToken();
    return mounted && _hasUsableAccessToken;
  }

  /// A delayed 401 may refer to a token that another request already rotated.
  Future<bool> refreshRejectedToken(String rejectedToken) async {
    if (!state.isLoggedIn) return false;
    if (state.accessToken != rejectedToken) return _hasUsableAccessToken;
    await refreshAccessToken();
    return mounted &&
        state.isLoggedIn &&
        state.accessToken != null &&
        state.accessToken != rejectedToken;
  }

  Future<void> loginUser(String username, String password) async {
    final revision = ++_sessionRevision;
    _refreshTask = null;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _authService.loginUser(
        username: username,
        password: password,
      );

      if (!_isCurrent(revision)) return;
      final statusCode = result['statusCode'] as int?;
      if (statusCode == 200) {
        final accessToken = result['accessToken'] as String?;
        final refreshToken = result['refreshToken'] as String?;

        state = AuthState(
          isLoading: false,
          isLoggedIn: (accessToken != null),
          accessToken: accessToken,
          refreshToken: refreshToken,
        );

        if (refreshToken != null) {
          await _store(
              revision, () => _tokenStorage.writeRefreshToken(refreshToken));
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
      if (!_isCurrent(revision)) return;
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        errorMessage: '로그인 중 오류: $e',
      );
    }
  }

  /// All callers share one refresh, including foreground and HTTP recovery.
  Future<void> refreshAccessToken() {
    final pending = _refreshTask;
    if (pending != null) return pending;
    final refresh = state.refreshToken;
    if (refresh == null) return Future.value();
    final revision = _sessionRevision;
    late final Future<void> task;
    task = _refresh(refresh, revision).whenComplete(() {
      if (identical(_refreshTask, task)) _refreshTask = null;
    });
    _refreshTask = task;
    return task;
  }

  Future<void> _refresh(String refresh, int revision) async {
    // Token maintenance must not replace the current screen with a login spinner.
    try {
      final result =
          await _authService.refreshAccessToken(refreshToken: refresh);
      if (!_isCurrent(revision) || state.refreshToken != refresh) return;
      final status = result['statusCode'] as int?;
      final access = result['accessToken'] as String?;
      if (status == 200 && access != null && access.isNotEmpty) {
        final rotated = result['refreshToken'] as String? ?? refresh;
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: true,
          accessToken: access,
          refreshToken: rotated,
        );
        await _store(revision, () => _tokenStorage.writeRefreshToken(rotated));
      } else if (status == 400 || status == 401 || status == 403) {
        // Explicit credential rejection clears both in-memory credentials and
        // storage. Other failures leave the session available for later retry.
        _sessionRevision++;
        final clearing = _queueStorage(_tokenStorage.deleteRefreshToken);
        state = AuthState.initial()
            .copyWith(errorMessage: '로그인이 만료되었습니다. 다시 로그인해주세요.');
        await clearing;
      } else {
        state = state.copyWith(
            isLoading: false, errorMessage: '로그인 연결을 확인하지 못했습니다. 다시 시도해주세요.');
      }
    } catch (_) {
      if (_isCurrent(revision)) {
        state = state.copyWith(
            isLoading: false, errorMessage: '로그인 연결을 확인하지 못했습니다. 다시 시도해주세요.');
      }
    }
  }

  Future<void> logout() async {
    final accessToken = state.accessToken;
    _sessionRevision++;
    _refreshTask = null;
    final clearing = _queueStorage(_tokenStorage.deleteRefreshToken);
    state = AuthState.initial();
    try {
      if (accessToken != null) {
        await _authService.logout(accessToken: accessToken);
      }
    } finally {
      await clearing;
    }
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

  Future<void> deleteAccount() async {
    final accessToken = state.accessToken;

    if (accessToken == null) {
      state = state.copyWith(errorMessage: '로그인 정보가 없습니다.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final statusCode = await _authService.deleteAccount(accessToken: accessToken);

      if (statusCode == 204) {
        _sessionRevision++;
        _refreshTask = null;
        final clearing = _queueStorage(_tokenStorage.deleteRefreshToken);
        state = AuthState.initial();
        await clearing;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '계정 삭제 실패 (status: $statusCode)',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '계정 삭제 중 오류 발생: $e',
      );
    }
  }
}
