import SwiftUI

/// Collapsed-by-default bubble for ingress / automation participants.
struct ExternalMessageBubbleView: View {
    let message: KBMessage
    @State private var isExpanded = false

    private var participantLabel: String {
        message.external?.participant?.label
            ?? message.external?.source
            ?? L10n.string("chat.external_participant")
    }

    private var summary: String {
        message.externalSummary
    }

    private var detail: String? {
        let text = message.external?.detail?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    private var links: [KBExternalLink] {
        message.external?.links ?? []
    }

    private var avatarURL: URL? {
        message.external?.participant?.avatarURL
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 6) {
                Text(participantLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(summary)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if detail != nil || !links.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Label(
                            isExpanded
                                ? L10n.string("chat.external_hide_details")
                                : L10n.string("chat.external_show_details"),
                            systemImage: isExpanded ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                }

                if isExpanded {
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    ForEach(links) { link in
                        if let url = URL(string: link.url) {
                            Link(link.title ?? link.url, destination: url)
                                .font(.footnote)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("chat.message.external.\(message.id)")
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let avatarURL {
                CachedRemoteImage(url: avatarURL)
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
        }
    }
}

/// Simple disk+memory avatar cache for ingress participant icons.
struct CachedRemoteImage: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .task(id: url) {
            image = await IngressAvatarCache.shared.image(for: url)
        }
    }
}

actor IngressAvatarCache {
    static let shared = IngressAvatarCache()

    private var memory: [URL: UIImage] = [:]

    func image(for url: URL) async -> UIImage? {
        if let cached = memory[url] {
            return cached
        }
        let fileURL = cacheFileURL(for: url)
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            memory[url] = image
            return image
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            memory[url] = image
            try? FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: fileURL, options: .atomic)
            return image
        } catch {
            return nil
        }
    }

    private func cacheFileURL(for url: URL) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ingress-avatars", isDirectory: true)
        let name = String(url.absoluteString.hashValue)
        return dir.appendingPathComponent(name)
    }
}
