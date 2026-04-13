package com.townhelpers.keepers_note

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class TodayInfoWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = HomeWidgetPlugin.getData(context)
            val weather = prefs.getString("weather", "맑음") ?: "맑음"
            val oakText = prefs.getString("oak_text", "미확정") ?: "미확정"
            val fluoriteText = prefs.getString("fluorite_text", "미확정") ?: "미확정"
            val updatedAt = prefs.getString("updated_at", "-") ?: "-"

            val views = RemoteViews(context.packageName, R.layout.today_info_widget)
            views.setTextViewText(R.id.widget_weather, "현재 날씨 · $weather")
            views.setTextViewText(R.id.widget_oak, "참나무 · $oakText")
            views.setTextViewText(R.id.widget_fluorite, "형광석 · $fluoriteText")
            views.setTextViewText(R.id.widget_updated_at, "업데이트 $updatedAt")

            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context,
                1001,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun forceUpdateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodayInfoWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            ids.forEach { id ->
                updateAppWidget(context, manager, id)
            }
        }
    }
}
