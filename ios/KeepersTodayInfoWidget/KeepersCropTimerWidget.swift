import WidgetKit
import SwiftUI
import AppIntents
import UserNotifications

private let cropTimerAppGroupId = "group.com.townhelpers.keepersnote"
private let cropTimerWidgetKind = "KeepersCropTimerWidget"

struct KeepersCropTimerItem: Codable, Identifiable, Hashable {
    let id: Int
    let cropId: String
    let cropName: String
    let asset: String
    let plantedAt: String
    let harvestAt: String
    let doneNotified: Bool
    let weedAlertEnabled: Bool?
}

struct KeepersCropTimerEntry: TimelineEntry {
    let date: Date
    let items: [KeepersCropTimerItem]
    let updatedAt: String
    let weedAlertEnabled: Bool
}

struct QuickCrop: Identifiable, Hashable {
    let id: String
    let name: String
    let minutes: Int
    let imageName: String
}

private let quickCrops: [QuickCrop] = [
    QuickCrop(id: "tomato", name: "토마토", minutes: 15, imageName: "ic_crop_tomato"),
    QuickCrop(id: "pineapple", name: "파인애플", minutes: 30, imageName: "ic_crop_pineapple"),
    QuickCrop(id: "potato", name: "감자", minutes: 60, imageName: "ic_crop_potato"),
    QuickCrop(id: "carrot", name: "당근", minutes: 120, imageName: "ic_crop_carrot"),
    QuickCrop(id: "wheat", name: "밀", minutes: 240, imageName: "ic_crop_wheat"),
    QuickCrop(id: "strawberry", name: "딸기", minutes: 360, imageName: "ic_crop_strawberry"),
    QuickCrop(id: "eggplant", name: "가지", minutes: 420, imageName: "ic_crop_eggplant"),
    QuickCrop(id: "lettuce", name: "양상추", minutes: 480, imageName: "ic_crop_lettuce"),
    QuickCrop(id: "grape", name: "포도", minutes: 600, imageName: "ic_crop_grape"),
    QuickCrop(id: "corn", name: "옥수수", minutes: 720, imageName: "ic_crop_corn")
]

enum KeepersCropTimerStore {
    private static let itemsKey = "crop_timer_widget_items"
    private static let updatedAtKey = "crop_timer_widget_updated_at"
    private static let weedAlertKey = "crop_timer_widget_weed_alert_enabled"

    static func loadItems() -> [KeepersCropTimerItem] {
        guard
            let defaults = UserDefaults(suiteName: cropTimerAppGroupId),
            let json = defaults.string(forKey: itemsKey),
            let data = json.data(using: .utf8)
        else {
            return []
        }

        return (try? JSONDecoder().decode([KeepersCropTimerItem].self, from: data)) ?? []
    }

    static func saveItems(_ items: [KeepersCropTimerItem]) {
        guard let defaults = UserDefaults(suiteName: cropTimerAppGroupId) else { return }

        if let data = try? JSONEncoder().encode(items),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: itemsKey)
        }

        defaults.set(nowLabel(), forKey: updatedAtKey)
    }

    static func isWeedAlertEnabled() -> Bool {
        let defaults = UserDefaults(suiteName: cropTimerAppGroupId)
        return defaults?.bool(forKey: weedAlertKey) ?? false
    }

    static func setWeedAlertEnabled(_ enabled: Bool) {
        UserDefaults(suiteName: cropTimerAppGroupId)?.set(enabled, forKey: weedAlertKey)
    }

    static func toggleWeedAlertEnabled() -> Bool {
        let next = !isWeedAlertEnabled()
        setWeedAlertEnabled(next)
        return next
    }

    static func startTimer(
        cropId: String,
        cropName: String,
        minutes: Int
    ) -> KeepersCropTimerItem {
        var items = loadItems()

        let now = Date()
        let harvestAt = now.addingTimeInterval(TimeInterval(minutes * 60))
        let id = Int(now.timeIntervalSince1970 * 1000) % 2147483647
        let weedEnabled = isWeedAlertEnabled()

        let item = KeepersCropTimerItem(
            id: id,
            cropId: cropId,
            cropName: cropName,
            asset: "",
            plantedAt: isoString(now),
            harvestAt: isoString(harvestAt),
            doneNotified: false,
            weedAlertEnabled: weedEnabled
        )

        items.append(item)
        items.sort { a, b in
            parseDate(a.harvestAt) < parseDate(b.harvestAt)
        }

        saveItems(items)
        return item
    }

    static func updatedAt() -> String {
        let defaults = UserDefaults(suiteName: cropTimerAppGroupId)
        return defaults?.string(forKey: updatedAtKey) ?? nowLabel()
    }

    static func nowLabel() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

struct StartCropTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "작물 타이머 시작"

    @Parameter(title: "작물 ID")
    var cropId: String

    @Parameter(title: "작물 이름")
    var cropName: String

    @Parameter(title: "재배 시간")
    var minutes: Int

    init() {}

    init(cropId: String, cropName: String, minutes: Int) {
        self.cropId = cropId
        self.cropName = cropName
        self.minutes = minutes
    }

    func perform() async throws -> some IntentResult {
        let item = KeepersCropTimerStore.startTimer(
            cropId: cropId,
            cropName: cropName,
            minutes: minutes
        )

        await scheduleCropDoneNotification(
            notificationId: item.id,
            cropName: cropName,
            minutes: minutes
        )

        if item.weedAlertEnabled == true {
            await scheduleWeedNotifications(
                notificationId: item.id,
                minutes: minutes
            )
        }

        WidgetCenter.shared.reloadTimelines(ofKind: cropTimerWidgetKind)

        return .result()
    }

    private func scheduleCropDoneNotification(
        notificationId: Int,
        cropName: String,
        minutes: Int
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "\(cropName) 수확 시간이에요"
        content.body = "지금 수확하러 가볼까요?"
        content.sound = .default
        content.userInfo = [
            "target": "crop_timer"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(1, minutes * 60)),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(notificationId)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // 위젯 액션에서는 알림 예약 실패가 UI를 막지 않게 함
        }
    }

    private func weedNotificationId(_ timerId: Int, _ stage: Int) -> Int {
        return ((timerId % 200000000) * 10) + stage
    }

    private func scheduleWeedNotifications(
        notificationId: Int,
        minutes: Int
    ) async {
        let totalSeconds = max(1, minutes * 60)

        let intervals = [
            max(1, totalSeconds / 3),
            max(1, (totalSeconds * 2) / 3),
            max(1, totalSeconds - 60),
            max(1, totalSeconds + 60)
        ]

        for index in 0..<intervals.count {
            await scheduleWeedNotification(
                notificationId: weedNotificationId(notificationId, index + 1),
                seconds: intervals[index]
            )
        }
    }

    private func scheduleWeedNotification(
        notificationId: Int,
        seconds: Int
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "잡초 확인 시간이에요"
        content.sound = .default
        content.userInfo = [
            "target": "crop_timer"
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(1, seconds)),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "\(notificationId)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // 위젯 액션에서는 알림 예약 실패가 UI를 막지 않게 함
        }
    }
}

struct ToggleCropWeedAlertIntent: AppIntent {
    static var title: LocalizedStringResource = "잡초 알림 받기"

    init() {}

    func perform() async throws -> some IntentResult {
        _ = KeepersCropTimerStore.toggleWeedAlertEnabled()
        WidgetCenter.shared.reloadTimelines(ofKind: cropTimerWidgetKind)
        return .result()
    }
}

struct KeepersCropTimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> KeepersCropTimerEntry {
        KeepersCropTimerEntry(
            date: Date(),
            items: [
                KeepersCropTimerItem(
                    id: 1,
                    cropId: "tomato",
                    cropName: "토마토",
                    asset: "",
                    plantedAt: KeepersCropTimerStore.isoString(Date()),
                    harvestAt: KeepersCropTimerStore.isoString(Date().addingTimeInterval(900)),
                    doneNotified: false,
                    weedAlertEnabled: true
                ),
                KeepersCropTimerItem(
                    id: 2,
                    cropId: "eggplant",
                    cropName: "가지",
                    asset: "",
                    plantedAt: KeepersCropTimerStore.isoString(Date()),
                    harvestAt: KeepersCropTimerStore.isoString(Date().addingTimeInterval(3600)),
                    doneNotified: false,
                    weedAlertEnabled: false
                )
            ],
            updatedAt: "방금",
            weedAlertEnabled: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (KeepersCropTimerEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeepersCropTimerEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)

        completion(
            Timeline(
                entries: [entry],
                policy: .after(nextUpdate)
            )
        )
    }

    private func loadEntry() -> KeepersCropTimerEntry {
        let items = KeepersCropTimerStore.loadItems()
            .sorted { a, b in
                parseDate(a.harvestAt) < parseDate(b.harvestAt)
            }

        return KeepersCropTimerEntry(
            date: Date(),
            items: items,
            updatedAt: KeepersCropTimerStore.updatedAt(),
            weedAlertEnabled: KeepersCropTimerStore.isWeedAlertEnabled()
        )
    }
}

struct KeepersCropTimerWidgetEntryView: View {
    var entry: KeepersCropTimerEntry

    private var activeItems: [KeepersCropTimerItem] {
        entry.items
            .sorted { a, b in
                parseDate(a.harvestAt) < parseDate(b.harvestAt)
            }
            .prefix(3)
            .map { $0 }
    }

    private var doneCount: Int {
        let now = Date()
        return entry.items.filter { parseDate($0.harvestAt) <= now }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            quickStartGrid

            if entry.items.isEmpty {
                emptyCompactView
            } else {
                timerList
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(15)
        .containerBackground(for: .widget) {
            cropTimerBackground
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("작물 타이머")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#2D3436"))

                Text("업데이트 \(entry.updatedAt)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: "#7C8796"))
            }

            Spacer()

            Link(destination: URL(string: "keepersnote://crop-timer?target=crop_timer")!) {
                Text("전체")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#475569"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.58))
                    .clipShape(Capsule())
            }
        }
    }

    private var quickStartGrid: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("빠른 시작")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "#7C8796"))

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
                spacing: 7
            ) {
                ForEach(quickCrops) { crop in
                    Button(
                        intent: StartCropTimerIntent(
                            cropId: crop.id,
                            cropName: crop.name,
                            minutes: crop.minutes
                        )
                    ) {
                        VStack(spacing: 3) {
                            Image(crop.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)

                            Text(shortCropName(crop.name))
                                .font(.system(size: crop.name == "파인애플" ? 7.5 : 8.5, weight: .bold))
                                .foregroundStyle(Color(hex: "#475569"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.62))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            weedAlertToggle
        }
    }

    private var weedAlertToggle: some View {
        Button(intent: ToggleCropWeedAlertIntent()) {
            HStack(spacing: 7) {
                Image(systemName: entry.weedAlertEnabled ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "#FF8E7C"))

                Text("잡초 알림 받기")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#475569"))

                Spacer(minLength: 0)

                Text("5성작용")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "#FF8E7C"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var timerList: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(activeItems) { item in
                timerRow(item)
            }
        }
    }

    private func timerRow(_ item: KeepersCropTimerItem) -> some View {
        let harvestDate = parseDate(item.harvestAt)
        let now = Date()
        let isDone = harvestDate <= now

        return HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#FFF1EC"))
                    .frame(width: 32, height: 32)

                Image(cropImageName(item))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23, height: 23)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.cropName.isEmpty ? "작물" : item.cropName)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(Color(hex: "#2D3436"))
                        .lineLimit(1)

                    if isDone {
                        Text("수확 가능")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Color(hex: "#FF6F61"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#FFF1EC"))
                            .clipShape(Capsule())
                    } else if item.weedAlertEnabled == true {
                        Text("잡초")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Color(hex: "#FF8E7C"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#FFF1EC"))
                            .clipShape(Capsule())
                    }
                }

                Text(isDone ? "지금 수확할 수 있어요" : formatHarvestTime(harvestDate))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isDone ? Color(hex: "#FF6F61") : Color(hex: "#7C8796"))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !isDone {
                Text(formatRemain(harvestDate))
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color(hex: "#FF8E7C"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var emptyCompactView: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "#FF8E7C"))
                .frame(width: 34, height: 34)
                .background(Color(hex: "#FFF1EC"))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("진행 중인 타이머가 없어요")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#2D3436"))

                Text("위 아이콘을 눌러 바로 시작해요")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color(hex: "#7C8796"))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footer: some View {
        HStack {
            let total = entry.items.count

            Text(doneCount > 0 ? "수확 가능 \(doneCount)개" : "총 \(total)개 진행 중")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "#FF8E7C"))

            Spacer()

            Link(destination: URL(string: "keepersnote://crop-timer?target=crop_timer")!) {
                Text("앱에서 보기")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#475569"))
            }
        }
    }

    private var cropTimerBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#FFF1EC"),
                    Color(hex: "#FFF7D8"),
                    Color(hex: "#E7FFF0")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 135, height: 135)
                .offset(x: 94, y: 72)

            Circle()
                .fill(Color(hex: "#B8F2C8").opacity(0.18))
                .frame(width: 92, height: 92)
                .offset(x: -92, y: -64)
        }
    }
}

struct KeepersCropTimerWidget: Widget {
    let kind: String = cropTimerWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KeepersCropTimerProvider()) { entry in
            KeepersCropTimerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("작물 타이머")
        .description("작물 타이머를 빠르게 시작하고 수확 상태를 확인해요.")
        .supportedFamilies([.systemLarge])
    }
}

private func parseDate(_ raw: String) -> Date {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    if value.isEmpty {
        return Date.distantFuture
    }

    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [
        .withInternetDateTime,
        .withFractionalSeconds
    ]

    if let date = isoWithFraction.date(from: value) {
        return date
    }

    let isoDefault = ISO8601DateFormatter()
    isoDefault.formatOptions = [
        .withInternetDateTime
    ]

    if let date = isoDefault.date(from: value) {
        return date
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.timeZone = TimeZone.current

    let formats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss.SSS",
        "yyyy-MM-dd HH:mm:ss"
    ]

    for format in formats {
        formatter.dateFormat = format
        if let date = formatter.date(from: value) {
            return date
        }
    }

    return Date.distantFuture
}

private func formatRemain(_ harvestAt: Date) -> String {
    let diff = Int(harvestAt.timeIntervalSince(Date()))

    if diff <= 0 {
        return "수확 가능"
    }

    let hours = diff / 3600
    let minutes = (diff % 3600) / 60

    if hours > 0 && minutes > 0 {
        return "\(hours)시간 \(minutes)분"
    }

    if hours > 0 {
        return "\(hours)시간"
    }

    let safeMinutes = max(1, minutes)
    return "\(safeMinutes)분"
}

private func formatHarvestTime(_ date: Date) -> String {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "HH:mm"

    let time = formatter.string(from: date)

    if calendar.isDateInToday(date) {
        return "오늘 \(time) 수확"
    }

    if calendar.isDateInTomorrow(date) {
        return "내일 \(time) 수확"
    }

    formatter.dateFormat = "M/d HH:mm"
    return "\(formatter.string(from: date)) 수확"
}

private func shortCropName(_ name: String) -> String {
    return name
}

private func cropImageName(_ item: KeepersCropTimerItem) -> String {
    let cropId = item.cropId
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    switch cropId {
    case "tomato":
        return "ic_crop_tomato"
    case "potato":
        return "ic_crop_potato"
    case "wheat":
        return "ic_crop_wheat"
    case "lettuce":
        return "ic_crop_lettuce"
    case "pineapple":
        return "ic_crop_pineapple"
    case "carrot":
        return "ic_crop_carrot"
    case "strawberry":
        return "ic_crop_strawberry"
    case "corn":
        return "ic_crop_corn"
    case "grape":
        return "ic_crop_grape"
    case "eggplant":
        return "ic_crop_eggplant"
    case "avocado":
        return "ic_crop_avocado"
    case "cocoa-tree", "cocoa_tree":
        return "ic_crop_cocoa_tree"
    case "romaine-lettuce", "romaine_lettuce":
        return "ic_crop_romaine_lettuce"
    case "tea-tree", "tea_tree":
        return "ic_crop_tea_tree"
    case "white-radish", "white_radish":
        return "ic_crop_white_radish"
    default:
        return cropImageNameByKoreanName(item.cropName)
    }
}

private func cropImageNameByKoreanName(_ cropName: String) -> String {
    switch cropName.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "토마토":
        return "ic_crop_tomato"
    case "감자":
        return "ic_crop_potato"
    case "밀":
        return "ic_crop_wheat"
    case "상추", "양상추":
        return "ic_crop_lettuce"
    case "파인애플":
        return "ic_crop_pineapple"
    case "당근":
        return "ic_crop_carrot"
    case "딸기":
        return "ic_crop_strawberry"
    case "옥수수":
        return "ic_crop_corn"
    case "포도":
        return "ic_crop_grape"
    case "가지":
        return "ic_crop_eggplant"
    case "찻잎":
        return "ic_crop_tea_tree"
    case "카카오":
        return "ic_crop_cocoa_tree"
    default:
        return "ic_crop_tomato"
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