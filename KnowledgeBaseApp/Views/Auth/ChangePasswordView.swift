import SwiftUI

struct ChangePasswordView: View {
    var onDone: () -> Void

    @Bindable private var session = AuthSessionStore.shared
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if session.mustChangePassword {
                    Section {
                        Text("auth.must_change_password_hint")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        SecureField("auth.current_password", text: $currentPassword)
                            .textContentType(.password)
                    }
                }
                Section {
                    SecureField("auth.new_password", text: $newPassword)
                        .textContentType(.newPassword)
                    SecureField("auth.confirm_password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isBusy {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("auth.change_password")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isBusy || !canSubmit)
                }
            }
            .navigationTitle("auth.change_password")
            .toolbar {
                if !session.mustChangePassword {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { onDone() }
                    }
                }
            }
            .interactiveDismissDisabled(session.mustChangePassword)
        }
    }

    private var canSubmit: Bool {
        newPassword.count >= 8 && newPassword == confirmPassword
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let access = session.accessToken,
              let client = URLSessionAuthAPIClient.makeFromConfiguration()
        else {
            errorMessage = String(localized: "auth.error_bad_url")
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await client.changePassword(
                accessToken: access,
                currentPassword: session.mustChangePassword ? nil : currentPassword,
                newPassword: newPassword
            )
            await session.refreshProfile()
            onDone()
        } catch let error as AuthAPIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
