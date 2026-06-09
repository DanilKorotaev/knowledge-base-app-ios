import SwiftUI

/// Sample for `onScrollGeometryChange` (pagination debug + edge detection).
struct ScrollPaginationSample: Equatable {
    let isNearOldestEdge: Bool
    let offsetBucket: Int
    let snapshot: String

    init(geometry: ScrollGeometry) {
        isNearOldestEdge = ChatOlderLoadScrollMetrics.isNearOldestLoadedEdge(geometry)
        offsetBucket = Int(geometry.contentOffset.y / 40)
        snapshot = ChatOlderLoadScrollMetrics.debugSnapshot(geometry)
    }

    static func == (lhs: ScrollPaginationSample, rhs: ScrollPaginationSample) -> Bool {
        lhs.isNearOldestEdge == rhs.isNearOldestEdge
            && lhs.offsetBucket == rhs.offsetBucket
    }
}

/// Scroll helpers for a bottom-anchored chat (`defaultScrollAnchor(.bottom)`).
enum ChatOlderLoadScrollMetrics {
    static let oldestEdgeThreshold: CGFloat = 120

    /// With `.defaultScrollAnchor(.bottom)`, resting at newest messages keeps a large positive
    /// `contentOffset.y` (often ≈ maxOffset). Scrolling toward older messages drives offset down
    /// and often negative — see `[pagination] geometry` logs.
    static func isNearOldestLoadedEdge(_ geometry: ScrollGeometry) -> Bool {
        isNearOldestLoadedEdge(
            contentOffsetY: geometry.contentOffset.y,
            contentInsetTop: geometry.contentInsets.top,
            contentHeight: geometry.contentSize.height,
            containerHeight: geometry.containerSize.height
        )
    }

    static func isNearOldestLoadedEdge(
        contentOffsetY: CGFloat,
        contentInsetTop: CGFloat,
        contentHeight: CGFloat,
        containerHeight: CGFloat
    ) -> Bool {
        let maxOffset = maxScrollOffset(contentHeight: contentHeight, containerHeight: containerHeight)
        guard maxOffset > oldestEdgeThreshold else { return false }
        return contentOffsetY <= contentInsetTop + oldestEdgeThreshold
    }

    static func maxScrollOffset(contentHeight: CGFloat, containerHeight: CGFloat) -> CGFloat {
        max(0, contentHeight - containerHeight)
    }

    static func debugSnapshot(_ geometry: ScrollGeometry) -> String {
        debugSnapshot(
            contentOffsetY: geometry.contentOffset.y,
            contentInsetTop: geometry.contentInsets.top,
            contentHeight: geometry.contentSize.height,
            containerHeight: geometry.containerSize.height
        )
    }

    static func debugSnapshot(
        contentOffsetY: CGFloat,
        contentInsetTop: CGFloat,
        contentHeight: CGFloat,
        containerHeight: CGFloat
    ) -> String {
        let maxOffset = maxScrollOffset(contentHeight: contentHeight, containerHeight: containerHeight)
        let near = isNearOldestLoadedEdge(
            contentOffsetY: contentOffsetY,
            contentInsetTop: contentInsetTop,
            contentHeight: contentHeight,
            containerHeight: containerHeight
        )
        return String(
            format: "offsetY=%.1f insetTop=%.1f contentH=%.1f containerH=%.1f maxOffset=%.1f near=%@",
            contentOffsetY,
            contentInsetTop,
            contentHeight,
            containerHeight,
            maxOffset,
            near ? "YES" : "no"
        )
    }
}
