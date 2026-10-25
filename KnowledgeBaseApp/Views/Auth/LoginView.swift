import SwiftUI

/// Nextcloud-inspired onboarding: server address first → probe → credentials.
struct LoginView: View {
    private enum Step: Equatable {
        case server
        case credentials
    }

    @Bindable private var session = AuthSessionStore.shared
    @State private var step: Step = .server
    @State private var serverURL: String = ""
    @State private var login = ""
    @State private var password = ""
    @State private var email = ""
    @State private var mode: Mode = .signIn
    @State private var openSignup = false
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var showChangePassword = false
    @State private var confirmedBaseURL: URL?

    private enum Mode: String, CaseIterable {
        case signIn
        case register
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .server:
                    serverStep
                case .credentials:
                    credentialsStep
                }
            }
            .navigationTitle(step == .server ? "auth.server_title" : "auth.title")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView {
                    showChangePassword = false
                }
            }
        }
    }

    // MARK: - Step 1: server

    private var serverStep: some View {
        Form {
            Section {
                TextField("auth.server_url_placeholder", text: $serverURL)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("auth.server_url")
                    .submitLabel(.continue)
                    .onSubmit { Task { await continueFromServer() } }
            } header: {
                Text("auth.server_section")
            } footer: {
                Text("auth.server_footer")
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
                    Task { await continueFromServer() }
                } label: {
                    if isBusy {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("auth.continue")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isBusy || ServerProbe.normalizeBaseURL(serverURL) == nil)
                .accessibilityIdentifier("auth.server_continue")
            }
        }
    }

    // MARK: - Step 2: credentials

    private var credentialsStep: some View {
        Form {
            if let confirmedBaseURL {
                Section {
                    LabeledContent("auth.server_section", value: confirmedBaseURL.host ?? confirmedBaseURL.absoluteString)
                    Button("auth.change_server") {
                        step = .server
                        errorMessage = nil
                    }
                    .accessibilityIdentifier("auth.change_server")
                }
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
                    Task { await submitCredentials() }
                } label: {
                    if isBusy {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(mode == .register ? "auth.create_account" : "auth.sign_in")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isBusy || !canSubmitCredentials)
                .accessibilityIdentifier("auth.submit")
            }
        }
    }

    private var canSubmitCredentials: Bool {
        let loginOK = login.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1
        let passOK = password.count >= (mode == .register ? 8 : 1)
        return confirmedBaseURL != nil && loginOK && passOK
    }

    @MainActor
    private func continueFromServer() async {
        errorMessage = nil
        guard let base = ServerProbe.normalizeBaseURL(serverURL) else {
            errorMessage = String(localized: "auth.error_bad_url")
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await ServerProbe.probe(baseURL: base)
            AppConfiguration.setUserString(base.absoluteString, for: AppConfiguration.Keys.apiBaseURL)
            confirmedBaseURL = base
            openSignup = result.openSignup
            if !result.openSignup {
                mode = .signIn
            }
            step = .credentials
        } catch let error as ServerProbeError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func submitCredentials() async {
        errorMessage = nil
        guard let base = confirmedBaseURL else {
            errorMessage = String(localized: "auth.error_bad_url")
            return
        }
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
