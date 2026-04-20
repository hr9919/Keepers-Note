package com.townhelpers.keepers_note

import android.content.Context
import android.util.Log
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object WidgetUpdateRepository {

    private const val TAG = "WidgetUpdateRepository"
    private const val BASE_URL = "https://api.keepers-note.o-r.kr"

    fun refreshTodayInfo(context: Context) {
        val prefs = HomeWidgetPlugin.getData(context)
        val voterId = prefs.getString("voter_id", "") ?: ""

        val weatherInfo = fetchWeatherInfo()
        val mapInfo = fetchMapInfo(voterId)

        Log.d(
            TAG,
            "refreshTodayInfo: weather=${weatherInfo.currentWeather}, oak=${mapInfo.oakText}, fluorite=${mapInfo.fluoriteText}"
        )

        prefs.edit()
            .putString("weather", weatherInfo.currentWeather)
            .putString("oak_text", mapInfo.oakText)
            .putString("fluorite_text", mapInfo.fluoriteText)
            .putBoolean("oak_verified", mapInfo.oakVerified)
            .putBoolean("fluorite_verified", mapInfo.fluoriteVerified)
            .putString("updated_at", nowLabel())
            .putString("hourly_0_time", weatherInfo.hourly.getOrNull(0)?.first ?: "-")
            .putString("hourly_0_weather", weatherInfo.hourly.getOrNull(0)?.second ?: "-")
            .putString("hourly_1_time", weatherInfo.hourly.getOrNull(1)?.first ?: "-")
            .putString("hourly_1_weather", weatherInfo.hourly.getOrNull(1)?.second ?: "-")
            .putString("hourly_2_time", weatherInfo.hourly.getOrNull(2)?.first ?: "-")
            .putString("hourly_2_weather", weatherInfo.hourly.getOrNull(2)?.second ?: "-")
            .apply()
    }

    private fun fetchWeatherInfo(): WeatherInfo {
        return try {
            val json = getJsonObject("$BASE_URL/api/weather/current")
            val currentWeather =
                normalizeWeatherLabel(json.optString("currentWeather", "맑음"))

            val timeline = json.optJSONArray("timeline")
            val hourly = mutableListOf<Pair<String, String>>()

            if (timeline != null) {
                for (i in 0 until minOf(3, timeline.length())) {
                    val item = timeline.optJSONObject(i) ?: continue
                    val time = formatHourlyLabel(item.optString("label", "-"))
                    val weather = normalizeWeatherLabel(item.optString("weather", "-"))
                    hourly.add(time to weather)
                }
            }

            while (hourly.size < 3) {
                hourly.add("-" to "-")
            }

            WeatherInfo(
                currentWeather = currentWeather,
                hourly = hourly
            )
        } catch (e: Exception) {
            Log.e(TAG, "fetchWeatherInfo failed", e)
            WeatherInfo(
                currentWeather = "맑음",
                hourly = listOf("-" to "-", "-" to "-", "-" to "-")
            )
        }
    }

    private fun fetchMapInfo(voterId: String): MapInfo {
        return try {
            val suffix = if (voterId.isNotBlank()) {
                "?voterId=${URLEncoder.encode(voterId, "UTF-8")}"
            } else {
                ""
            }

            val json = getJsonObject("$BASE_URL/api/map/resources$suffix")
            val spawnPoints = json.optJSONArray("spawnPoints") ?: JSONArray()

            var oakText = "위치 확인 중"
            var fluoriteText = "위치 확인 중"
            var oakVerified = false
            var fluoriteVerified = false

            for (i in 0 until spawnPoints.length()) {
                val point = spawnPoints.optJSONObject(i) ?: continue
                val placeLabel = point.optString("placeLabel", "").trim()
                val resources = point.optJSONArray("resources") ?: JSONArray()

                for (j in 0 until resources.length()) {
                    val r = resources.optJSONObject(j) ?: continue
                    val resourceName = r.optString("resourceName", "")
                    val isVerified = r.optBoolean("isVerified", false)
                    val isFixed = r.optBoolean("isFixed", false)
                    val isActive = r.optBoolean("isActive", true)

                    if (!isActive) continue

                    if (resourceName == "roaming_oak" && (isVerified || isFixed)) {
                        oakVerified = true
                        oakText = placeLabel.ifEmpty { "위치 확인 중" }
                    }

                    if (resourceName == "fluorite" && (isVerified || isFixed)) {
                        fluoriteVerified = true
                        fluoriteText = placeLabel.ifEmpty { "위치 확인 중" }
                    }
                }
            }

            MapInfo(
                oakText = if (oakVerified) oakText else "위치 확인 중",
                fluoriteText = if (fluoriteVerified) fluoriteText else "위치 확인 중",
                oakVerified = oakVerified,
                fluoriteVerified = fluoriteVerified
            )
        } catch (e: Exception) {
            Log.e(TAG, "fetchMapInfo failed", e)
            MapInfo("위치 확인 중", "위치 확인 중", false, false)
        }
    }

    private fun getJsonObject(urlString: String): JSONObject {
        val url = URL(urlString)
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 10000
            readTimeout = 10000
            doInput = true
            useCaches = false
            setRequestProperty("Cache-Control", "no-cache")
            setRequestProperty("Pragma", "no-cache")
        }

        try {
            val code = conn.responseCode
            val stream = if (code in 200..299) {
                BufferedInputStream(conn.inputStream)
            } else {
                BufferedInputStream(conn.errorStream ?: conn.inputStream)
            }

            val text = BufferedReader(InputStreamReader(stream)).use { it.readText() }

            if (code !in 200..299) {
                throw IllegalStateException("HTTP $code from $urlString: $text")
            }

            return JSONObject(text)
        } finally {
            conn.disconnect()
        }
    }

    private fun nowLabel(): String {
        return SimpleDateFormat("MM/dd HH:mm", Locale.getDefault()).format(Date())
    }

    private fun normalizeWeatherLabel(raw: String?): String {
        return when ((raw ?: "").trim()) {
            "SUNNY", "CLEAR", "맑음" -> "맑음"
            "CLOUDY", "OVERCAST", "흐림" -> "흐림"
            "RAIN", "비" -> "비"
            "SNOW", "눈" -> "눈"
            "RAINBOW", "무지개" -> "무지개"
            else -> if (raw.isNullOrBlank()) "맑음" else raw.trim()
        }
    }

    private fun formatHourlyLabel(raw: String?): String {
        val value = (raw ?: "").trim()
        if (value.isEmpty()) return "-"

        val regex = Regex("""(\d{1,2}):(\d{2})""")
        val match = regex.find(value) ?: return value

        val hour = match.groupValues[1].padStart(2, '0')
        return "${hour}시"
    }

    data class WeatherInfo(
        val currentWeather: String,
        val hourly: List<Pair<String, String>>
    )

    data class MapInfo(
        val oakText: String,
        val fluoriteText: String,
        val oakVerified: Boolean,
        val fluoriteVerified: Boolean
    )
}