import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Quick record (small + lock screen)

struct QuickRecordEntry: TimelineEntry {
    let date: Date
}

struct QuickRecordProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickRecordEntry {
        QuickRecordEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickRecordEntry) -> Void) {
        completion(QuickRecordEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickRecordEntry>) -> Void) {
        let entry = QuickRecordEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct QuickRecordWidget: Widget {
    let kind = "QuickRecordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickRecordProvider()) { entry in
            QuickRecordWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("widget.quick_record.title"))
        .description(LocalizedStringResource("widget.quick_record.description"))
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct QuickRecordWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: QuickRecordEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Button(intent: StartVoiceRecordingIntent()) {
                    Image(systemName: "mic.fill")
                }
                .buttonStyle(.plain)
            default:
                Button(intent: StartVoiceRecordingIntent()) {
                    ZStack {
                        ContainerRelativeShape()
                            .fill(Color.accentColor.opacity(0.38))
                        VStack(spacing: 6) {
                            Image(systemName: "mic.fill")
                                .font(.title2)
                            Text(L10n.string("widget.record_button"))
                                .font(.caption2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Current session (medium; session title via App Group — pending task)

struct SessionEntry: TimelineEntry {
    let date: Date
}

struct SessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> SessionEntry {
        SessionEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SessionEntry) -> Void) {
        completion(SessionEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SessionEntry>) -> Void) {
        let entry = SessionEntry(date: Date())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct CurrentSessionWidget: Widget {
    let kind = "CurrentSessionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SessionProvider()) { entry in
            SessionWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringResource("widget.current_session.title"))
        .description(LocalizedStringResource("widget.current_session.description"))
        .supportedFamilies([.systemMedium])
    }
}

struct SessionWidgetEntryView: View {
    var entry: SessionEntry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Demo session")
                    .font(.headline)
                Text("Last reply: open the app to chat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button(intent: StartVoiceRecordingIntent()) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 36))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

@main
struct KnowledgeBaseWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickRecordWidget()
        CurrentSessionWidget()
    }
}
