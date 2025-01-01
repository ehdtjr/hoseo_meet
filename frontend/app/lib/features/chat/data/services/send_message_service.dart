import '../../../../config.dart';
import '../../../../api/login/login_service.dart'; // AuthService
import 'package:http/http.dart' as http;

class SendMessageService {
  final String _locationEndpoint = '${AppConfig.baseUrl}/messages/send/stream/location/';
  final AuthService _authService;

  SendMessageService(this._authService);

  /// 1) 텍스트 메시지 전송 (form-urlencoded 예시 - 이미 기존에 있을 수 있음)
  Future<void> sendMessage({
    required int streamId,
    required String messageContent,
  }) async {
    final formBody = <String, String>{
      'message_content': messageContent,
    };

    final url = '${AppConfig.baseUrl}/messages/send/stream/$streamId?lifetime_seconds=3600';

    // AuthService의 postRequestFormUrlEncoded 활용
    final response = await _authService.postRequestFormUrlEncoded(url, formBody);
    if (response.statusCode == 200) {
      print('[SendMessageService] sendMessage 성공: ${response.body}');
    } else {
      throw Exception('[SendMessageService] sendMessage 실패: ${response.body}');
    }
  }

  Future<void> sendLocation({
    required int streamId,
    required double lat,
    required double lng,
  }) async {
    final url = '$_locationEndpoint$streamId';

    // JSON 형식의 바디
    final Map<String, dynamic> jsonBody = {
      'lat': lat,
      'lng': lng,
    };

    // AuthService의 postRequest 사용 (JSON 전송)
    final http.Response response = await _authService.postRequest(url, jsonBody);

    if (response.statusCode == 200) {
      print('[SendMessageService] 위치 전송 성공: ${response.body}');
    } else {
      throw Exception('[SendMessageService] 위치 전송 실패: ${response.statusCode} / ${response.body}');
    }
  }
}
