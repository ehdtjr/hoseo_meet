import 'package:http/http.dart' as http;
import '../../../../config.dart'; // AppConfig (baseUrl 등)
import '../../../../api/login/login_service.dart'; // AuthService (토큰)

class ActivateDeactivateService {
  final AuthService _authService;

  ActivateDeactivateService(this._authService);

  /// 채팅방 활성화
  /// `streamId`(int): path 파라미터 (ex: /stream/27/active)
  Future<void> activateRoom(int streamId) async {
    final token = _authService.accessToken;
    if (token == null) {
      throw Exception('로그인 토큰이 없습니다. 로그인 후 다시 시도해주세요.');
    }

    final url = '${AppConfig.baseUrl}/stream/$streamId/active?lifetime_seconds=3600';
    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        print('[Activate] 성공: $streamId');
        print('응답: ${response.body}');
      } else {
        print('[Activate] 실패: ${response.statusCode}');
        print('응답: ${response.body}');
      }
    } catch (e) {
      print('[Activate] 요청 중 오류: $e');
    }
  }

  /// 활성화된 채팅방 해제
  /// `POST /api/v1/stream/deactive`
  Future<void> deactivateRoom() async {
    final token = _authService.accessToken;
    if (token == null) {
      throw Exception('로그인 토큰이 없습니다. 로그인 후 다시 시도해주세요.');
    }

    final url = '${AppConfig.baseUrl}/stream/deactive';
    final headers = {
      'accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        print('[Deactivate] 성공');
        print('응답: ${response.body}');
      } else {
        print('[Deactivate] 실패: ${response.statusCode}');
        print('응답: ${response.body}');
      }
    } catch (e) {
      print('[Deactivate] 요청 중 오류: $e');
    }
  }
}
