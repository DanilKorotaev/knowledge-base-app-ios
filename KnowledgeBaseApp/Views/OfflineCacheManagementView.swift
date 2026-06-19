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
                LabeledContent("Attachments cached", value: "\(entries.count)")
                LabeledContent("Total size", value: CacheByteFormatting.string(for: totalBytes))
            }

            Section("Cached files") {
                if entries.isEmpty {
                    Text("No attachments cached yet. Open images or voice messages while online.")
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
                                    Text("session \(sessionId)")
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
        .navigationTitle("Offline cache")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Clear all cache", role: .destructive) {
                    showClearAllConfirm = true
                }
                .disabled(entries.isEmpty)
            }
        }
        .onAppear { reload() }
        .alert("Clear all cached attachments?", isPresented: $showClearAllConfirm) {
            Button("Clear all", role: .destructive) {
                cache.removeAll()
                reload()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(entries.count) files (\(CacheByteFormatting.string(for: totalBytes))). They will download again when opened online.")
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
        "opened \(SyncStatusFormatting.relativeAge(since: date))"
    }
}

#Preview {
    NavigationStack {
        OfflineCacheManagementView(cache: FileAttachmentDiskCache())
    }
}
