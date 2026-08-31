import QuickLook
import SwiftUI

struct OfflineCacheManagementView: View {
    @State private var entries: [CachedAttachmentEntry] = []
    @State private var totalBytes: Int64 = 0
    @State private var showClearAllConfirm = false
    @State private var isSelecting = false
    @State private var selectedKeys: Set<String> = []
    @State private var previewImageItem: IdentifiableCacheImage?
    @State private var previewURL: URL?
    @State private var previewError: String?
    @State private var kindByKey: [String: CachedAttachmentKind] = [:]

    private let cache: AttachmentDiskCacheProtocol

    init(cache: AttachmentDiskCacheProtocol = FileAttachmentDiskCache.shared) {
        self.cache = cache
    }

    var body: some View {
        List {
            Section {
                LabeledContent("offline.attachments_cached", value: "\(entries.count)")
                LabeledContent("offline.total_size", value: CacheByteFormatting.string(for: totalBytes))
            }

            Section("offline.cached_files") {
                if entries.isEmpty {
                    Text("offline.cache_empty")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        cacheRow(for: entry)
                            .contextMenu {
                                Button("offline.preview", systemImage: "eye") {
                                    Task { await openPreview(for: entry) }
                                }
                                Button("offline.delete", systemImage: "trash", role: .destructive) {
                                    delete(keys: [entry.cacheKey])
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("offline.delete", role: .destructive) {
                                    delete(keys: [entry.cacheKey])
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("offline.cache_title")
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarWhenPushed()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !entries.isEmpty {
                    Button(isSelecting ? "common.done" : "common.select") {
                        withAnimation(.snappy(duration: 0.25)) {
                            isSelecting.toggle()
                            if !isSelecting {
                                selectedKeys.removeAll()
                            }
                        }
                    }
                }
            }
        }
        // Keep actions in a stable inset — `.bottomBar` jumps when the tab bar hides on push.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !entries.isEmpty {
                bottomActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.28), value: isSelecting)
        .animation(.snappy(duration: 0.28), value: entries.isEmpty)
        .onAppear { reload() }
        .fullScreenCover(item: $previewImageItem) { item in
            FullscreenImageViewer(image: item.image) {
                previewImageItem = nil
            }
        }
        .quickLookPreview($previewURL)
        .alert("preview.unavailable", isPresented: Binding(
            get: { previewError != nil },
            set: { if !$0 { previewError = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(previewError ?? "")
        }
        .alert("offline.clear_confirm_title", isPresented: $showClearAllConfirm) {
            Button("offline.clear_all", role: .destructive) {
                cache.removeAll()
                reload()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(
                L10n.format(
                    "offline.clear_confirm_format",
                    Int64(entries.count),
                    CacheByteFormatting.string(for: totalBytes)
                )
            )
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(role: .destructive) {
                if isSelecting {
                    delete(keys: selectedKeys)
                    withAnimation(.snappy(duration: 0.25)) {
                        isSelecting = false
                    }
                } else {
                    showClearAllConfirm = true
                }
            } label: {
                Text(isSelecting ? "offline.delete_selected" : "offline.clear_all_cache")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .disabled(isSelecting && selectedKeys.isEmpty)
            .padding(.horizontal, 16)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func cacheRow(for entry: CachedAttachmentEntry) -> some View {
        let kind = kindByKey[entry.cacheKey] ?? CachedAttachmentKind.from(entry: entry)
        Button {
            if isSelecting {
                toggleSelection(for: entry.cacheKey)
            } else {
                Task { await openPreview(for: entry) }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.systemImageName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(CachedAttachmentPreviewURL.displayTitle(for: entry, kind: kind))
                        .font(.body)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        Text(CacheByteFormatting.string(for: Int64(entry.byteSize)))
                        if let sessionId = entry.sessionId {
                            Text(L10n.format("offline.session_format", sessionId))
                        }
                        Text(AttachmentCacheAgeFormatting.relative(since: entry.lastAccessAt))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isSelecting {
                    Image(systemName: selectedKeys.contains(entry.cacheKey) ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(selectedKeys.contains(entry.cacheKey) ? Color.accentColor : .secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggleSelection(for key: String) {
        if selectedKeys.contains(key) {
            selectedKeys.remove(key)
        } else {
            selectedKeys.insert(key)
        }
    }

    private func delete(keys: Set<String>) {
        guard !keys.isEmpty else { return }
        for key in keys {
            cache.remove(key: key)
        }
        selectedKeys.subtract(keys)
        reload()
    }

    @MainActor
    private func openPreview(for entry: CachedAttachmentEntry) async {
        guard let source = cache.fileURL(forKey: entry.cacheKey) else {
            previewError = L10n.string("preview.unavailable")
            return
        }

        let hint = peekHeader(at: source)
        let kind = CachedAttachmentKind.from(entry: entry, dataHint: hint)
        kindByKey[entry.cacheKey] = kind

        do {
            let preview = try CachedAttachmentPreviewURL.make(
                for: entry,
                sourceURL: source,
                kind: kind
            )
            switch kind {
            case .image:
                if let image = UIImage(contentsOfFile: preview.path) {
                    previewImageItem = IdentifiableCacheImage(image: image)
                } else {
                    previewURL = preview
                }
            case .audio, .video, .other:
                previewURL = preview
            }
        } catch {
            previewError = L10n.string("preview.unavailable")
        }
    }

    private func reload() {
        entries = cache.allEntries()
        totalBytes = cache.totalByteSize()
        selectedKeys = selectedKeys.intersection(Set(entries.map(\.cacheKey)))
        if entries.isEmpty {
            isSelecting = false
        }
        for entry in entries where kindByKey[entry.cacheKey] == nil {
            let hint = cache.fileURL(forKey: entry.cacheKey).flatMap(peekHeader(at:))
            kindByKey[entry.cacheKey] = CachedAttachmentKind.from(entry: entry, dataHint: hint)
        }
    }

    private func peekHeader(at url: URL) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: 16)
    }
}

private struct IdentifiableCacheImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    NavigationStack {
        OfflineCacheManagementView(cache: FileAttachmentDiskCache())
    }
}
