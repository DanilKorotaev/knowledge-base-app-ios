//
//  UserDefaultsAddView.swift
//  KnowledgeBaseApp
//
//  Created by danil.korotaev on 15.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import SwiftUI


struct UserDefaultsAddView: View {
    @SwiftUI.Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ViewModel

    init() {
        _viewModel = StateObject(wrappedValue: ViewModel())
    }

    var body: some View {
        Form {
            keyInputSection
            valueTypeSection
            valueInputSection
            saveSection
        }
        .navigationTitle("ud.add_key_title")
        .navigationBarTitleDisplayMode(.inline)
        .kbErrorAlert(error: $viewModel.error)
        .kbSuccessAlert(isPresented: $viewModel.success, title: L10n.string("ud.value_saved"))
        .onChange(of: viewModel.success) { success in
            if success {
                dismiss()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userDefaultsInspectorDidChange)) { notification in
            let changedKey = notification.userInfo?[UserDefaultsInspectorNotificationKeys.key] as? String
            viewModel.handleExternalChange(changedKey: changedKey)
        }
    }

    // MARK: - Key Input

    private var keyInputSection: some View {
        Section(header: Text("ud.key_section")) {
            Picker("ud.input_mode", selection: $viewModel.keyInputMode) {
                ForEach(KeyInputMode.allCases) {
                    Text($0.title).tag($0)
                }
            }
            .pickerStyle(.segmented)

            switch viewModel.keyInputMode {
            case .registry:
                NavigationLink(
                    destination: UserDefaultsRegistryKeySelectionView(
                        selectedKey: $viewModel.selectedRegistryKey,
                        groupedKeys: viewModel.groupedKeys
                    )
                ) {
                    HStack {
                        Text("ud.field.key")
                        Spacer()
                        Text(viewModel.selectedRegistryKey?.key.rawValue ?? L10n.string("ud.select_a_key"))
                            .foregroundColor(
                                viewModel.selectedRegistryKey == nil
                                ? Color.secondary
                                : Color.primary
                            )
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            case .manual:
                TextField("ud.enter_key", text: $viewModel.manualKey)
                    .autocapitalization(.none)
                    .keyboardType(.asciiCapable)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            if let selected = viewModel.selectedRegistryKey, viewModel.keyInputMode == .registry {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selected.key.rawValue)
                        .font(.caption)
                        .foregroundColor(Color.primary)
                    Text(selected.description)
                        .font(.caption2)
                        .foregroundColor(Color.secondary)
                }
            }
        }
    }

    // MARK: - Value Type

    private var valueTypeSection: some View {
        Section(header: Text("ud.type_section")) {
            Picker("ud.value_type", selection: $viewModel.valueType) {
                ForEach(UserDefaultsValueType.addableCases) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Value Input

    @ViewBuilder
    private var valueInputSection: some View {
        Section(header: Text("ud.value_section")) {
            switch viewModel.valueType {
            case .bool:
                Toggle("ud.value_section", isOn: $viewModel.boolValue)
            case .string:
                TextField("ud.enter_value", text: $viewModel.stringValue)
                    .autocapitalization(.none)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            case .integer, .double:
                TextField("ud.enter_number", text: $viewModel.stringValue)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            case .date:
                DatePicker("ud.value_section", selection: $viewModel.dateValue)
            case .json:
                TextEditor(text: $viewModel.stringValue)
                    .frame(minHeight: 80)
                    .cornerRadius(8.0)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    .autocapitalization(.none)
            case .data, .unknown:
                Text("ud.type_not_creatable")
                    .foregroundColor(Color.secondary)
            }
        }
    }

    // MARK: - Save

    private var saveSection: some View {
        Section {
            Button(action: viewModel.didSaveActionRequested) {
                Text("common.save")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.canSave)
        }
    }
}
