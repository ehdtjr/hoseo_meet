import 'package:campusmeet/commons/network/auth_http_client.dart';
import 'package:campusmeet/features/chat/data/repositories/chat_repository.dart';
import 'package:campusmeet/features/chat/data/services/activate_deactivate_service.dart';
import 'package:campusmeet/features/chat/data/services/load_message_service.dart';
import 'package:campusmeet/features/chat/data/services/message_read_service.dart';
import 'package:campusmeet/features/chat/data/services/send_message_service.dart';
import 'package:campusmeet/features/chat/data/services/socket_message_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class ReadClient implements AuthHttpClient {
  final int status;
  Map<String, dynamic>? sentBody;
  ReadClient(this.status);

  @override
  Future<http.Response> postRequest(String url, Map<String, dynamic> body,
      {Map<String, String>? headers}) async {
    sentBody = body;
    return http.Response('', status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final status in [200, 403, 500]) {
    test('fetched-range read uses explicit anchor and propagates HTTP $status',
        () async {
      final client = ReadClient(status);
      final socket = SocketMessageService('test-token');
      addTearDown(socket.dispose);
      final repository = ChatRepository(
        loadService: LoadMessageService(client),
        sendService: SendMessageService(client),
        readService: MessageReadService(client),
        activateService: ActivateDeactivateService(client),
        socketService: socket,
      );
      final result = repository.markLoadedMessagesAsRead(
          streamId: 7, anchorId: 42, numBefore: 1);
      if (status == 200) {
        await result;
      } else {
        await expectLater(result, throwsException);
      }
      expect(client.sentBody, {
        'stream_id': 7,
        'anchor': '42',
        'num_before': 1,
        'num_after': 0,
      });
    });
  }
}
