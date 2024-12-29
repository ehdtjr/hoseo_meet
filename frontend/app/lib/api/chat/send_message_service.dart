import '../../config.dart'; // config 파일 import
import '../login/login_service.dart'; // AuthService import

class SendMessageService {
  final String sendMessageEndpoint = '${AppConfig.baseUrl}/messages/send/stream/';
  final AuthService _authService;

  SendMessageService(this._authService);

  // 메시지를 보내는 함수
  Future<void> sendMessage({
    required int streamId,
    required String messageContent,
  }) async {
    // x-www-form-urlencoded에 맞춰 String으로
    final formBody = <String, String>{
      'message_content': messageContent,
    };

    final url = '$sendMessageEndpoint$streamId?lifetime_seconds=3600';

    // x-www-form-urlencoded 전송 메서드 사용
    final response = await _authService.postRequestFormUrlEncoded(url, formBody);

    if (response.statusCode == 200) {
      print('메시지 전송 성공: ${response.body}');
    } else {
      throw Exception('메시지 전송에 실패했습니다: ${response.body}');
    }
  }
}

