// Run only against websocket_probe_server.dart; this is not the application entrypoint.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:campusmeet/features/chat/data/models/chat_message.dart';
import 'package:campusmeet/features/chat/data/services/message_recovery_service.dart';
import 'package:campusmeet/features/chat/data/services/socket_message_service.dart';

void main() => runApp(const MaterialApp(home: NetworkProbe()));

class NetworkProbe extends StatefulWidget {
  const NetworkProbe({super.key});
  @override
  State<NetworkProbe> createState() => _NetworkProbeState();
}

class _NetworkProbeState extends State<NetworkProbe>
    with WidgetsBindingObserver {
  static const base = 'http://10.0.2.2:18823';
  final messages = <int, ChatMessage>{};
  String token = 'probe-token-one';
  int? checkpoint;
  bool active = true;
  late final SocketMessageService socket;
  StreamSubscription<dynamic>? events;
  StreamSubscription<dynamic>? states;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    socket = SocketMessageService(
      tokenProvider: () => active ? token : null,
      socketUrl: 'ws://10.0.2.2:18823/events/connect',
      initialRetryDelay: const Duration(milliseconds: 200),
      maxRetryDelay: const Duration(seconds: 2),
      connectTimeout: const Duration(seconds: 3),
      pingInterval: const Duration(seconds: 2),
      onConnected: () async {
        final recovered = await MessageRecoveryService(_load)
            .recover(streamId: 7, afterId: checkpoint, isActive: () => active);
        if (!active) return;
        for (final message in recovered) {
          messages.putIfAbsent(message.id, () => message);
        }
        if (recovered.isNotEmpty) checkpoint = recovered.last.id;
        _report();
      },
    );
    events = socket.messageStream.listen((event) {
      if (!active || event['type'] != 'stream') return;
      final message = ChatMessage.fromJson(event['data']);
      messages.putIfAbsent(message.id, () => message);
      _report();
    });
    states = socket.connectionStates.listen((_) => _report());
    socket.connectWebSocket();
  }

  Future<List<ChatMessage>> _load(
      {required int streamId,
      String anchor = 'first_unread',
      int numBefore = 10,
      int numAfter = 30}) async {
    final uri = Uri.parse('$base/messages/stream').replace(queryParameters: {
      'stream_id': '$streamId',
      'anchor': anchor,
      'num_before': '$numBefore',
      'num_after': '$numAfter',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 3));
    if (response.statusCode != 200) {
      throw StateError('Probe HTTP ${response.statusCode}');
    }
    return (jsonDecode(response.body) as List)
        .map((m) => ChatMessage.fromJson(m))
        .toList();
  }

  void _report() {
    final ids = messages.keys.toList()..sort();
    final report = {
      'at': DateTime.now().toUtc().toIso8601String(),
      'state': socket.connectionState.name,
      'token': token,
      'ids': ids,
      'checkpoint': checkpoint
    };
    debugPrint('NETWORK_PROBE ${jsonEncode(report)}');
    if (mounted) setState(() {});
    unawaited(http
        .post(Uri.parse('$base/report'), body: jsonEncode(report))
        .timeout(const Duration(seconds: 3))
        .then<void>((_) {}, onError: (Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!active) return;
    if (state == AppLifecycleState.resumed) socket.reconnectWebSocket();
    if (state == AppLifecycleState.paused) socket.closeWebSocket();
  }

  @override
  void dispose() {
    active = false;
    WidgetsBinding.instance.removeObserver(this);
    socket.dispose();
    events?.cancel();
    states?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Issue 23 network probe')),
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('State: ${socket.connectionState.name}'),
          Text('Messages: ${messages.length} / checkpoint: $checkpoint'),
          Text('Token: $token'),
          ElevatedButton(
              onPressed: () {
                token = 'probe-token-two';
                socket.reconnectWebSocket();
              },
              child: const Text('Rotate token')),
          ElevatedButton(
              onPressed: () {
                active = false;
                socket.dispose();
                _report();
              },
              child: const Text('Close service')),
        ])),
      );
}
