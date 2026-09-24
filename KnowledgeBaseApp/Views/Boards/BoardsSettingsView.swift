import SwiftUI

struct BoardsSettingsView: View {
    @State private var overviewEnabled = BoardsPreferences.isOverviewEnabled

    var body: some View {
        Form {
            Section {
                Toggle("boards.settings.enable", isOn: $overviewEnabled)
                    .onChange(of: overviewEnabled) { _, newValue in
                        BoardsPreferences.isOverviewEnabled = newValue
                    }
            } footer: {
                Text("boards.settings.enable_footer")
            }
        }
        .navigationTitle("boards.settings.title")
    }
}

#Preview {
    NavigationStack {
        BoardsSettingsView()
    }
}
