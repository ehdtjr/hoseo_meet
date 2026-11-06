import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/socket_message_service.dart';

typedef SocketMessageServiceFactory = SocketMessageService Function({
  required FutureOr<String?> Function() tokenProvider,
  required Future<void> Function() onConnected,
});

final socketMessageServiceFactoryProvider =
    Provider<SocketMessageServiceFactory>((ref) => SocketMessageService.new);
