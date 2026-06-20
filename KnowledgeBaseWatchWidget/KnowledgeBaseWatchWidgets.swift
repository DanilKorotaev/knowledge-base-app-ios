import SwiftUI
import WidgetKit

private let recordDeepLink = URL(string: "knowledgebase://record")!

struct WatchRecordEntry: TimelineEntry {
    let date: Date
}

struct WatchRecordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchRecordEntry {
        WatchRecordEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchRecordEntry) -> Void) {
        completion(WatchRecordEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchRecordEntry>) -> Void) {
        let entry = WatchRecordEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct WatchRecordComplication: Widget {
    let kind = "WatchRecordComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchRecordProvider()) { _ in
            WatchRecordComplicationView()
        }
        .configurationDisplayName("Запись")
        .description("Открыть приложение и начать голосовую запись.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct WatchRecordComplicationView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "mic.fill")
                .font(.title3)
                .widgetAccentable()
        }
        .widgetURL(recordDeepLink)
    }
}

@main
struct KnowledgeBaseWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchRecordComplication()
    }
}
