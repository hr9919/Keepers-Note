import WidgetKit
import SwiftUI
import AppIntents

private let todoAppGroupId = "group.com.townhelpers.keepersnote"
private let todoWidgetKind = "KeepersTodoWidget"

struct KeepersTodoItem: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var done: Bool
    var createdAt: Double
}

struct KeepersTodoEntry: TimelineEntry {
    let date: Date
    let todos: [KeepersTodoItem]
    let updatedAt: String
}

enum KeepersTodoStore {
    private static let todosKey = "keepers_todo_widget_data"
    private static let updatedAtKey = "keepers_todo_updated_at"

    static func loadTodos() -> [KeepersTodoItem] {
        guard
            let defaults = UserDefaults(suiteName: todoAppGroupId),
            let json = defaults.string(forKey: todosKey),
            let data = json.data(using: .utf8)
        else {
            return []
        }

        return (try? JSONDecoder().decode([KeepersTodoItem].self, from: data)) ?? []
    }

    static func saveTodos(_ todos: [KeepersTodoItem]) {
        guard let defaults = UserDefaults(suiteName: todoAppGroupId) else { return }

        if let data = try? JSONEncoder().encode(todos),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: todosKey)
        }

        defaults.set(nowLabel(), forKey: updatedAtKey)
    }

    static func toggleTodo(id: String) {
        var todos = loadTodos()

        guard let index = todos.firstIndex(where: { $0.id == id }) else {
            return
        }

        todos[index].done.toggle()
        saveTodos(todos)
    }

    static func updatedAt() -> String {
        let defaults = UserDefaults(suiteName: todoAppGroupId)
        return defaults?.string(forKey: updatedAtKey) ?? nowLabel()
    }

    static func nowLabel() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
}

struct ToggleKeepersTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "할일 체크"

    @Parameter(title: "Todo ID")
    var todoId: String

    init() {}

    init(todoId: String) {
        self.todoId = todoId
    }

    func perform() async throws -> some IntentResult {
        let oldTodos = KeepersTodoStore.loadTodos()

        KeepersTodoStore.toggleTodo(id: todoId)
        WidgetCenter.shared.reloadTimelines(ofKind: todoWidgetKind)

        guard let url = URL(string: "https://api.keepers-note.o-r.kr/api/todo/toggle/\(todoId)") else {
            return .result()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 8

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            if statusCode < 200 || statusCode >= 300 {
                KeepersTodoStore.saveTodos(oldTodos)
                WidgetCenter.shared.reloadTimelines(ofKind: todoWidgetKind)
            }
        } catch {
            KeepersTodoStore.saveTodos(oldTodos)
            WidgetCenter.shared.reloadTimelines(ofKind: todoWidgetKind)
        }

        return .result()
    }
}

struct KeepersTodoProvider: TimelineProvider {
    func placeholder(in context: Context) -> KeepersTodoEntry {
        KeepersTodoEntry(
            date: Date(),
            todos: [
                KeepersTodoItem(id: "sample_1", title: "작물 수확하기", done: false, createdAt: 1),
                KeepersTodoItem(id: "sample_2", title: "형광석 확인", done: true, createdAt: 2),
                KeepersTodoItem(id: "sample_3", title: "참나무 위치 확인", done: false, createdAt: 3)
            ],
            updatedAt: "방금"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (KeepersTodoEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeepersTodoEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> KeepersTodoEntry {
        let todos = KeepersTodoStore.loadTodos()
            .sorted { a, b in
                a.createdAt < b.createdAt
            }

        return KeepersTodoEntry(
            date: Date(),
            todos: todos,
            updatedAt: KeepersTodoStore.updatedAt()
        )
    }
}

struct KeepersTodoWidgetEntryView: View {
    var entry: KeepersTodoEntry
    @Environment(\.widgetFamily) private var family

   private var visibleTodos: [KeepersTodoItem] {
       Array(entry.todos.prefix(7))
   }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if entry.todos.isEmpty {
                emptyView
            } else {
                todoList
            }

            Spacer(minLength: 0)

            footer
        }
        .padding(16)
        .containerBackground(for: .widget) {
            todoBackground
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("오늘의 할일")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "#2D3436"))

                Text("업데이트 \(entry.updatedAt)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(hex: "#6B7280"))
            }

            Spacer()

            Link(destination: URL(string: "keepersnote://todo/add")!) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 26, height: 26)
                    .background(Color(hex: "#FF8E7C"))
                    .clipShape(Circle())
            }
        }
    }

    private var todoList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(visibleTodos) { todo in
                todoRow(todo)
            }
        }
    }

    @ViewBuilder
    private func todoRow(_ todo: KeepersTodoItem) -> some View {
        let rowContent = HStack(spacing: 8) {
            Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(todo.done ? Color(hex: "#FF8E7C") : Color(hex: "#9CA3AF"))

            Text(todo.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(todo.done ? Color(hex: "#9CA3AF") : Color(hex: "#2D3436"))
                .strikethrough(todo.done, color: Color(hex: "#9CA3AF"))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        if todo.id.hasPrefix("local_default_") {
            rowContent
        } else {
            Button(intent: ToggleKeepersTodoIntent(todoId: todo.id)) {
                rowContent
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("아직 할일이 없어요")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "#2D3436"))

            Text("+ 버튼으로 오늘 할일을 추가해요")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "#6B7280"))
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footer: some View {
        HStack {
            let doneCount = entry.todos.filter { $0.done }.count
            let totalCount = entry.todos.count

            Text("\(doneCount)/\(totalCount) 완료")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "#FF8E7C"))

            Spacer()

            Link(destination: URL(string: "keepersnote://todo")!) {
                Text("전체 보기")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#475569"))
            }
        }
    }

    private var todoBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#FFE7DE"),
                    Color(hex: "#FFF4D8"),
                    Color(hex: "#EAF8FF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 120, height: 120)
                .offset(x: 86, y: 70)
        }
    }
}

struct KeepersTodoWidget: Widget {
    let kind: String = todoWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KeepersTodoProvider()) { entry in
            KeepersTodoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("오늘의 할일")
        .description("오늘의 할일을 확인하고 바로 체크해요.")
        .supportedFamilies([.systemLarge])
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