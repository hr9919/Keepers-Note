import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PushService {
  static const String _baseUrl = 'https://api.keepers-note.o-r.kr';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  bool _localNotificationInitialized = false;
  bool _initialized = false;

  Future<void> init({
    required String userId,
    required Future<void> Function() onRealtimeNotificationRefresh,
    required Future<void> Function(Map<String, dynamic> data) onTapNavigate,
  }) async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (!_localNotificationInitialized) {
      const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();

      await _localNotifications.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );

      _localNotificationInitialized = true;
    }

    final token = await _messaging.getToken();
    if (token != null && userId.isNotEmpty) {
      await _registerToken(userId: userId, token: token);
    }

    _messaging.onTokenRefresh.listen((token) async {
      if (userId.isNotEmpty) {
        await _registerToken(userId: userId, token: token);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await onRealtimeNotificationRefresh();
      await _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await onRealtimeNotificationRefresh();
      await onTapNavigate(message.data);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await onTapNavigate(initialMessage.data);
    }
  }

  Future<void> _registerToken({
    required String userId,
    required String token,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/push/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': int.tryParse(userId),
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('푸시 토큰 등록 실패: ${response.statusCode} ${response.body}');
    } else {
      debugPrint('푸시 토큰 등록 완료');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'community_channel',
      '커뮤니티 알림',
      channelDescription: '댓글, 좋아요, UID 관련 알림',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }
}