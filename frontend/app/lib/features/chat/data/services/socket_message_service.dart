import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../../config.dart';

enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  disposed,
}

typedef SocketConnector = Future<WebSocket> Function(String url, String token);

/// Owns one connection and one retry timer. Authentication is read per attempt.
class SocketMessageService {
  SocketMessageService({
    required FutureOr<String?> Function() tokenProvider,
    String? socketUrl,
    SocketConnector? connector,
    Future<void> Function()? onConnected,
    this.initialRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 30),
    this.connectTimeout = const Duration(seconds: 15),
    this.pingInterval = const Duration(seconds: 15),
  })  : _tokenProvider = tokenProvider,
        _socketUrl = socketUrl ?? AppConfig.socketUrl,
        _connector = connector,
        _onConnected = onConnected;

  final FutureOr<String?> Function() _tokenProvider;
  final String _socketUrl;
  final SocketConnector? _connector;
  final Future<void> Function()? _onConnected;
  final Duration initialRetryDelay;
  final Duration maxRetryDelay;
  final Duration connectTimeout;
  final Duration pingInterval;

  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _states = StreamController<SocketConnectionState>.broadcast();
  final _eventIds = <String>{};
  WebSocket? _socket;
  HttpClient? _httpClient;
  StreamSubscription<dynamic>? _subscription;
  Completer<void>? _socketDone;
  Future<void> _transportClosing = Future.value();
  Future<void>? _disposeTask;
  Timer? _retryTimer;
  Timer? _handshakeTimer;
  Completer<WebSocket?>? _handshake;
  Completer<void>? _cancelSignal;
  Future<void>? _connectionTask;
  bool _wanted = false;
  bool _disposed = false;
  int _generation = 0;
  int _failures = 0;
  SocketConnectionState _state = SocketConnectionState.disconnected;

  Stream<Map<String, dynamic>> get messageStream => _messages.stream;
  Stream<SocketConnectionState> get connectionStates => _states.stream;
  SocketConnectionState get connectionState => _state;

  void _setState(SocketConnectionState value) {
    if (_state == value || _disposed) return;
    _state = value;
    print('[WebSocket] state=${value.name}');
    _states.add(value);
  }

  bool _isCurrent(int generation) =>
      !_disposed && _wanted && generation == _generation;

  Future<void> connectWebSocket() {
    if (_disposed) return Future.value();
    _wanted = true;
    if (_connectionTask != null) return _connectionTask!;
    if (_socket != null || _retryTimer != null) return Future.value();
    final generation = _generation;
    _setState(
      _failures == 0
          ? SocketConnectionState.connecting
          : SocketConnectionState.reconnecting,
    );
    final task = _open(generation);
    _connectionTask = task;
    unawaited(
      task.whenComplete(() {
        if (identical(_connectionTask, task)) _connectionTask = null;
      }),
    );
    return task;
  }

  Future<void> _open(int generation) async {
    final cancelled = Completer<void>();
    _cancelSignal = cancelled;
    try {
      await Future.any<void>([_transportClosing, cancelled.future]);
      if (!_isCurrent(generation)) return;
      final token = await Future.any<String?>([
        Future.sync(_tokenProvider),
        cancelled.future.then((_) => null),
      ]);
      if (!_isCurrent(generation)) return;
      if (token == null || token.isEmpty) {
        closeWebSocket();
        return;
      }
      final client = _connector == null ? HttpClient() : null;
      _httpClient = client;
      if (client != null) client.connectionTimeout = connectTimeout;
      final pending = _connector != null
          ? _connector(_socketUrl, token)
          : WebSocket.connect(
              _socketUrl,
              headers: {'sec-websocket-protocol': token},
              customClient: client,
            );
      final handshake = Completer<WebSocket?>();
      _handshake = handshake;
      _handshakeTimer = Timer(connectTimeout, () {
        if (!handshake.isCompleted) {
          handshake
              .completeError(TimeoutException('WebSocket handshake timed out'));
        }
      });
      // Cancellation completes our wait immediately. A late raw handshake must
      // still be closed, without attaching the application's listener.
      unawaited(pending.then((socket) {
        if (handshake.isCompleted || !_isCurrent(generation)) {
          unawaited(socket.close());
        } else {
          handshake.complete(socket);
        }
      }, onError: (Object error, StackTrace stack) {
        if (!handshake.isCompleted) handshake.completeError(error, stack);
      }));
      WebSocket? socket;
      try {
        socket = await handshake.future;
      } finally {
        if (identical(_handshake, handshake)) {
          _handshakeTimer?.cancel();
          _handshakeTimer = null;
          _handshake = null;
        }
      }
      if (socket == null) return;
      if (!_isCurrent(generation)) {
        unawaited(socket.close());
        return;
      }
      _socket = socket;
      socket.pingInterval = pingInterval;
      final done = Completer<void>();
      _socketDone = done;
      _subscription = socket.listen(
        (data) {
          if (_isCurrent(generation)) _onMessageReceived(data);
        },
        onDone: () {
          print('[WebSocket] disconnected');
          if (!done.isCompleted) done.complete();
          _retry(generation);
        },
        onError: (Object error) {
          print('[WebSocket] transport_failed');
          if (!done.isCompleted) done.complete();
          _retry(generation);
        },
        cancelOnError: true,
      );
      // Listen before HTTP catch-up: live traffic may overlap the recovered page.
      await _onConnected?.call();
      if (!_isCurrent(generation)) return;
      _failures = 0;
      _setState(SocketConnectionState.connected);
    } catch (_) {
      // Avoid logging headers or message bodies containing private chat content.
      print('[WebSocket] connect_failed');
      _retry(generation);
    }
  }

  void _retry(int generation) {
    if (!_isCurrent(generation)) return;
    _generation++;
    unawaited(_releaseTransport());
    _connectionTask = null;
    _setState(SocketConnectionState.reconnecting);
    var delay = initialRetryDelay;
    for (var i = 0; i < _failures && delay < maxRetryDelay; i++) {
      delay *= 2;
    }
    if (delay > maxRetryDelay) delay = maxRetryDelay;
    _failures++;
    print('[WebSocket] retry_scheduled attempt=$_failures');
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      unawaited(connectWebSocket());
    });
  }

  void _onMessageReceived(dynamic data) {
    try {
      final decoded = jsonDecode(data as String);
      if (decoded is! Map<String, dynamic>) {
        print('[WebSocket] invalid_message_shape');
        return;
      }
      final eventId = decoded['last_event_id']?.toString();
      if (eventId != null) {
        if (!_eventIds.add(eventId)) return;
        if (_eventIds.length > 1024) _eventIds.remove(_eventIds.first);
      }
      // Unknown types can contain private input. Log protocol constants only.
      final type = decoded['type'];
      final safeType = type is String &&
              const {'stream', 'user', 'location', 'read'}.contains(type)
          ? type
          : 'unknown';
      print('[WebSocket] received type=$safeType');
      _messages.add(decoded);
    } on FormatException {
      // Ignore malformed frames without interrupting the connection.
      print('[WebSocket] decode_failed');
    } on TypeError {
      // Binary/non-object frames are not chat events.
      print('[WebSocket] invalid_frame');
    }
  }

  /// A resume/token change replaces even a half-open connection immediately.
  Future<void> reconnectWebSocket() async {
    if (_disposed) return;
    await closeWebSocket();
    await connectWebSocket();
  }

  Future<void> _releaseTransport() {
    _cancelSignal?.complete();
    _cancelSignal = null;
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    final handshake = _handshake;
    _handshake = null;
    if (handshake != null && !handshake.isCompleted) handshake.complete(null);
    _httpClient?.close(force: true);
    _httpClient = null;
    final subscription = _subscription;
    final socket = _socket;
    final done = _socketDone;
    _subscription = null;
    _socket = null;
    _socketDone = null;
    // Keep reading the protocol close response; cancelling first bypasses the
    // dart:io cleanup that stops the heartbeat and close-handshake timers.
    final closing = () async {
      if (socket != null) {
        socket.pingInterval = null;
        try {
          await socket.close();
          await done?.future;
        } catch (_) {
          // Transport failure also completes the listener's done signal.
        }
      }
      await subscription?.cancel();
    }();
    _transportClosing = Future.wait([_transportClosing, closing]).then((_) {});
    return _transportClosing;
  }

  Future<void> closeWebSocket() {
    _wanted = false;
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _connectionTask = null;
    _failures = 0;
    final closing = _releaseTransport();
    _setState(SocketConnectionState.disconnected);
    return closing;
  }

  Future<void> dispose() {
    if (_disposeTask != null) return _disposeTask!;
    final closing = closeWebSocket();
    _setState(SocketConnectionState.disposed);
    _disposed = true;
    _eventIds.clear();
    return _disposeTask = Future.wait([
      closing,
      _messages.close(),
      _states.close(),
    ]).then((_) {});
  }
}
