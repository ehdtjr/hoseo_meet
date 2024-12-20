import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KakaoAutoLoginService {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  // 자동 로그인을 시도하는 메서드
  Future<bool> tryAutoLogin() async {
    String? accessToken = await _storage.read(key: 'accessToken');
    String? refreshToken = await _storage.read(key: 'refreshToken');

    print("카톡 자동로그인 시도전 토큰 값: Access Token: $accessToken, Refresh Token: $refreshToken");

    if (accessToken == null || refreshToken == null) {
      // 토큰이 없으면 자동 로그인 시도를 하지 않고 false를 반환
      print("자동 로그인 실패: 저장된 토큰이 없습니다.");
      return false;
    }

    try {
      bool isValidToken = await AuthApi.instance.hasToken();

      if (isValidToken) {
        await TokenManagerProvider.instance.manager.setToken(
          OAuthToken(
            accessToken,
            DateTime.now().add(Duration(hours: 12)),
            refreshToken,
            DateTime.now().add(Duration(days: 30)),
            null,
          ),
        );

        // 로그인 성공 시 토큰을 업데이트
        await _storeToken(accessToken, refreshToken);

        print("자동 로그인 성공: Access Token: $accessToken, Refresh Token: $refreshToken");
        return true;
      } else {
        // 토큰이 만료된 경우 새로 발급
        OAuthToken token = await AuthApi.instance.refreshAccessToken(
          oldToken: OAuthToken(
            accessToken,
            DateTime.now().add(Duration(hours: 1)),
            refreshToken,
            DateTime.now().add(Duration(days: 30)),
            null,
          ),
        );

        // 재발급된 토큰을 로컬에 저장
        await _storeToken(token.accessToken, token.refreshToken);

        print("토큰 재발급 성공: Access Token: ${token.accessToken}, Refresh Token: ${token.refreshToken}");
        return true;
      }
    } catch (e) {
      // 자동 로그인 및 토큰 재발급에 실패한 경우 false를 반환
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
