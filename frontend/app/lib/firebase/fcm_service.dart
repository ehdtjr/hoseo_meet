// file: lib/firebase/fcm_service.dart

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
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
    print('iOS 알림 권한: ${settings.authorizationStatus}');

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // (1) 콘솔 디버그
      print('포어그라운드 알림 수신: '
          '${message.notification?.title}, ${message.notification?.body}');

      // (2) 로컬 알림 (Android 예시)
      const androidDetails = AndroidNotificationDetails(
        'my_channel_id',
        '포어그라운드 알림 채널',
        importance: Importance.max,
        priority: Priority.high,
      );
      const notiDetails = NotificationDetails(android: androidDetails);

      await localNotificationsPlugin.show(
        0,
        message.notification?.title ?? 'No title',
        message.notification?.body ?? 'No body',
        notiDetails,
        payload: 'foreground msg',
      );

      // (3) notification.body 파싱 → ChatRoomNotifier 반영
      final bodyString = message.notification?.body;
      if (bodyString == null || bodyString.isEmpty) {
        print('알림 body가 비어있어 처리하지 않음.');
        return;
      }

      try {
        // 3-1) 최상위 JSON 파싱
        // 예: {"type":"stream","data":"{\"id\":3003, ... }"}
        final raw = jsonDecode(bodyString);

        // raw가 Map 형태인지 확인
        if (raw is Map<String, dynamic>) {
          final dataField = raw['data'];

          // data 필드가 문자열이라면, 한 번 더 jsonDecode
          if (dataField is String) {
            // 3-2) 이중 파싱
            final dataMap = jsonDecode(dataField);
            if (dataMap is Map<String, dynamic>) {
              final chatMessage = ChatMessage.fromJson(dataMap);
              print('★ 파싱된 ChatMessage: $chatMessage');

              // ChatRoomNotifier(예시)로 메시지 전달
              ref.read(chatRoomNotifierProvider.notifier).handleIncomingMessage(
                  newMessage: chatMessage);
            } else {
              print('★ data 필드를 decode했지만 Map이 아님. dataMap=$dataMap');
            }
          }
          // 만약 백엔드가 data를 바로 Map으로 준다면(이중 구조 아님)
          else if (dataField is Map<String, dynamic>) {
            final chatMessage = ChatMessage.fromJson(dataField);
            print('★ 파싱된 ChatMessage(이중 JSON 아님): $chatMessage');

            ref.read(chatRoomNotifierProvider.notifier).handleIncomingMessage(
                newMessage: chatMessage);
          } else {
            print('★ data 필드가 Map도 아니고 String도 아님. data=$dataField');
          }
        } else {
          print('★ raw(최상위)가 Map이 아님: $raw');
        }
      } catch (e, stack) {
        print('★ notification.body JSON 파싱 오류: $e\n$stack');
      }
    });
  }

  /// 백그라운드 메시지 핸들러 등록 (top-level 함수 넘겨받아 세팅)
  void setupBackgroundHandler(Future<void> Function(RemoteMessage) handler){
    FirebaseMessaging.onBackgroundMessage(handler);
  }

}