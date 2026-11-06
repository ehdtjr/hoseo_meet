import 'dart:async';
import 'dart:io';

import 'package:campusmeet/features/chat/data/services/socket_message_service.dart';
import 'package:flutter_test/flutter_test.dart';

class CloseOnlySocket implements WebSocket {
  int closeCalls = 0;
  @override
  Future<void> close([int? code, String? reason]) async {
    closeCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected socket operation');
}

void main() {
  testWidgets(
      'dispose completes a pending handshake and leaves no timeout timer',
      (tester) async {
    final handshake = Completer<WebSocket>();
    final service = SocketMessageService(
        tokenProvider: () => 'token', connector: (_, __) => handshake.future);
    final connecting = service.connectWebSocket();
    await tester.pump();
    service.dispose();
    await connecting;
    final lateSocket = CloseOnlySocket();
    handshake.complete(lateSocket);
    await tester.pump();
    expect(lateSocket.closeCalls, 1);
    expect(service.connectionState, SocketConnectionState.disposed);
    // testWidgets also fails if the 15-second handshake timer remains pending.
  });

  testWidgets('dispose cancels waiting for asynchronous authentication',
      (tester) async {
    final token = Completer<String?>();
    var attempts = 0;
    final service = SocketMessageService(
        tokenProvider: () => token.future,
        connector: (_, __) async {
          attempts++;
          return CloseOnlySocket();
        });
    final connecting = service.connectWebSocket();
    await tester.pump();
    service.dispose();
    await connecting;
    token.complete('late-token');
    await tester.pump();
    expect(attempts, 0);
  });
}
