import 'package:home_widget/home_widget.dart';

class KeepersHomeWidgetService {
  static const String androidProviderName = 'TodayInfoWidgetProvider';
  static const String iOSName = 'TodayInfoWidget';

  static const String keyWeather = 'weather';
  static const String keyOakText = 'oak_text';
  static const String keyFluoriteText = 'fluorite_text';
  static const String keyUpdatedAt = 'updated_at';

  static Future<void> saveTodayInfo({
    required String weather,
    required String oakText,
    required String fluoriteText,
    required String updatedAt,
  }) async {
    await HomeWidget.saveWidgetData<String>(keyWeather, weather);
    await HomeWidget.saveWidgetData<String>(keyOakText, oakText);
    await HomeWidget.saveWidgetData<String>(keyFluoriteText, fluoriteText);
    await HomeWidget.saveWidgetData<String>(keyUpdatedAt, updatedAt);
  }

  static Future<void> updateTodayInfoWidget() async {
    await HomeWidget.updateWidget(
      androidName: androidProviderName,
      iOSName: iOSName,
    );
  }

  static Future<void> saveAndRefresh({
    required String weather,
    required String oakText,
    required String fluoriteText,
    required String updatedAt,
  }) async {
    await saveTodayInfo(
      weather: weather,
      oakText: oakText,
      fluoriteText: fluoriteText,
      updatedAt: updatedAt,
    );
    await updateTodayInfoWidget();
  }
}