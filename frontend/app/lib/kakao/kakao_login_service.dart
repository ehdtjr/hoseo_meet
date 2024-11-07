import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';

class KakaoLoginService {
  final _storage = FlutterSecureStorage();

  // 로그인 메서드: 로그인 성공 시 토큰 저장
  Future<bool> login() async {
    try {
      OAuthToken token;

      // 카카오톡 앱으로 로그인 시도
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      // 로그인 성공 시 토큰 정보를 안전하게 저장
      if (token.accessToken != null && token.refreshToken != null) {
        await _storeToken(token.accessToken!, token.refreshToken!);
      } else {
        print("토큰 정보가 없습니다.");
        return false;
      }

      // 사용자 정보 확인
      User user = await UserApi.instance.me();
      print("사용자 정보:");
      print("ID: ${user.id}");
      print("Nickname: ${user.kakaoAccount?.profile?.nickname}");
      print("Email: ${user.kakaoAccount?.email}");

      return true;
    } catch (error) {
      print("Kakao 로그인 실패: $error");
      return false;
    }
  }

  // 로그아웃 메서드: 로그아웃 시 저장된 토큰 삭제
  Future<void> logout() async {
    try {
      await UserApi.instance.logout();
      await _clearToken(); // 로컬에 저장된 토큰 삭제
      print("Kakao 로그아웃 성공");
    } catch (error) {
      print("Kakao 로그아웃 실패: $error");
    }
  }

  // 자동 로그인 시도 메서드
  Future<bool> tryAutoLogin() async {
    final accessToken = await _storage.read(key: 'accessToken');
    if (accessToken == null) {
      return false; // 저장된 토큰이 없으면 자동 로그인 불가능
    }

    // 토큰이 있을 경우, 사용자 정보 조회로 자동 로그인 시도
    try {
      User user = await UserApi.instance.me();
      print("자동 로그인 성공, 사용자 정보:");
      print("ID: ${user.id}");
      print("Nickname: ${user.kakaoAccount?.profile?.nickname}");
      print("Email: ${user.kakaoAccount?.email}");
      return true;
    } catch (error) {
      print("자동 로그인 실패: $error");
      return false;
    }
  }

  // 토큰 저장 메서드
  Future<void> _storeToken(String accessToken, String refreshToken) async {
    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'refreshToken', value: refreshToken);
  }

  // 토큰 삭제 메서드
  Future<void> _clearToken() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
  }
}
