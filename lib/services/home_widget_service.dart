import 'dart:io';
import 'package:home_widget/home_widget.dart';

class KeepersHomeWidgetService {
  static const String _androidWidgetName = 'TodayInfoWidgetProvider';

  // iOS에서 Runner/Widget Extension에 동일하게 넣은 App Group 값으로 바꿔야 함
  static const String _iOSAppGroupId = 'group.com.townhelpers.keepers_note';

  static bool _isInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(_iOSAppGroupId);
    }

    _isInitialized = true;
  }

  static Future<void> saveAndRefresh({
    required String weather,
    required String oakText,
    required String fluoriteText,
    required String updatedAt,
    required bool oakVerified,
    required bool fluoriteVerified,
    required String voterId,
    required List<Map<String, String>> hourlyWeather,
  }) async {
    await _ensureInitialized();

    await HomeWidget.saveWidgetData<String>('weather', weather);
    await HomeWidget.saveWidgetData<String>('oak_text', oakText);
    await HomeWidget.saveWidgetData<String>('fluorite_text', fluoriteText);
    await HomeWidget.saveWidgetData<String>('updated_at', updatedAt);
    await HomeWidget.saveWidgetData<bool>('oak_verified', oakVerified);
    await HomeWidget.saveWidgetData<bool>('fluorite_verified', fluoriteVerified);
    await HomeWidget.saveWidgetData<String>('voter_id', voterId);

    for (int i = 0; i < 3; i++) {
      final item = i < hourlyWeather.length ? hourlyWeather[i] : const <String, String>{};

      await HomeWidget.saveWidgetData<String>(
        'hourly_${i}_time',
        item['time'] ?? '-',
      );
      await HomeWidget.saveWidgetData<String>(
        'hourly_${i}_weather',
        item['weather'] ?? '-',
      );
    }

    await HomeWidget.updateWidget(
      androidName: _androidWidgetName,
    );
  }
}