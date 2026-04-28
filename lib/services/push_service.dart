import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

    if (!enabled) return;
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
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;

          final uri = Uri.tryParse(payload);
          if (uri == null) return;

          final data = _dataFromDeepLink(uri);

          await onRealtimeNotificationRefresh();
          await onTapNavigate(data);
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
      await onRealtimeNotificationRefresh();
      await _showLocalNotification(message);
    });
  }

  Uri? _deepLinkFromPushData(Map<String, dynamic> data) {
    final String rawTarget = data['target']?.toString() ?? '';
    final String rawType = data['type']?.toString() ?? '';

    final bool isCommunityType =
        rawType == 'comment' || rawType == 'reply' || rawType == 'like';

    final String target = rawTarget.isNotEmpty
        ? rawTarget
        : isCommunityType
        ? 'community_post'
        : rawType;

    if (target == 'community_post') {
      final String postId =
          (data['postId'] ?? data['targetId'] ?? data['targetPostId'])
              ?.toString() ??
              '';

      if (postId.isEmpty) return null;

      final String commentId =
          (data['commentId'] ??
              data['targetCommentId'] ??
              data['target_comment_id'])
              ?.toString() ??
              '';

      final String notificationId =
          data['notificationId']?.toString() ?? data['id']?.toString() ?? '';

      final query = <String, String>{
        'target': 'community_post',
        'postId': postId,
      };

      if (commentId.isNotEmpty) {
        query['commentId'] = commentId;
      }

      if (notificationId.isNotEmpty) {
        query['notificationId'] = notificationId;
      }

      return Uri.https('keepersnote.app', '/community/post/$postId', query);
    }

    if (target == 'event') {
      final String eventId = data['eventId']?.toString() ?? '';
      if (eventId.isEmpty) return null;

      return Uri.https('keepersnote.app', '/event/$eventId', {
        'target': 'event',
        'eventId': eventId,
      });
    }

    if (target == 'uid_request' ||
        target == 'uid_rejected' ||
        target == 'uid_approved') {
      return Uri(
        scheme: 'keepersnote',
        host: 'community',
        queryParameters: {'target': target},
      );
    }

    return null;
  }

  Map<String, dynamic> _dataFromDeepLink(Uri uri) {
    final params = uri.queryParameters;

    if (params['target'] == 'community_post') {
      return {
        'target': 'community_post',
        'type': 'comment',
        'postId': params['postId'],
        'targetId': params['postId'],
        'commentId': params['commentId'],
        'targetCommentId': params['commentId'],
        'notificationId': params['notificationId'],
      };
    }

    if (params['target'] == 'event') {
      return {
        'target': 'event',
        'eventId': params['eventId'],
      };
    }

    return Map<String, dynamic>.from(params);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
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

    final deepLink = _deepLinkFromPushData(message.data);

    await _localNotifications.show(
      title.hashCode,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: deepLink?.toString(),
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
      final token = await _getSafeFcmToken();
      if (token != null) {
        await _registerToken(userId: userId, token: token);
      }
      return;
    }

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
    await http.post(
      Uri.parse('$_baseUrl/api/push/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': int.tryParse(userId),
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      }),
    );
  }
}