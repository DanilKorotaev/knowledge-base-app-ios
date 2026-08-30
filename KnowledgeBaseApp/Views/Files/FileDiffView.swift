import SwiftUI
import WebKit

struct FileDiffView: View {
    let file: KBChangedFile
    let filesClient: FilesAPIClientProtocol
    var onReverted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmRevert = false
    @State private var isReverting = false
    @State private var errorMessage: String?
    @State private var isOpeningCurrentVersion = false
    @State private var previewURL: URL?
    @State private var diffMode: DiffMode = .unified
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(file.path)
                    .font(.title3.weight(.semibold))
                Text(file.changeKind)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("diff.mode", selection: $diffMode) {
                    ForEach(DiffMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch diffMode {
                case .unified:
                    UnifiedFileDiffView(beforeText: file.beforeText, afterText: file.afterText)
                case .split:
                    SplitFileDiffView(beforeText: file.beforeText, afterText: file.afterText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("diff.title")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarWhenPushed()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await openCurrentVersion() }
                } label: {
                    Label("diff.current", systemImage: "eye")
                }
                .disabled(isOpeningCurrentVersion)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let previewURL {
                        openURL(previewURL)
                    } else {
                        Task { await openCurrentVersion(openExternal: true) }
                    }
                } label: {
                    Label("diff.open", systemImage: "safari")
                }
                .disabled(isOpeningCurrentVersion)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("diff.revert", role: .destructive) {
                    confirmRevert = true
                }
                .disabled(isReverting)
            }
        }
        .confirmationDialog(
            "diff.revert_confirm",
            isPresented: $confirmRevert,
            titleVisibility: .visible
        ) {
            Button("diff.revert", role: .destructive) {
                Task { await revert() }
            }
            Button("common.cancel", role: .cancel) {}
        }
        .alert("diff.revert", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: Binding(
            get: { previewURL.map(IdentifiableURL.init) },
            set: { newValue in
                previewURL = newValue?.url
            }
        )) { item in
            NavigationStack {
                FilePreviewWebView(url: item.url)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle("diff.current_version")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("common.done") {
                                previewURL = nil
                            }
                        }
                    }
            }
        }
    }

    @MainActor
    private func openCurrentVersion(openExternal: Bool = false) async {
        isOpeningCurrentVersion = true
        defer { isOpeningCurrentVersion = false }
        do {
            let url = try await filesClient.createShareLink(fileId: file.id)
            previewURL = url
            if openExternal {
                openURL(url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func revert() async {
        isReverting = true
        defer { isReverting = false }
        do {
            try await filesClient.revertFile(id: file.id)
            onReverted()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private enum DiffMode: String, CaseIterable, Identifiable {
    case unified
    case split

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unified:
            return L10n.string("diff.mode.unified")
        case .split:
            return L10n.string("diff.mode.split")
        }
    }
}

private struct UnifiedFileDiffView: View {
    let beforeText: String?
    let afterText: String?
    @State private var expandedContextGroupIDs: Set<String> = []

    private var lines: [UnifiedDiffLine] {
        UnifiedDiffLine.build(beforeText: beforeText, afterText: afterText)
    }

    private var rows: [UnifiedDiffRow] {
        UnifiedDiffRow.build(lines: lines, expandedContextGroupIDs: expandedContextGroupIDs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("diff.old")
                    .frame(width: 44, alignment: .trailing)
                Text("diff.new")
                    .frame(width: 44, alignment: .trailing)
                Text(" ")
                    .frame(width: 12)
                Text("diff.content")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            ForEach(rows) { row in
                switch row {
                case .line(let line):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(line.oldLine.map(String.init) ?? "")
                            .frame(width: 44, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        Text(line.newLine.map(String.init) ?? "")
                            .frame(width: 44, alignment: .trailing)
                            .foregroundStyle(.secondary)
                        Text(line.prefix)
                            .frame(width: 12, alignment: .leading)
                            .foregroundStyle(line.prefixColor)
                        Text(line.content.isEmpty ? " " : line.content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(line.backgroundColor)
                case .collapsedContext(let context):
                    Button {
                        expandedContextGroupIDs.insert(context.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "ellipsis")
                                .font(.caption)
                            Text(L10n.format("diff.show_more_unchanged_format", context.hiddenCount))
                                .font(.caption)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct SplitFileDiffView: View {
    let beforeText: String?
    let afterText: String?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            diffColumn(title: L10n.string("diff.before"), text: beforeText)
            diffColumn(title: L10n.string("diff.after"), text: afterText)
        }
    }

    private func diffColumn(title: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text ?? "—")
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private enum UnifiedDiffOperation {
    case equal(String)
    case delete(String)
    case insert(String)
}

private struct UnifiedDiffLine: Identifiable {
    let id = UUID()
    let oldLine: Int?
    let newLine: Int?
    let prefix: String
    let content: String
    let kind: Kind

    enum Kind {
        case context
        case added
        case removed
    }

    var backgroundColor: Color {
        switch kind {
        case .context:
            Color.clear
        case .added:
            Color.green.opacity(0.16)
        case .removed:
            Color.red.opacity(0.16)
        }
    }

    var prefixColor: Color {
        switch kind {
        case .context:
            .secondary
        case .added:
            .green
        case .removed:
            .red
        }
    }

    static func build(beforeText: String?, afterText: String?) -> [UnifiedDiffLine] {
        let beforeLines = splitLines(beforeText ?? "")
        let afterLines = splitLines(afterText ?? "")

        if beforeLines.isEmpty, afterLines.isEmpty {
            return [
                UnifiedDiffLine(
                    oldLine: nil,
                    newLine: nil,
                    prefix: " ",
                    content: L10n.string("diff.no_textual_changes"),
                    kind: .context
                ),
            ]
        }

        let operations = diffOperations(before: beforeLines, after: afterLines)
        var rendered: [UnifiedDiffLine] = []
        var oldCounter = 1
        var newCounter = 1

        for operation in operations {
            switch operation {
            case .equal(let content):
                rendered.append(
                    UnifiedDiffLine(
                        oldLine: oldCounter,
                        newLine: newCounter,
                        prefix: " ",
                        content: content,
                        kind: .context
                    )
                )
                oldCounter += 1
                newCounter += 1
            case .delete(let content):
                rendered.append(
                    UnifiedDiffLine(
                        oldLine: oldCounter,
                        newLine: nil,
                        prefix: "-",
                        content: content,
                        kind: .removed
                    )
                )
                oldCounter += 1
            case .insert(let content):
                rendered.append(
                    UnifiedDiffLine(
                        oldLine: nil,
                        newLine: newCounter,
                        prefix: "+",
                        content: content,
                        kind: .added
                    )
                )
                newCounter += 1
            }
        }

        return rendered
    }

    private static func splitLines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private static func diffOperations(before: [String], after: [String]) -> [UnifiedDiffOperation] {
        let n = before.count
        let m = after.count
        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)

        if n > 0, m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    if before[i] == after[j] {
                        lcs[i][j] = lcs[i + 1][j + 1] + 1
                    } else {
                        lcs[i][j] = max(lcs[i + 1][j], lcs[i][j + 1])
                    }
                }
            }
        }

        var i = 0
        var j = 0
        var operations: [UnifiedDiffOperation] = []

        while i < n && j < m {
            if before[i] == after[j] {
                operations.append(.equal(before[i]))
                i += 1
                j += 1
            } else if lcs[i + 1][j] >= lcs[i][j + 1] {
                operations.append(.delete(before[i]))
                i += 1
            } else {
                operations.append(.insert(after[j]))
                j += 1
            }
        }

        while i < n {
            operations.append(.delete(before[i]))
            i += 1
        }
        while j < m {
            operations.append(.insert(after[j]))
            j += 1
        }

        return operations
    }
}

private enum UnifiedDiffRow: Identifiable {
    case line(UnifiedDiffLine)
    case collapsedContext(CollapsedContextGroup)

    var id: String {
        switch self {
        case .line(let line):
            return "line-\(line.id.uuidString)"
        case .collapsedContext(let group):
            return "group-\(group.id)"
        }
    }

    static func build(lines: [UnifiedDiffLine], expandedContextGroupIDs: Set<String>) -> [UnifiedDiffRow] {
        let threshold = 9
        let visibleContextEdge = 3
        var rows: [UnifiedDiffRow] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            guard line.kind == .context else {
                rows.append(.line(line))
                index += 1
                continue
            }

            let start = index
            while index < lines.count, lines[index].kind == .context {
                index += 1
            }
            let end = index
            let count = end - start
            let groupID = "\(start)-\(end)"

            if count <= threshold || expandedContextGroupIDs.contains(groupID) {
                for item in lines[start..<end] {
                    rows.append(.line(item))
                }
                continue
            }

            let headRange = start..<(start + visibleContextEdge)
            let tailRange = (end - visibleContextEdge)..<end

            for item in lines[headRange] {
                rows.append(.line(item))
            }
            rows.append(
                .collapsedContext(
                    CollapsedContextGroup(
                        id: groupID,
                        hiddenCount: count - (visibleContextEdge * 2)
                    )
                )
            )
            for item in lines[tailRange] {
                rows.append(.line(item))
            }
        }

        return rows
    }
}

private struct CollapsedContextGroup {
    let id: String
    let hiddenCount: Int
}

private struct FilePreviewWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
