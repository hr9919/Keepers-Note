import WidgetKit
import SwiftUI

private let appGroupId = "group.com.townhelpers.keepersnote"
private let baseUrl = "https://api.keepers-note.o-r.kr"

struct KeepersTodayInfoEntry: TimelineEntry {
    let date: Date
    let weather: String
    let hourly: [(time: String, weather: String)]
    let fluoriteText: String
    let oakText: String
    let updatedAt: String
}

struct KeepersTodayInfoProvider: TimelineProvider {
    func placeholder(in context: Context) -> KeepersTodayInfoEntry {
        KeepersTodayInfoEntry(
            date: Date(),
            weather: "맑음",
            hourly: [
                ("09시", "맑음"),
                ("12시", "흐림"),
                ("15시", "비")
            ],
            fluoriteText: "위치 확인 중",
            oakText: "위치 확인 중",
            updatedAt: "방금"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (KeepersTodayInfoEntry) -> Void) {
        completion(loadCachedEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeepersTodayInfoEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func fetchEntry() async -> KeepersTodayInfoEntry {
        async let weatherInfo = fetchWeatherInfo()
        async let mapInfo = fetchMapInfo()

        let weather = await weatherInfo
        let map = await mapInfo

        let entry = KeepersTodayInfoEntry(
            date: Date(),
            weather: weather.currentWeather,
            hourly: weather.hourly,
            fluoriteText: map.fluoriteText,
            oakText: map.oakText,
            updatedAt: nowLabel()
        )

        saveCache(entry)
        return entry
    }

    private func loadCachedEntry() -> KeepersTodayInfoEntry {
        let defaults = UserDefaults(suiteName: appGroupId)

        let weather = defaults?.string(forKey: "weather") ?? "맑음"
        let fluorite = defaults?.string(forKey: "fluorite_text") ?? "위치 확인 중"
        let oak = defaults?.string(forKey: "oak_text") ?? "위치 확인 중"

        let h0Time = defaults?.string(forKey: "hourly_0_time") ?? "-"
        let h0Weather = defaults?.string(forKey: "hourly_0_weather") ?? "-"
        let h1Time = defaults?.string(forKey: "hourly_1_time") ?? "-"
        let h1Weather = defaults?.string(forKey: "hourly_1_weather") ?? "-"
        let h2Time = defaults?.string(forKey: "hourly_2_time") ?? "-"
        let h2Weather = defaults?.string(forKey: "hourly_2_weather") ?? "-"
        let updatedAt = defaults?.string(forKey: "updated_at") ?? "방금"

        return KeepersTodayInfoEntry(
            date: Date(),
            weather: weather,
            hourly: [
                (h0Time, h0Weather),
                (h1Time, h1Weather),
                (h2Time, h2Weather)
            ],
            fluoriteText: fluorite,
            oakText: oak,
            updatedAt: updatedAt
        )
    }

    private func saveCache(_ entry: KeepersTodayInfoEntry) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }

        defaults.set(entry.weather, forKey: "weather")
        defaults.set(entry.fluoriteText, forKey: "fluorite_text")
        defaults.set(entry.oakText, forKey: "oak_text")
        defaults.set(entry.updatedAt, forKey: "updated_at")

        defaults.set(entry.hourly[safe: 0]?.time ?? "-", forKey: "hourly_0_time")
        defaults.set(entry.hourly[safe: 0]?.weather ?? "-", forKey: "hourly_0_weather")
        defaults.set(entry.hourly[safe: 1]?.time ?? "-", forKey: "hourly_1_time")
        defaults.set(entry.hourly[safe: 1]?.weather ?? "-", forKey: "hourly_1_weather")
        defaults.set(entry.hourly[safe: 2]?.time ?? "-", forKey: "hourly_2_time")
        defaults.set(entry.hourly[safe: 2]?.weather ?? "-", forKey: "hourly_2_weather")
    }

    private func fetchWeatherInfo() async -> WeatherInfo {
        guard let url = URL(string: "\(baseUrl)/api/weather/current") else {
            return WeatherInfo(currentWeather: "맑음", hourly: fallbackHourly())
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            let currentWeather = normalizeWeatherLabel(json?["currentWeather"] as? String)

            var allTimeline: [(time: String, weather: String)] = []

            if let timeline = json?["timeline"] as? [[String: Any]] {
                for item in timeline {
                    let time = formatHourlyLabel(item["label"] as? String)
                    let weather = normalizeWeatherLabel(item["weather"] as? String)

                    if time != "-", weather != "-" {
                        allTimeline.append((time, weather))
                    }
                }
            }

            var seenTimes = Set<String>()
            let distinctTimeline = allTimeline.filter { item in
                if seenTimes.contains(item.time) {
                    return false
                }
                seenTimes.insert(item.time)
                return true
            }

            // 핵심: timeline 첫 번째가 현재 날씨 슬롯이면 제외하고 다음 3개만 표시
            var nextHourly = Array(distinctTimeline.dropFirst().prefix(3))

            while nextHourly.count < 3 {
                nextHourly.append(("-", "-"))
            }

            return WeatherInfo(
                currentWeather: currentWeather,
                hourly: nextHourly
            )
        } catch {
            return WeatherInfo(currentWeather: "맑음", hourly: fallbackHourly())
        }
    }

    private func fetchMapInfo() async -> MapInfo {
        let defaults = UserDefaults(suiteName: appGroupId)
        let voterId = defaults?.string(forKey: "voter_id") ?? ""

        var urlString = "\(baseUrl)/api/map/resources"
        if !voterId.isEmpty,
           let encoded = voterId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "?voterId=\(encoded)"
        }

        guard let url = URL(string: urlString) else {
            return MapInfo(oakText: "위치 확인 중", fluoriteText: "위치 확인 중")
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let spawnPoints = json?["spawnPoints"] as? [[String: Any]] ?? []

            var oakText = "위치 확인 중"
            var fluoriteText = "위치 확인 중"
            var oakVerified = false
            var fluoriteVerified = false

            for point in spawnPoints {
                let placeLabel = (point["placeLabel"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let resources = point["resources"] as? [[String: Any]] ?? []

                for resource in resources {
                    let resourceName = resource["resourceName"] as? String ?? ""
                    let isVerified = resource["isVerified"] as? Bool ?? false
                    let isFixed = resource["isFixed"] as? Bool ?? false
                    let isActive = resource["isActive"] as? Bool ?? true

                    if !isActive { continue }

                    if resourceName == "roaming_oak", isVerified || isFixed {
                        oakVerified = true
                        oakText = placeLabel.isEmpty ? "위치 확인 중" : placeLabel
                    }

                    if resourceName == "fluorite", isVerified || isFixed {
                        fluoriteVerified = true
                        fluoriteText = placeLabel.isEmpty ? "위치 확인 중" : placeLabel
                    }
                }
            }

            return MapInfo(
                oakText: oakVerified ? oakText : "위치 확인 중",
                fluoriteText: fluoriteVerified ? fluoriteText : "위치 확인 중"
            )
        } catch {
            return MapInfo(oakText: "위치 확인 중", fluoriteText: "위치 확인 중")
        }
    }

    private func fallbackHourly() -> [(String, String)] {
        [
            ("-", "-"),
            ("-", "-"),
            ("-", "-")
        ]
    }

    private func nowLabel() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: Date())
    }
}

struct WeatherInfo {
    let currentWeather: String
    let hourly: [(time: String, weather: String)]
}

struct MapInfo {
    let oakText: String
    let fluoriteText: String
}

struct KeepersTodayInfoWidgetEntryView: View {
    var entry: KeepersTodayInfoProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if family == .systemSmall {
                smallContent
            } else {
                mediumContent
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            weatherBackground(entry.weather)
        }
        .widgetURL(URL(string: "keepersnote://widget/today-info"))
    }

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(entry.updatedAt)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryTextColor(entry.weather))
                .lineLimit(1)

            HStack(spacing: 8) {
                Text(weatherEmoji(entry.weather))
                    .font(.system(size: 30))

                VStack(alignment: .leading, spacing: 2) {
                    Text("현재 날씨")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(secondaryTextColor(entry.weather))

                    Text(entry.weather)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(primaryTextColor(entry.weather))
                }
            }

            Divider()
                .overlay(secondaryTextColor(entry.weather).opacity(0.35))

            resourceLine(imageName: "ic_widget_fluorite", title: "형광석", value: entry.fluoriteText)
            resourceLine(imageName: "ic_widget_oak", title: "참나무", value: entry.oakText)
        }
    }

    private var mediumContent: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center) {
                    Text("현재 날씨")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(secondaryTextColor(entry.weather))

                    Spacer(minLength: 8)

                    Text(entry.updatedAt)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(secondaryTextColor(entry.weather))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                HStack(spacing: 9) {
                    Text(weatherEmoji(entry.weather))
                        .font(.system(size: 34))

                    Text(entry.weather)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(primaryTextColor(entry.weather))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                HStack(spacing: 13) {
                    ForEach(0..<3, id: \.self) { index in
                        let item = entry.hourly[safe: index] ?? ("-", "-")
                        VStack(spacing: 2) {
                            Text(item.time)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(secondaryTextColor(entry.weather))

                            Text(weatherEmoji(item.weather))
                                .font(.system(size: 18))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                resourceCard(imageName: "ic_widget_fluorite", title: "형광석", value: entry.fluoriteText)
                resourceCard(imageName: "ic_widget_oak", title: "참나무", value: entry.oakText)
            }
            .frame(width: 126)
        }
    }

    private func resourceLine(imageName: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(secondaryTextColor(entry.weather))

            Spacer(minLength: 4)

            Text(normalizePlaceLabel(value))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(primaryTextColor(entry.weather))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func resourceCard(imageName: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(secondaryTextColor(entry.weather))
            }

            Text(normalizePlaceLabel(value))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(primaryTextColor(entry.weather))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(cardOpacity(entry.weather)))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct KeepersTodayInfoWidget: Widget {
    let kind: String = "KeepersTodayInfoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KeepersTodayInfoProvider()) { entry in
            KeepersTodayInfoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("오늘의 자원 정보")
        .description("현재 날씨와 형광석/참나무 위치를 확인해요.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private func normalizeWeatherLabel(_ raw: String?) -> String {
    switch (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines) {
    case "SUNNY", "CLEAR", "맑음":
        return "맑음"
    case "CLOUDY", "OVERCAST", "흐림":
        return "흐림"
    case "RAIN", "비":
        return "비"
    case "SNOW", "눈":
        return "눈"
    case "RAINBOW", "무지개":
        return "무지개"
    case "METEOR_SHOWER", "유성우":
        return "유성우"
    default:
        return raw?.isEmpty == false ? raw! : "맑음"
    }
}

private func formatHourlyLabel(_ raw: String?) -> String {
    let value = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty { return "-" }

    let pattern = #"(\d{1,2}):(\d{2})"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
          let hourRange = Range(match.range(at: 1), in: value) else {
        return value
    }

    let hour = String(value[hourRange]).leftPadded(toLength: 2, withPad: "0")
    return "\(hour)시"
}

private func weatherEmoji(_ weather: String) -> String {
    switch weather.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "맑음":
        return "☀️"
    case "흐림":
        return "☁️"
    case "비":
        return "🌧️"
    case "눈":
        return "❄️"
    case "무지개":
        return "🌈"
    case "유성우":
        return "☄️"
    default:
        return "·"
    }
}

private func normalizePlaceLabel(_ raw: String) -> String {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? "위치 확인 중" : value
}

private func primaryTextColor(_ weather: String) -> Color {
    switch weather {
    case "맑음", "눈", "무지개":
        return Color(red: 0.18, green: 0.23, blue: 0.30)
    default:
        return Color.white
    }
}

private func secondaryTextColor(_ weather: String) -> Color {
    switch weather {
    case "맑음", "눈", "무지개":
        return Color(red: 0.34, green: 0.38, blue: 0.46).opacity(0.88)
    default:
        return Color.white.opacity(0.82)
    }
}

private func cardOpacity(_ weather: String) -> Double {
    switch weather {
    case "맑음", "눈", "무지개":
        return 0.46
    default:
        return 0.18
    }
}

@ViewBuilder
private func weatherBackground(_ weather: String) -> some View {
    switch weather {
    case "맑음":
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#8ED8FF"),
                    Color(hex: "#BEE9FF"),
                    Color(hex: "#EAF8FF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 120, height: 120)
                .offset(x: 90, y: 70)
        }

    case "흐림":
        LinearGradient(
            colors: [
                Color(hex: "#93A4B8"),
                Color(hex: "#6E7F94"),
                Color(hex: "#536273")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

    case "비":
        LinearGradient(
            colors: [
                Color(hex: "#3D5A80"),
                Color(hex: "#2B4162"),
                Color(hex: "#1B2840")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

    case "눈":
        LinearGradient(
            colors: [
                Color(hex: "#A9D0E7"),
                Color(hex: "#8BB7D9"),
                Color(hex: "#6A9CC9")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

    case "무지개":
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#FFC6DA"),
                    Color(hex: "#FFE29A"),
                    Color(hex: "#CDB4FF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(hex: "#B8F2E6").opacity(0.12))
                .frame(width: 105, height: 105)
                .offset(x: 90, y: 58)
        }

    case "유성우":
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#171936"),
                    Color(hex: "#30265C"),
                    Color(hex: "#6A3F7F")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 100, height: 100)
                .offset(x: 92, y: 62)
        }

    default:
        LinearGradient(
            colors: [
                Color(hex: "#8ED8FF"),
                Color(hex: "#BEE9FF"),
                Color(hex: "#EAF8FF")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension String {
    func leftPadded(toLength: Int, withPad pad: String) -> String {
        if count >= toLength { return self }
        return String(repeating: pad, count: toLength - count) + self
    }
}

private extension Color {
    init(hex: String) {
        let cleanedHex = hex
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var int: UInt64 = 0
        Scanner(string: cleanedHex).scanHexInt64(&int)

        let red = Double((int >> 16) & 0xFF) / 255.0
        let green = Double((int >> 8) & 0xFF) / 255.0
        let blue = Double(int & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}