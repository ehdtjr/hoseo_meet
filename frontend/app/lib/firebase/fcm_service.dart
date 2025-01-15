// file: lib/firebase/fcm_service.dart

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hoseomeet/features/chat/data/models/chat_message.dart';

// ChatRoomNotifier Provider import (경로 맞게 수정)
import '../features/chat/providers/chat_room_provicer.dart';

class FcmService {
  final FlutterLocalNotificationsPlugin localNotificationsPlugin;
  final WidgetRef ref;

  FcmService({
    required this.localNotificationsPlugin,
    required this.ref,
  });

  /// iOS 권한 요청 + 포어그라운드 알림 표시
  Future<void> requestIOSPermissions() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('iOS 알림 권한: ${settings.authorizationStatus}');

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      try {
        final rawDataString = message.data['data'];
        if (rawDataString == null) {
          print('★ message.data["data"]가 없습니다. Parsing 중단');
          return;
        }

        final decoded = jsonDecode(rawDataString);
        if (decoded is Map<String, dynamic>) {
          final chatMessage = ChatMessage.fromJson(decoded);
          ref.read(chatRoomNotifierProvider.notifier).handleIncomingMessage(
            newMessage: chatMessage,
          );
        } else {
          print('★ "data" 필드를 decode했지만 Map이 아님. decoded=$decoded');
        }
      } catch (e, stack) {
        print('★ message.data JSON 파싱 오류: $e\n$stack');
      }


    });
  }

  void setupBackgroundHandler(Future<void> Function(RemoteMessage) handler){
    FirebaseMessaging.onBackgroundMessage(handler);
  }

}