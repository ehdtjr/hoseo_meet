// Synthetic server for websocket_network_probe.dart. No real accounts or tokens.
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 18823);
  final history = <Map<String, dynamic>>[];
  final sockets = <WebSocket>{};
  final connections = <Map<String, dynamic>>[];
  final reports = <dynamic>[];
  Map<String, dynamic> message(int id) => {
        'id': id,
        'stream_id': 7,
        'content': 'probe-$id',
        'date_sent': '2026-11-06T00:00:00Z',
      };
  history.add(message(1));
  stdout.writeln('Probe listening on 127.0.0.1:18823');
  await for (final request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final token = request.headers.value('sec-websocket-protocol');
      if (!['probe-token-one', 'probe-token-two'].contains(token)) {
        request.response.statusCode = 403;
        await request.response.close();
        continue;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      connections.add(
          {'token': token, 'at': DateTime.now().toUtc().toIso8601String()});
      socket.listen((_) {},
          onDone: () => sockets.remove(socket),
          onError: (Object _) => sockets.remove(socket));
      continue;
    }
    dynamic result;
    final query = request.uri.queryParameters;
    switch (request.uri.path) {
      case '/messages/stream':
        final anchor = query['anchor'];
        if (anchor == 'newest') {
          result = [history.last];
          break;
        }
        final from = anchor == 'oldest' ? 1 : int.parse(anchor!);
        final after = int.parse(query['num_after']!);
        result = history
            .where((m) => (m['id'] as int) >= from)
            .take(after + 1)
            .toList();
        break;
      case '/publish':
        final count = int.parse(query['count'] ?? '1');
        for (var i = 0; i < count; i++) {
          final msg = message(history.length + 1);
          history.add(msg);
          final event = jsonEncode({
            'type': 'stream',
            'data': msg,
            'last_event_id': '${msg['id']}-0'
          });
          for (final socket in sockets.toList()) {
            socket.add(event);
          }
        }
        result = {'newest': history.length};
        break;
      case '/disconnect':
        for (final socket in sockets.toList()) {
          socket.close();
        }
        result = {'disconnected': sockets.length};
        break;
      case '/report':
        reports.add(jsonDecode(await utf8.decoder.bind(request).join()));
        result = {'ok': true};
        break;
      case '/status':
        result = {
          'newest': history.length,
          'active': sockets.length,
          'connections': connections,
          'reports': reports
        };
        break;
      default:
        request.response.statusCode = 404;
        result = {'detail': 'Unknown probe route'};
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(result));
    await request.response.close();
  }
}
