// lib/kakao/kakao_auto_login_service.dart
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KakaoAutoLoginService {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  // 자동 로그인을 시도하는 메서드
  Future<bool> tryAutoLogin() async {
    String? accessToken = await _storage.read(key: 'accessToken');
    String? refreshToken = await _storage.read(key: 'refreshToken');

    if (accessToken == null || refreshToken == null) {
      return false;
    }

    try {
      bool isValidToken = await AuthApi.instance.hasToken();

      if (isValidToken) {
        await TokenManagerProvider.instance.manager.setToken(
          OAuthToken(
            accessToken,
            DateTime.now().add(Duration(hours: 1)),
            refreshToken,
            DateTime.now().add(Duration(days: 30)),
            null,
          ),
        );
        print("자동 로그인 성공: Access Token: $accessToken, Refresh Token: $refreshToken");
        return true;
      } else {
        OAuthToken token = await AuthApi.instance.refreshAccessToken(
          oldToken: OAuthToken(
            accessToken,
            DateTime.now().add(Duration(hours: 1)),
            refreshToken,
            DateTime.now().add(Duration(days: 30)),
            null,
          ),
        );
        await _storeToken(token.accessToken, token.refreshToken);
        print("토큰 재발급 성공: Access Token: ${token.accessToken}, Refresh Token: ${token.refreshToken}");
        return true;
      }
    } catch (e) {
      print("자동 로그인 실패: $e");
      return false;
    }
  }

  // 액세스 토큰과 리프레시 토큰을 로컬에 저장하는 메서드
  Future<void> _storeToken(String? accessToken, String? refreshToken) async {
    if (accessToken != null) {
      await _storage.write(key: 'accessToken', value: accessToken);
    }
    if (refreshToken != null) {
      await _storage.write(key: 'refreshToken', value: refreshToken);
    }
  }

  // 토큰을 삭제하는 메서드 (테스트용)
  Future<void> deleteTokens() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
    print("로컬 스토리지의 토큰이 삭제되었습니다.");
  }
}
