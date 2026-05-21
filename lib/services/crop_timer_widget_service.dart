import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class CropTimerWidgetService {
  static const String _iOSAppGroupId = 'group.com.townhelpers.keepersnote';
  static const String _iOSWidgetName = 'KeepersCropTimerWidget';
  static const String _weedAlertKey = 'crop_timer_widget_weed_alert_enabled';

  static Future<void> _ensureInitialized() async {
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(_iOSAppGroupId);
    }
  }

  static Future<void> saveAndRefreshFromJson(String itemsJson) async {
    await _ensureInitialized();

    debugPrint('🌱 CropTimerWidget save json=$itemsJson');

    await HomeWidget.saveWidgetData<String>(
      'crop_timer_widget_items',
      itemsJson,
    );

    await HomeWidget.saveWidgetData<String>(
      'crop_timer_widget_updated_at',
      _nowLabel(),
    );

    await HomeWidget.updateWidget(
      name: _iOSWidgetName,
      iOSName: _iOSWidgetName,
    );
  }

  static Future<void> saveWeedAlertEnabled(bool enabled) async {
    await _ensureInitialized();

    await HomeWidget.saveWidgetData<bool>(
      _weedAlertKey,
      enabled,
    );

    await HomeWidget.updateWidget(
      name: _iOSWidgetName,
      iOSName: _iOSWidgetName,
    );
  }

  static Future<bool?> loadWeedAlertEnabled() async {
    await _ensureInitialized();

    return HomeWidget.getWidgetData<bool>(
      _weedAlertKey,
      defaultValue: null,
    );
  }

  static Future<void> clearAndRefresh() async {
    await saveAndRefreshFromJson('[]');
  }

  static String _nowLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}