import AppIntents

/// Shortcuts / Siri phrases for the main app (widget uses the same `StartVoiceRecordingIntent` from `SharedIntents`).
struct KnowledgeBaseAppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartVoiceRecordingIntent(),
            phrases: [
                "Голосовой запрос в \(.applicationName)",
                "Запись в \(.applicationName)",
                "Voice request in \(.applicationName)"
            ],
            shortTitle: "Голос KB",
            systemImageName: "mic.fill"
        )
    }
}
