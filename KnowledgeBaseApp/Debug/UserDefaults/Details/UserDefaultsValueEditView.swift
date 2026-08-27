//
//  UserDefaultsValueEditView.swift
//  KnowledgeBaseApp
//
//  Created by Korotaev Danil on 16.04.2026.
//  Copyright © 2026 allgoritm. All rights reserved.
//

import SwiftUI
import UIKit

struct UserDefaultsValueEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: UserDefaultsDetailView.ViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.valueType == .date {
                DatePicker("ud.value_section", selection: $viewModel.dateValue)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                Spacer(minLength: 0)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .foregroundColor(.clear)
                    TextEditor(text: $viewModel.stringValue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .autocapitalization(.none)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("ud.edit_value")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("ud.update") {
                    viewModel.didUpdateActionRequested()
                }
            }
        }
        .kbErrorAlert(error: $viewModel.error)
        .onChange(of: viewModel.success) { success in
            if success {
                dismiss()
            }
        }
    }
}
