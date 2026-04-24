import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('push_enabled') ?? true;

    if (!enabled) {
      debugPrint('푸시 OFF 상태 → init 스킵');
      return;
    }

    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
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
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          final payload = response.payload;
          debugPrint('A. onDidReceiveNotificationResponse payload=$payload');

          if (payload == null || payload.isEmpty) return;

          try {
            final Map<String, dynamic> data =
            jsonDecode(payload) as Map<String, dynamic>;
            debugPrint('A-1. 로컬 알림 클릭 data=$data');

            await onRealtimeNotificationRefresh();
            await onTapNavigate(data);
          } catch (e, s) {
            debugPrint('로컬 알림 payload 파싱 실패: $e');
            debugPrint('$s');
          }
        },
      );

      _localNotificationInitialized = true;
    }

    final token = await _getSafeFcmToken();
    if (token != null && userId.isNotEmpty) {
      await _registerToken(userId: userId, token: token);
    }

    _messaging.onTokenRefresh.listen((token) async {
      if (userId.isNotEmpty) {
        await _registerToken(userId: userId, token: token);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('B. onMessage data=${message.data}');
      debugPrint('B-1. onMessage title=${message.notification?.title}');
      debugPrint('B-2. onMessage body=${message.notification?.body}');

      await onRealtimeNotificationRefresh();
      await _showLocalNotification(message);
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];

    if (title == null || body == null) return;

    const androidDetails = AndroidNotificationDetails(
      'community_notifications',
      '커뮤니티 알림',
      channelDescription: '커뮤니티 관련 알림',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    await _localNotifications.show(
      title.hashCode,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<String?> _getSafeFcmToken() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (Platform.isIOS) {
      String? apnsToken = await _messaging.getAPNSToken();

      int retry = 0;
      while (apnsToken == null && retry < 12) {
        await Future.delayed(const Duration(milliseconds: 500));
        apnsToken = await _messaging.getAPNSToken();
        retry++;
      }

      if (apnsToken == null) {
        debugPrint('APNs token 미준비');
        return null;
      }
    }

    return await _messaging.getToken();
  }

  Future<void> setPushEnabled({
    required bool enabled,
    required String userId,
  }) async {
    if (enabled) {
      debugPrint('푸시 ON');

      final token = await _getSafeFcmToken();
      if (token != null) {
        await _registerToken(userId: userId, token: token);
      }
      return;
    }

    debugPrint('푸시 OFF');

    try {
      final existingToken = await _messaging.getToken();
      if (existingToken != null) {
        await http.delete(
          Uri.parse('$_baseUrl/api/push/token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': int.tryParse(userId),
            'token': existingToken,
          }),
        );
      }
    } catch (_) {}

    await _messaging.deleteToken();
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
}