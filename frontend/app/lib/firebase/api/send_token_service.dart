import 'package:http/http.dart' as http;
import '../../config.dart'; // AppConfig import (기본 URL)
import '../../commons/network/auth_http_client.dart'; // AuthHttpClient import

class SendTokenService {
  final String _endpoint =
      '${AppConfig.baseUrl}/users/me/register/fcm-token?lifetime_seconds=3600';

  final AuthHttpClient _client; // (1) AuthHttpClient로 교체

  SendTokenService(this._client);

  /// FCM 토큰을 서버에 전송하는 함수
  Future<http.Response> sendToken(String fcmToken) async {
    // 요청 바디 (JSON)
    final Map<String, dynamic> requestBody = {
      'fcm_token': fcmToken,
    };

    // (2) AuthHttpClient를 통해 POST 요청
    final response = await _client.postRequest(_endpoint, requestBody);

    return response;
  }
}
