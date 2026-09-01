import SwiftUI

struct MarkdownTableView: View {
    let header: [String]
    let rows: [[String]]

    @State private var viewportWidth: CGFloat = 280
    @State private var fullscreenTable: MarkdownTableData?

    /// ~48% of bubble width — enough to read a column without oversized peek.
    private var columnWidth: CGFloat {
        max(96, viewportWidth * 0.48)
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
        .background(widthReader)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fullScreenCover(item: $fullscreenTable) { table in
            MarkdownTableFullscreenView(table: table) {
                fullscreenTable = nil
            }
        }
    }

    private var widthReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { viewportWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, newValue in
                    viewportWidth = max(1, newValue)
                }
        }
    }
}
