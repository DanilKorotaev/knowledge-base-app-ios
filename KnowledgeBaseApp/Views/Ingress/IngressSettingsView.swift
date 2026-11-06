import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct IngressSettingsView: View {
    @State private var tokens: [IngressToken] = []
    @State private var bindings: [IngressBinding] = []
    @State private var rules: [IngressRule] = []
    @State private var adapters: [IngressAdapter] = []
    @State private var events: [IngressEvent] = []
    @State private var sessions: [KBSession] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var createdURL: String?
    @State private var showCreateToken = false
    @State private var newTokenLabel = ""
    @State private var newTokenChannel = "alerts"
    @State private var busyTokenId: String?
    @State private var editingBindingKey: String?
    @State private var bindingSessionDraft = ""

    private var client: IngressAPIClientProtocol {
        URLSessionIngressAPIClient() ?? StubIngressAPIClient()
    }

    private var sessionsClient: KnowledgeBaseAPIClientProtocol {
        URLSessionKnowledgeBaseAPIClient() ?? StubKnowledgeBaseAPIClient()
    }

    var body: some View {
        Form {
            if let errorText {
                Section {
                    Text(errorText)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }

            if let createdURL {
                Section {
                    Text(createdURL)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                    Button("ingress.settings.copy_url") {
                        copyToPasteboard(createdURL)
                    }
                } header: {
                    Text("ingress.settings.created_token")
                } footer: {
                    Text("ingress.settings.created_token_footer")
                }
            }

            Section {
                if isLoading && tokens.isEmpty {
                    ProgressView()
                }
                ForEach(tokens) { token in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(token.label.isEmpty ? token.maskedPrefix : token.label)
                            Spacer()
                            if token.isRevoked {
                                Text("ingress.settings.revoked")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("\(token.channelId) · \(token.maskedPrefix)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let desc = optionalNonEmpty(token.description) {
                            Text(desc)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if !token.isRevoked {
                            HStack {
                                Button("ingress.settings.copy_path") {
                                    copyToPasteboard(token.ingressPath ?? "/api/ingress/\(token.maskedPrefix)")
                                }
                                .buttonStyle(.bordered)
                                Button("ingress.settings.revoke", role: .destructive) {
                                    Task { await revoke(token) }
                                }
                                .buttonStyle(.bordered)
                                .disabled(busyTokenId == token.id)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Button("ingress.settings.create_token") {
                    showCreateToken = true
                }
            } header: {
                Text("ingress.settings.tokens")
            } footer: {
                Text("ingress.settings.tokens_footer")
            }

            Section {
                ForEach(bindings) { binding in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(binding.bindingKey)
                            .font(.headline)
                        Text("session #\(binding.sessionId)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if editingBindingKey == binding.bindingKey {
                            HStack {
                                TextField("ingress.settings.session_id", text: $bindingSessionDraft)
                                    .keyboardType(.numberPad)
                                Button("common.save") {
                                    Task { await saveBinding(binding.bindingKey) }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            if !sessions.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(sessions.prefix(12)) { session in
                                            Button {
                                                bindingSessionDraft = session.id
                                            } label: {
                                                Text(sessionTitle(session))
                                                    .font(.caption2)
                                                    .lineLimit(1)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }
                        } else {
                            Button("ingress.settings.edit_binding") {
                                editingBindingKey = binding.bindingKey
                                bindingSessionDraft = String(binding.sessionId)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                Button("ingress.settings.add_alerts_binding") {
                    editingBindingKey = "alerts"
                    bindingSessionDraft = bindings.first(where: { $0.bindingKey == "alerts" }).map { String($0.sessionId) } ?? ""
                    if !bindings.contains(where: { $0.bindingKey == "alerts" }) {
                        bindings.append(IngressBinding(bindingKey: "alerts", sessionId: 0, updatedAt: nil))
                    }
                }
            } header: {
                Text("ingress.settings.bindings")
            } footer: {
                Text("ingress.settings.bindings_footer")
            }

            Section {
                ForEach(rules) { rule in
                    Toggle(isOn: Binding(
                        get: { rule.enabled },
                        set: { newValue in
                            Task { await setRule(rule, enabled: newValue) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.label.isEmpty ? rule.id : rule.label)
                            Text("p\(rule.priority) · \(rule.actionSummary)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("ingress.settings.rules")
            } footer: {
                Text("ingress.settings.rules_footer")
            }

            Section {
                ForEach(adapters) { adapter in
                    LabeledContent(adapter.label.isEmpty ? adapter.key : adapter.label, value: adapter.key)
                }
                if adapters.isEmpty {
                    Text("ingress.settings.adapters_empty")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("ingress.settings.adapters")
            }

            Section {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.summary)
                            .lineLimit(2)
                        Text("\(event.status) · \(event.source)/\(event.type)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let err = optionalNonEmpty(event.errorMessage) {
                            Text(err)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
                if events.isEmpty {
                    Text("ingress.settings.events_empty")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("ingress.settings.events")
            }
        }
        .navigationTitle("ingress.settings.title")
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showCreateToken) {
            NavigationStack {
                Form {
                    TextField("ingress.settings.token_label", text: $newTokenLabel)
                    TextField("ingress.settings.token_channel", text: $newTokenChannel)
                }
                .navigationTitle("ingress.settings.create_token")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") { showCreateToken = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.create") {
                            Task { await createToken() }
                        }
                        .disabled(newTokenLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    @MainActor
    private func reload() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            async let t = client.fetchTokens()
            async let b = client.fetchBindings()
            async let r = client.fetchRules()
            async let a = client.fetchAdapters()
            async let e = client.fetchEvents(limit: 25)
            async let s = sessionsClient.fetchSessions()
            tokens = try await t
            bindings = try await b
            rules = try await r.sorted { $0.priority < $1.priority }
            adapters = try await a
            events = try await e
            sessions = (try? await s) ?? []
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func createToken() async {
        let label = newTokenLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let channel = newTokenChannel.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let created = try await client.createToken(
                IngressCreateTokenBody(
                    label: label,
                    description: "Created from iOS Settings",
                    channelId: channel.isEmpty ? "default" : channel,
                    adapterKey: channel == "alerts" ? "grafana" : nil,
                    allowedSources: channel == "alerts" ? ["grafana"] : nil,
                    allowEnqueueAgent: false,
                    allowScript: false,
                    agentRuntime: "none",
                    agentPromptProfile: "untrusted_ingress"
                )
            )
            createdURL = created.ingressUrl ?? created.ingressUrlPath ?? created.token.map { "/api/ingress/\($0)" }
            showCreateToken = false
            newTokenLabel = ""
            await reload()
        } catch {
            errorText = error.localizedDescription
            showCreateToken = false
        }
    }

    @MainActor
    private func revoke(_ token: IngressToken) async {
        busyTokenId = token.id
        defer { busyTokenId = nil }
        do {
            try await client.revokeToken(id: token.id)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func saveBinding(_ key: String) async {
        guard let sessionId = Int(bindingSessionDraft.trimmingCharacters(in: .whitespacesAndNewlines)), sessionId > 0 else {
            errorText = String(localized: "ingress.settings.invalid_session_id")
            return
        }
        do {
            try await client.upsertBinding(key: key, sessionId: sessionId)
            editingBindingKey = nil
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    @MainActor
    private func setRule(_ rule: IngressRule, enabled: Bool) async {
        do {
            try await client.setRuleEnabled(id: rule.id, enabled: enabled)
            await reload()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func sessionTitle(_ session: KBSession) -> String {
        let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty { return "#\(session.id)" }
        return "#\(session.id) \(title.prefix(28))"
    }

    private func optionalNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}
