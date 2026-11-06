import 'package:campusmeet/commons/network/auth_http_client.dart';
import 'package:campusmeet/features/chat/data/services/send_message_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class StubClient implements AuthHttpClient {
  int status = 200;
  bool disconnected = false;
  Map<String, String>? form;
  Map<String, String>? headers;
  @override
  Future<http.Response> postFormUrlEncoded(
      String url, Map<String, String> formFields,
      {Map<String, String>? headers}) async {
    form = formFields;
    this.headers = headers;
    if (disconnected) throw http.ClientException('offline');
    return http.Response('', status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final status in [200, 201, 204, 400, 401, 403, 422, 500, 503]) {
    test('send propagates HTTP $status explicitly', () async {
      final client = StubClient()..status = status;
      final result = SendMessageService(client).sendMessage(
          streamId: 7, messageContent: '원문 & +', clientMessageId: 'message-id');
      if (status < 300) {
        await result;
      } else {
        await expectLater(
            result,
            throwsA(isA<MessageSendException>()
                .having((e) => e.statusCode, 'statusCode', status)));
      }
      expect(client.form, {'message_content': '원문 & +'});
      expect(client.headers, {'X-Client-Message-ID': 'message-id'});
    });
  }
  test('transport errors propagate instead of becoming successful sends',
      () async {
    final client = StubClient()..disconnected = true;
    await expectLater(
        SendMessageService(client).sendMessage(
            streamId: 7, messageContent: '원문', clientMessageId: 'message-id'),
        throwsA(isA<http.ClientException>()));
  });
}
