import SwiftUI

struct MarkdownTableFullscreenView: View {
    let table: MarkdownTableData
    let onDismiss: () -> Void

    @State private var viewportWidth: CGFloat = 360

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                MarkdownTableGrid(
                    header: table.header,
                    rows: table.rows,
                    columnWidth: fullscreenColumnWidth,
                    compactPadding: false
                )
                .padding()
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Table")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        toggleOrientationHint()
                    } label: {
                        Label("Rotate", systemImage: "rotate.right")
                    }
                }
            }
            .background(widthReader)
        }
        .onAppear {
            OrientationLock.setLandscapeAllowed(true)
        }
        .onDisappear {
            OrientationLock.setLandscapeAllowed(false)
        }
    }

    private var fullscreenColumnWidth: CGFloat {
        max(160, min(320, viewportWidth * 0.42))
    }

    private var widthReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { viewportWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, newValue in
                    viewportWidth = newValue
                }
        }
    }

    private func toggleOrientationHint() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let isLandscape = scene?.interfaceOrientation.isLandscape ?? false
        let target: UIInterfaceOrientationMask = isLandscape ? .portrait : .landscape
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: target)) { _ in }
    }
}
