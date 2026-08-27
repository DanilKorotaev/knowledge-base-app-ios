//
//  UserDefaultsInspectorSettingsView.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 18.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import SwiftUI


struct UserDefaultsInspectorSettingsView: View {
    @StateObject
    private var viewModel = ViewModel()

    var body: some View {
        List {
            Section(
                header: Text("ud.logging"),
                footer: Text("ud.verbose_restart_footer")
            ) {
                Toggle("ud.enabled", isOn: $viewModel.isLoggingEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))

                Toggle("ud.verbose_logs", isOn: $viewModel.isVerboseLoggingEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
            }

            Section(header: Text("ud.ignore_keys")) {
                HStack(spacing: 8) {
                    TextField("ud.enter_full_key", text: $viewModel.draftIgnoredKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("ud.add") {
                        viewModel.addDraftIgnoredKey()
                    }
                    .disabled(viewModel.canAddDraftIgnoredKey == false)
                }

                ForEach(viewModel.ignoredKeys, id: \.self) { key in
                    Text(key)
                        .lineLimit(2)
                }
                .onDelete(perform: viewModel.deleteIgnoredKeys)
            }
        }
        .navigationTitle("ud.settings_title")
    }
}
