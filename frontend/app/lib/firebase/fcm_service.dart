// file: lib/firebase/fcm_service.dart

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// 포어그라운드 메시지 수신 시 → 로컬 알림 표시 + ChatRoomNotifier 업데이트
  void setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // 1) 콘솔 디버그
      print('포어그라운드 알림 수신: '
          '${message.notification?.title}, ${message.notification?.body}');

      // 2) 로컬 알림 (안드로이드)
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

      // 3) notification.body (JSON) 파싱 → ChatRoomNotifier 반영
      final bodyString = message.notification?.body;
      if (bodyString == null || bodyString.isEmpty) {
        print('알림 body가 비어있어 처리하지 않음.');
        return;
      }

      try {
        // 최상위 JSON: {"type":"stream","data":{...}}
        final raw = jsonDecode(bodyString) as Map<String, dynamic>;
        print('★ FCM body JSON 파싱 성공: $raw');

        // ★ "data" 필드를 먼저 꺼낸다
        final dataMap = raw['data'] as Map<String, dynamic>?;
        if (dataMap == null) {
          print('★ data 필드가 없습니다. 메시지 정보를 파싱할 수 없음.');
          return;
        }

        // dataMap 안에 "stream_id", "content", "date_sent" 등이 들어있음
        final streamId = (dataMap['stream_id'] as int?) ?? 0;
        final contentRaw = dataMap['content'];
        final dateSentRaw = dataMap['date_sent'];

        // 숫자든 문자열이든 toString()으로 문자열화
        final content = contentRaw?.toString() ?? '';
        final dateSent = dateSentRaw?.toString() ?? '';

        // ChatRoomNotifier 호출
        ref.read(chatRoomNotifierProvider.notifier).handleIncomingMessage(
          streamId: streamId,
          content: content,
          dateSent: dateSent,
        );

        print('★ handleIncomingMessage: $streamId, $content, $dateSent');
      } catch (e) {
        print('★ notification.body JSON 파싱 오류: $e');
      }
    });
  }


  /// 백그라운드 메시지 핸들러 등록 (top-level 함수 넘겨받아 세팅)
  void setupBackgroundHandler(Future<void> Function(RemoteMessage) handler) {
    FirebaseMessaging.onBackgroundMessage(handler);
  }
}
