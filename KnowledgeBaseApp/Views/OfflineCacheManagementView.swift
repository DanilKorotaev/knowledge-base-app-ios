import SwiftUI

struct OfflineCacheManagementView: View {
    @State private var entries: [CachedAttachmentEntry] = []
    @State private var totalBytes: Int64 = 0
    @State private var showClearAllConfirm = false

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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.fileName ?? entry.cacheKey)
                                .font(.body)
                                .lineLimit(2)
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
                    }
                    .onDelete(perform: deleteAtOffsets)
                }
            }
        }
        .navigationTitle("offline.cache_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("offline.clear_all_cache", role: .destructive) {
                    showClearAllConfirm = true
                }
                .disabled(entries.isEmpty)
            }
        }
        .onAppear { reload() }
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

    private func reload() {
        entries = cache.allEntries()
        totalBytes = cache.totalByteSize()
    }

    private func deleteAtOffsets(_ offsets: IndexSet) {
        for index in offsets {
            cache.remove(key: entries[index].cacheKey)
        }
        reload()
    }
}

enum AttachmentCacheAgeFormatting {
    static func relative(since date: Date) -> String {
        L10n.format("offline.opened_format", SyncStatusFormatting.relativeAge(since: date))
    }
}

#Preview {
    NavigationStack {
        OfflineCacheManagementView(cache: FileAttachmentDiskCache())
    }
}
