import SwiftUI

struct LoginView: View {
    @Bindable private var session = AuthSessionStore.shared
    /// Prefer saved URL; otherwise staging so one TestFlight build can validate multi-user without xcconfig secrets.
    @State private var serverURL: String = AppConfiguration.string(for: AppConfiguration.Keys.apiBaseURL)
        ?? "https://kbapp-staging.coredan.ru"
    @State private var login = ""
    @State private var password = ""
    @State private var email = ""
    @State private var mode: Mode = .signIn
    @State private var openSignup = false
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var showChangePassword = false

    private enum Mode: String, CaseIterable {
        case signIn
        case register
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("auth.server_url", text: $serverURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("auth.server_url")
                } header: {
                    Text("auth.server_section")
                } footer: {
                    Text("auth.server_footer")
                }

                if openSignup {
                    Section {
                        Picker("auth.mode", selection: $mode) {
                            Text("auth.sign_in").tag(Mode.signIn)
                            Text("auth.register").tag(Mode.register)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("auth.mode")
                    }
                }

                Section {
                    TextField("auth.login", text: $login)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("auth.login")
                    SecureField("auth.password", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)
                        .accessibilityIdentifier("auth.password")
                    if mode == .register {
                        TextField("auth.email_optional", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("auth.email")
                    }
                } header: {
                    Text(mode == .register ? "auth.register" : "auth.sign_in")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityIdentifier("auth.error")
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isBusy {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(mode == .register ? "auth.create_account" : "auth.sign_in")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isBusy || !canSubmit)
                    .accessibilityIdentifier("auth.submit")
                }
            }
            .navigationTitle("auth.title")
            .task {
                await refreshSignupStatus()
            }
            .onChange(of: serverURL) { _, _ in
                Task { await refreshSignupStatus() }
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView {
                    showChangePassword = false
                }
            }
        }
    }

    private var canSubmit: Bool {
        let urlOK = normalizedBaseURL() != nil
        let loginOK = login.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1
        let passOK = password.count >= (mode == .register ? 8 : 1)
        return urlOK && loginOK && passOK
    }

    private func normalizedBaseURL() -> URL? {
        var raw = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        if !raw.contains("://") {
            raw = "https://\(raw)"
        }
        while raw.hasSuffix("/") {
            raw.removeLast()
        }
        return URL(string: raw)
    }

    private func refreshSignupStatus() async {
        guard let base = normalizedBaseURL() else {
            openSignup = false
            return
        }
        let client = URLSessionAuthAPIClient(baseURL: base)
        do {
            let status = try await client.signupStatus()
            openSignup = status.openSignup
            if !status.openSignup {
                mode = .signIn
            }
        } catch {
            openSignup = false
            mode = .signIn
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard let base = normalizedBaseURL() else {
            errorMessage = String(localized: "auth.error_bad_url")
            return
        }
        AppConfiguration.setUserString(base.absoluteString, for: AppConfiguration.Keys.apiBaseURL)
        let client = URLSessionAuthAPIClient(baseURL: base)
        let trimmedLogin = login.trimmingCharacters(in: .whitespacesAndNewlines)
        isBusy = true
        defer { isBusy = false }
        do {
            let tokens: AuthTokenResponse
            if mode == .register {
                tokens = try await client.register(
                    login: trimmedLogin,
                    password: password,
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
            } else {
                tokens = try await client.login(login: trimmedLogin, password: password)
            }
            session.apply(tokens: tokens)
            if tokens.user.mustChangePassword {
                showChangePassword = true
            }
        } catch let error as AuthAPIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview {
    LoginView()
}
