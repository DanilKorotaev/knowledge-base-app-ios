import SwiftUI

struct MarkdownTableView: View {
    let header: [String]
    let rows: [[String]]

    @State private var viewportWidth: CGFloat = 280
    @State private var fullscreenTable: MarkdownTableData?

    /// ~72% of bubble width so the next column peeks and hints at horizontal scroll.
    private var columnWidth: CGFloat {
        max(112, viewportWidth * 0.72)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            MarkdownTableGrid(
                header: header,
                rows: rows,
                columnWidth: columnWidth,
                compactPadding: true
            )
        }
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { _, newValue in
            viewportWidth = max(1, newValue)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(6)
                .background(.ultraThinMaterial, in: Circle())
                .padding(6)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            fullscreenTable = MarkdownTableData(header: header, rows: rows)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fullScreenCover(item: $fullscreenTable) { table in
            MarkdownTableFullscreenView(table: table) {
                fullscreenTable = nil
            }
        }
    }
}
