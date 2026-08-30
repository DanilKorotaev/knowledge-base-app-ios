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
                        withAnimation {
                            isSelecting.toggle()
                            if !isSelecting {
                                selectedKeys.removeAll()
                            }
                        }
                    }
                }
            }
            ToolbarItem(placement: .bottomBar) {
                if isSelecting {
                    Button("offline.delete_selected", role: .destructive) {
                        delete(keys: selectedKeys)
                        isSelecting = false
                    }
                    .disabled(selectedKeys.isEmpty)
                } else {
                    Button("offline.clear_all_cache", role: .destructive) {
                        showClearAllConfirm = true
                    }
                    .disabled(entries.isEmpty)
                }
            }
        }
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

    @ViewBuilder
    private func cacheRow(for entry: CachedAttachmentEntry) -> some View {
        let kind = CachedAttachmentKind.from(entry: entry)
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
                    Text(entry.fileName ?? entry.cacheKey)
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
        guard let url = cache.fileURL(forKey: entry.cacheKey) else {
            previewError = L10n.string("preview.unavailable")
            return
        }

        switch CachedAttachmentKind.from(entry: entry) {
        case .image:
            if let image = UIImage(contentsOfFile: url.path) {
                previewImageItem = IdentifiableCacheImage(image: image)
            } else {
                previewError = L10n.string("preview.unavailable")
            }
        case .audio, .video, .other:
            previewURL = url
        }
    }

    private func reload() {
        entries = cache.allEntries()
        totalBytes = cache.totalByteSize()
        selectedKeys = selectedKeys.intersection(Set(entries.map(\.cacheKey)))
        if entries.isEmpty {
            isSelecting = false
        }
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
