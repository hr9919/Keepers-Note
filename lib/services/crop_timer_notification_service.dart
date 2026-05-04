import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class CropTimerNotificationService {
  CropTimerNotificationService._();

  static final CropTimerNotificationService instance =
  CropTimerNotificationService._();

  VoidCallback? _onTapCropTimer;

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const int cropProgressNotificationId = 991001;
  static const String _storageKey = 'crop_timer_items';

  Future<void> init({
    VoidCallback? onTapCropTimer,
  }) async {
    if (onTapCropTimer != null) {
      _onTapCropTimer = onTapCropTimer;
    }

    if (_initialized) return;

    tz.initializeTimeZones();

    try {
      final TimezoneInfo timezoneInfo =
      await FlutterTimezone.getLocalTimezone();

      tz.setLocalLocation(
        tz.getLocation(timezoneInfo.identifier),
      );
    } catch (_) {
      tz.setLocalLocation(
        tz.getLocation('Asia/Seoul'),
      );
    }

    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload ?? '';

        if (payload.contains('crop_timer') ||
            payload.contains('crop-timer')) {
          _onTapCropTimer?.call();
        }
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();

      try {
        await androidPlugin?.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('정확 알람 권한 요청 실패 또는 미지원: $e');
      }
    }

    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _initialized = true;
  }

  Future<void> showCropTimerProgressNotification({
    required String cropName,
    required DateTime plantedAt,
    required DateTime harvestAt,
  }) async {
    await init();

    if (!Platform.isAndroid) {
      return;
    }

    final now = DateTime.now();
    final totalSeconds = harvestAt.difference(plantedAt).inSeconds;
    final passedSeconds = now.difference(plantedAt).inSeconds;
    final remain = harvestAt.difference(now);

    final int progress = totalSeconds <= 0
        ? 100
        : ((passedSeconds / totalSeconds) * 100).clamp(0, 100).round();

    String remainText;

    if (remain.isNegative) {
      remainText = '수확 가능';
    } else {
      final int totalMinutes = remain.inSeconds <= 60
          ? 1
          : (remain.inSeconds / 60).ceil();

      final int hours = totalMinutes ~/ 60;
      final int minutes = totalMinutes % 60;

      if (hours > 0 && minutes > 0) {
        remainText = '$hours시간 $minutes분 남음';
      } else if (hours > 0) {
        remainText = '$hours시간 남음';
      } else {
        remainText = '$totalMinutes분 남음';
      }
    }

    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'crop_timer_progress_channel',
      '작물 타이머 진행 상황',
      channelDescription: '진행 중인 작물 타이머를 상단바에 표시합니다.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',
      showWhen: false,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      id: cropProgressNotificationId,
      title: '$cropName 자라는 중',
      body: remainText,
      notificationDetails: details,
      payload: 'keepersnote://crop-timer?target=crop_timer',
    );
  }

  Future<void> cancelCropTimerProgressNotification() async {
    await init();

    await _plugin.cancel(
      id: cropProgressNotificationId,
    );
  }

  Future<void> showCropHarvestDoneNotification({
    required int notificationId,
    required String cropName,
  }) async {
    await init();

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'crop_timer_done_channel',
      '작물 수확 완료',
      channelDescription: '작물 수확 시간이 되었을 때 알려드려요.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      autoCancel: true,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: notificationId,
      title: '$cropName 수확 시간이에요',
      body: '지금 수확하러 가볼까요?',
      notificationDetails: details,
      payload: 'keepersnote://crop-timer?target=crop_timer',
    );
  }

  Future<void> scheduleCropHarvestNotification({
    required int notificationId,
    required String cropName,
    required DateTime harvestAt,
  }) async {
    await init();

    final tz.TZDateTime scheduledAt =
    tz.TZDateTime.from(harvestAt, tz.local);

    if (scheduledAt.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'crop_timer_done_channel',
      '작물 수확 완료',
      channelDescription: '작물 수확 시간이 되었을 때 알려드려요.',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      autoCancel: true,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id: notificationId,
        title: '$cropName 수확 시간이에요',
        body: '지금 수확하러 가볼까요?',
        scheduledDate: scheduledAt,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'keepersnote://crop-timer?target=crop_timer',
      );
    } catch (e) {
      debugPrint('작물 수확 exact 알림 예약 실패: $e');

      await _plugin.zonedSchedule(
        id: notificationId,
        title: '$cropName 수확 시간이에요',
        body: '지금 수확하러 가볼까요?',
        scheduledDate: scheduledAt,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: 'keepersnote://crop-timer?target=crop_timer',
      );
    }
  }

  Future<void> showCropTimerProgressSummaryNotification({
    required List<CropTimerNotificationItem> items,
  }) async {
    await init();

    if (!Platform.isAndroid) {
      return;
    }

    final now = DateTime.now();

    final activeItems = items
        .where((e) => e.harvestAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.harvestAt.compareTo(b.harvestAt));

    if (activeItems.isEmpty) {
      await cancelCropTimerProgressNotification();
      return;
    }

    final next = activeItems.first;

    String formatHarvestTime(DateTime dateTime) {
      final now = DateTime.now();

      final isToday = now.year == dateTime.year &&
          now.month == dateTime.month &&
          now.day == dateTime.day;

      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final isTomorrow = tomorrow.year == dateTime.year &&
          tomorrow.month == dateTime.month &&
          tomorrow.day == dateTime.day;

      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      if (isToday) return '오늘 $hour:$minute 수확';
      if (isTomorrow) return '내일 $hour:$minute 수확';

      return '${dateTime.month}.${dateTime.day} $hour:$minute 수확';
    }

    int progressFor(CropTimerNotificationItem item) {
      final totalSeconds = item.harvestAt.difference(item.plantedAt).inSeconds;
      final passedSeconds = now.difference(item.plantedAt).inSeconds;

      if (totalSeconds <= 0) return 100;

      return ((passedSeconds / totalSeconds) * 100).clamp(0, 100).round();
    }

    final lines = activeItems.take(6).map((item) {
      return '${item.cropName} · ${formatHarvestTime(item.harvestAt)}';
    }).toList();

    if (activeItems.length > 6) {
      lines.add('외 ${activeItems.length - 6}개 더 진행 중');
    }

    final title = activeItems.length == 1
        ? '${next.cropName} 자라는 중'
        : '작물 ${activeItems.length}개 자라는 중';

    final body = activeItems.length == 1
        ? '${next.cropName} 수확 대기 중'
        : '다음 수확: ${next.cropName}';

    final androidDetails = AndroidNotificationDetails(
      'crop_timer_progress_channel',
      '작물 타이머 진행 상황',
      channelDescription: '진행 중인 작물 타이머를 상단바에 표시합니다.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',

      showWhen: false,
      when: next.harvestAt.millisecondsSinceEpoch,
      usesChronometer: true,
      chronometerCountDown: true,

      styleInformation: InboxStyleInformation(
        lines,
        contentTitle: title,
        summaryText: activeItems.length == 1
            ? null
            : '${activeItems.length}개 진행 중',
      ),
    );

    final details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      id: cropProgressNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: 'keepersnote://crop-timer?target=crop_timer',
    );
  }

  Future<void> cancelCropTimer(int notificationId) async {
    await init();

    await _plugin.cancel(
      id: notificationId,
    );
  }

  Future<void> syncCropTimerProgressFromStorage() async {
    await init();

    if (!Platform.isAndroid) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      await cancelCropTimerProgressNotification();
      return;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        await cancelCropTimerProgressNotification();
        return;
      }

      final now = DateTime.now();

      final activeItems = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) {
        final harvestAt = DateTime.tryParse(
          e['harvestAt']?.toString() ?? '',
        );

        return harvestAt != null && harvestAt.isAfter(now);
      })
          .toList()
        ..sort((a, b) {
          final aHarvest = DateTime.tryParse(
            a['harvestAt']?.toString() ?? '',
          ) ??
              now;

          final bHarvest = DateTime.tryParse(
            b['harvestAt']?.toString() ?? '',
          ) ??
              now;

          return aHarvest.compareTo(bHarvest);
        });

      if (activeItems.isEmpty) {
        await cancelCropTimerProgressNotification();
        return;
      }

      final items = activeItems.map((item) {
        final cropName = item['cropName']?.toString() ?? '작물';

        final plantedAt = DateTime.tryParse(
          item['plantedAt']?.toString() ?? '',
        ) ??
            now;

        final harvestAt = DateTime.tryParse(
          item['harvestAt']?.toString() ?? '',
        ) ??
            now;

        return CropTimerNotificationItem(
          cropName: cropName,
          plantedAt: plantedAt,
          harvestAt: harvestAt,
        );
      }).toList();

      await showCropTimerProgressSummaryNotification(
        items: items,
      );
    } catch (_) {
      await cancelCropTimerProgressNotification();
    }
  }
}

class CropTimerNotificationItem {
  final String cropName;
  final DateTime plantedAt;
  final DateTime harvestAt;

  const CropTimerNotificationItem({
    required this.cropName,
    required this.plantedAt,
    required this.harvestAt,
  });
}