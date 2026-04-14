package com.townhelpers.keepers_note

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.concurrent.Executors

class TodayInfoWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            updateAppWidget(context, appWidgetManager, id, widgetData)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_REFRESH_WIDGET -> animateRefreshAndUpdate(context)

            ACTION_AUTO_REFRESH_WIDGET,
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                refreshFromServerAndUpdate(context)
            }
        }
    }

    private fun animateRefreshAndUpdate(context: Context) {
        // 먼저 날씨만 로딩 상태로 바꾸고, 자원 위치는 유지
        renderLoadingState(context)

        val handler = Handler(Looper.getMainLooper())
        val frames = listOf("⟳", "⟲", "⟳", "⟲")

        frames.forEachIndexed { index, frame ->
            handler.postDelayed({
                setRefreshButtonText(context, frame)
            }, index * 120L)
        }

        handler.postDelayed({
            refreshFromServerAndUpdate(context)
        }, 520L)
    }

    private fun refreshFromServerAndUpdate(context: Context) {
        Executors.newSingleThreadExecutor().execute {
            try {
                WidgetUpdateRepository.refreshTodayInfo(context)
            } catch (_: Exception) {
            } finally {
                forceUpdateAll(context)
            }
        }
    }

    companion object {
        const val ACTION_REFRESH_WIDGET =
            "com.townhelpers.keepers_note.ACTION_REFRESH_WIDGET"
        const val ACTION_AUTO_REFRESH_WIDGET =
            "com.townhelpers.keepers_note.ACTION_AUTO_REFRESH_WIDGET"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            prefs: SharedPreferences
        ) {
            val weatherRaw = prefs.getString("weather", "") ?: ""
            val fluorite = prefs.getString("fluorite_text", "위치 확인 중") ?: "위치 확인 중"
            val oak = prefs.getString("oak_text", "위치 확인 중") ?: "위치 확인 중"

            val h0TimeRaw = prefs.getString("hourly_0_time", "") ?: ""
            val h0WeatherRaw = prefs.getString("hourly_0_weather", "") ?: ""
            val h1TimeRaw = prefs.getString("hourly_1_time", "") ?: ""
            val h1WeatherRaw = prefs.getString("hourly_1_weather", "") ?: ""
            val h2TimeRaw = prefs.getString("hourly_2_time", "") ?: ""
            val h2WeatherRaw = prefs.getString("hourly_2_weather", "") ?: ""

            val isLoading = weatherRaw.isBlank()

            val displayWeather = if (isLoading) "로딩중.." else weatherRaw
            val displayWeatherIcon = if (isLoading) "⏳" else getWeatherEmoji(weatherRaw)

            val h0Time = if (h0TimeRaw.isBlank()) "--시" else h0TimeRaw
            val h1Time = if (h1TimeRaw.isBlank()) "--시" else h1TimeRaw
            val h2Time = if (h2TimeRaw.isBlank()) "--시" else h2TimeRaw

            val h0Weather = if (h0WeatherRaw.isBlank()) "·" else getWeatherEmoji(h0WeatherRaw)
            val h1Weather = if (h1WeatherRaw.isBlank()) "·" else getWeatherEmoji(h1WeatherRaw)
            val h2Weather = if (h2WeatherRaw.isBlank()) "·" else getWeatherEmoji(h2WeatherRaw)

            val views = RemoteViews(context.packageName, R.layout.today_info_widget)

            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                getWeatherBackgroundRes(weatherRaw)
            )

            val primaryTextColor = getPrimaryTextColor(weatherRaw)
            val secondaryTextColor = getSecondaryTextColor(weatherRaw)
            val emojiColor = getEmojiColor(weatherRaw)

            views.setTextViewText(R.id.widget_title, "키퍼노트")
            views.setTextColor(R.id.widget_title, secondaryTextColor)

            views.setTextViewText(R.id.widget_weather_text, displayWeather)
            views.setTextColor(R.id.widget_weather_text, primaryTextColor)

            views.setTextViewText(R.id.widget_weather_icon, displayWeatherIcon)
            views.setTextColor(R.id.widget_weather_icon, emojiColor)

            views.setImageViewResource(R.id.widget_fluorite_icon, R.drawable.ic_widget_fluorite)
            views.setTextViewText(R.id.widget_fluorite_label, "형광석")
            views.setTextColor(R.id.widget_fluorite_label, secondaryTextColor)
            views.setTextViewText(R.id.widget_fluorite_value, normalizePlaceLabel(fluorite))
            views.setTextColor(R.id.widget_fluorite_value, primaryTextColor)

            views.setImageViewResource(R.id.widget_oak_icon, R.drawable.ic_widget_oak)
            views.setTextViewText(R.id.widget_oak_label, "참나무")
            views.setTextColor(R.id.widget_oak_label, secondaryTextColor)
            views.setTextViewText(R.id.widget_oak_value, normalizePlaceLabel(oak))
            views.setTextColor(R.id.widget_oak_value, primaryTextColor)

            views.setTextViewText(R.id.widget_hourly_0_time, h0Time)
            views.setTextColor(R.id.widget_hourly_0_time, secondaryTextColor)
            views.setTextViewText(R.id.widget_hourly_0_weather, h0Weather)
            views.setTextColor(R.id.widget_hourly_0_weather, emojiColor)

            views.setTextViewText(R.id.widget_hourly_1_time, h1Time)
            views.setTextColor(R.id.widget_hourly_1_time, secondaryTextColor)
            views.setTextViewText(R.id.widget_hourly_1_weather, h1Weather)
            views.setTextColor(R.id.widget_hourly_1_weather, emojiColor)

            views.setTextViewText(R.id.widget_hourly_2_time, h2Time)
            views.setTextColor(R.id.widget_hourly_2_time, secondaryTextColor)
            views.setTextViewText(R.id.widget_hourly_2_weather, h2Weather)
            views.setTextColor(R.id.widget_hourly_2_weather, emojiColor)

            views.setTextViewText(R.id.widget_refresh_button, "⟳")
            views.setTextColor(R.id.widget_refresh_button, primaryTextColor)

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val openAppPendingIntent = PendingIntent.getActivity(
                    context,
                    1001,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.main_weather, openAppPendingIntent)
                views.setOnClickPendingIntent(R.id.hourly_container, openAppPendingIntent)
                views.setOnClickPendingIntent(R.id.resource_row, openAppPendingIntent)
            }

            val refreshIntent = Intent(context, TodayInfoWidgetProvider::class.java).apply {
                action = ACTION_REFRESH_WIDGET
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                2001,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_refresh_button, refreshPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun forceUpdateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodayInfoWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            val prefs = HomeWidgetPlugin.getData(context)

            ids.forEach { id ->
                updateAppWidget(context, manager, id, prefs)
            }
        }

        fun setRefreshButtonText(context: Context, text: String) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodayInfoWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            val prefs = HomeWidgetPlugin.getData(context)
            val weather = prefs.getString("weather", "") ?: ""

            ids.forEach { id ->
                val views = RemoteViews(context.packageName, R.layout.today_info_widget)
                views.setTextViewText(R.id.widget_refresh_button, text)
                views.setTextColor(R.id.widget_refresh_button, getPrimaryTextColor(weather))
                manager.updateAppWidget(id, views)
            }
        }

        fun renderLoadingState(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodayInfoWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            val prefs = HomeWidgetPlugin.getData(context)

            val fluorite = prefs.getString("fluorite_text", "위치 확인 중") ?: "위치 확인 중"
            val oak = prefs.getString("oak_text", "위치 확인 중") ?: "위치 확인 중"
            val weather = prefs.getString("weather", "") ?: ""

            ids.forEach { id ->
                val views = RemoteViews(context.packageName, R.layout.today_info_widget)

                views.setInt(
                    R.id.widget_root,
                    "setBackgroundResource",
                    getWeatherBackgroundRes(weather)
                )

                val primaryTextColor = getPrimaryTextColor(weather)
                val secondaryTextColor = getSecondaryTextColor(weather)

                views.setTextViewText(R.id.widget_title, "키퍼노트")
                views.setTextColor(R.id.widget_title, secondaryTextColor)

                views.setTextViewText(R.id.widget_weather_text, "로딩중..")
                views.setTextColor(R.id.widget_weather_text, primaryTextColor)

                views.setTextViewText(R.id.widget_weather_icon, "⏳")
                views.setTextColor(R.id.widget_weather_icon, primaryTextColor)

                views.setTextViewText(R.id.widget_hourly_0_time, "--시")
                views.setTextColor(R.id.widget_hourly_0_time, secondaryTextColor)
                views.setTextViewText(R.id.widget_hourly_0_weather, "·")
                views.setTextColor(R.id.widget_hourly_0_weather, primaryTextColor)

                views.setTextViewText(R.id.widget_hourly_1_time, "--시")
                views.setTextColor(R.id.widget_hourly_1_time, secondaryTextColor)
                views.setTextViewText(R.id.widget_hourly_1_weather, "·")
                views.setTextColor(R.id.widget_hourly_1_weather, primaryTextColor)

                views.setTextViewText(R.id.widget_hourly_2_time, "--시")
                views.setTextColor(R.id.widget_hourly_2_time, secondaryTextColor)
                views.setTextViewText(R.id.widget_hourly_2_weather, "·")
                views.setTextColor(R.id.widget_hourly_2_weather, primaryTextColor)

                // 자원 위치는 유지
                views.setTextViewText(R.id.widget_fluorite_value, normalizePlaceLabel(fluorite))
                views.setTextColor(R.id.widget_fluorite_value, primaryTextColor)
                views.setTextViewText(R.id.widget_oak_value, normalizePlaceLabel(oak))
                views.setTextColor(R.id.widget_oak_value, primaryTextColor)

                views.setTextViewText(R.id.widget_refresh_button, "⟳")
                views.setTextColor(R.id.widget_refresh_button, primaryTextColor)

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val openAppPendingIntent = PendingIntent.getActivity(
                        context,
                        1001,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.main_weather, openAppPendingIntent)
                    views.setOnClickPendingIntent(R.id.hourly_container, openAppPendingIntent)
                    views.setOnClickPendingIntent(R.id.resource_row, openAppPendingIntent)
                }

                val refreshIntent = Intent(context, TodayInfoWidgetProvider::class.java).apply {
                    action = ACTION_REFRESH_WIDGET
                }
                val refreshPendingIntent = PendingIntent.getBroadcast(
                    context,
                    2001,
                    refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_refresh_button, refreshPendingIntent)

                manager.updateAppWidget(id, views)
            }
        }

        private fun normalizePlaceLabel(raw: String): String {
            val value = raw.trim()
            return if (value.isEmpty()) "위치 확인 중" else value
        }

        private fun getWeatherEmoji(weather: String): String {
            return when (weather.trim()) {
                "맑음" -> "☀️"
                "흐림" -> "☁️"
                "비" -> "🌧️"
                "눈" -> "❄️"
                "무지개" -> "🌈"
                else -> "·"
            }
        }

        private fun getWeatherBackgroundRes(weather: String): Int {
            return when (weather.trim()) {
                "맑음" -> R.drawable.bg_widget_weather_sunny
                "흐림" -> R.drawable.bg_widget_weather_cloudy
                "비" -> R.drawable.bg_widget_weather_rain
                "눈" -> R.drawable.bg_widget_weather_snow
                "무지개" -> R.drawable.bg_widget_weather_rainbow
                else -> R.drawable.bg_widget_weather_sunny
            }
        }

        private fun getPrimaryTextColor(weather: String): Int {
            return when (weather.trim()) {
                "맑음", "눈" -> Color.parseColor("#E6334155")
                "무지개" -> Color.parseColor("#FF2F3A4D")
                else -> Color.WHITE
            }
        }

        private fun getSecondaryTextColor(weather: String): Int {
            return when (weather.trim()) {
                "맑음", "눈" -> Color.parseColor("#CC475569")
                "무지개" -> Color.parseColor("#E0556275")
                else -> Color.parseColor("#D9FFFFFF")
            }
        }

        private fun getEmojiColor(weather: String): Int {
            return when (weather.trim()) {
                "무지개" -> Color.parseColor("#FF2F3A4D")
                "맑음", "눈" -> Color.parseColor("#E6334155")
                else -> Color.WHITE
            }
        }
    }
}