import Foundation

/// Built-in demo boards used by the stub client and as a graceful fallback when the API
/// does not yet expose `/api/boards` (404). No vault paths or domain knowledge.
enum DemoBoardsCatalog {
    static let demoKPIId = "demo-kpi"
    static let demoJobsId = "demo-active-jobs"

    static func boards() -> [KBBoard] {
        [
            KBBoard(
                id: demoKPIId,
                title: "Demo: summary",
                subtitle: "Sample metrics and table",
                icon: "chart.bar",
                kind: "cached_view",
                sortOrder: 10,
                enabled: true,
                listCell: KBBoardListCell(
                    kind: "metrics",
                    title: "Demo: summary",
                    subtitle: "Sample metrics and table",
                    metrics: [
                        KBBoardListMetric(label: "Total", value: "12 450"),
                        KBBoardListMetric(label: "Last", value: "1 200"),
                    ]
                ),
                renderedAt: "2026-08-27T12:00:00Z"
            ),
            KBBoard(
                id: demoJobsId,
                title: "Demo: active jobs",
                subtitle: "System board preview",
                icon: "bolt.horizontal.circle",
                kind: "system",
                sortOrder: 20,
                enabled: true,
                listCell: KBBoardListCell(
                    kind: "status",
                    title: "Demo: active jobs",
                    subtitle: "System board preview",
                    statusText: "1 running",
                    statusTone: "info"
                ),
                renderedAt: "2026-08-27T12:00:00Z"
            ),
        ]
    }

    static func detail(id: String) -> KBBoardDetail? {
        guard let board = boards().first(where: { $0.id == id }) else { return nil }
        switch id {
        case demoKPIId:
            return KBBoardDetail(board: board, document: kpiDocument, renderedAt: board.renderedAt)
        case demoJobsId:
            return KBBoardDetail(board: board, document: jobsDocument, renderedAt: board.renderedAt)
        default:
            return nil
        }
    }

    private static let kpiDocument = KBStructuredUIDocument(
        schemaVersion: 1,
        screen: KBStructuredUINode(
            type: "vstack",
            id: "root",
            children: [
                KBStructuredUINode(type: "text", id: "title", text: "Demo summary"),
                KBStructuredUINode(
                    type: "callout",
                    id: "hint",
                    text: "This screen is driven by JSON from the server. The app does not hardcode your knowledge base structure.",
                    variant: "info"
                ),
                KBStructuredUINode(
                    type: "hstack",
                    id: "metrics_row",
                    children: [
                        KBStructuredUINode(
                            type: "metric",
                            id: "m_total",
                            text: "12 450",
                            label: "Total"
                        ),
                        KBStructuredUINode(
                            type: "metric",
                            id: "m_last",
                            text: "1 200",
                            label: "Last entry"
                        ),
                        KBStructuredUINode(
                            type: "metric",
                            id: "m_count",
                            text: "18",
                            label: "Count"
                        ),
                    ],
                    spacing: 12
                ),
                KBStructuredUINode(
                    type: "table",
                    id: "sample_table",
                    label: "Recent rows",
                    columns: [
                        KBStructuredUITableColumn(id: "date", label: "Date"),
                        KBStructuredUITableColumn(id: "item", label: "Item"),
                        KBStructuredUITableColumn(id: "amount", label: "Amount"),
                    ],
                    rows: [
                        ["2026-08-20", "Alpha", "1 200"],
                        ["2026-08-12", "Beta", "890"],
                        ["2026-08-01", "Gamma", "450"],
                    ]
                ),
            ]
        )
    )

    private static let jobsDocument = KBStructuredUIDocument(
        schemaVersion: 1,
        screen: KBStructuredUINode(
            type: "vstack",
            id: "root",
            children: [
                KBStructuredUINode(type: "text", id: "title", text: "Active jobs"),
                KBStructuredUINode(
                    type: "callout",
                    id: "status",
                    text: "Demo only — real cancel/list arrives with query jobs API.",
                    variant: "tip"
                ),
                KBStructuredUINode(
                    type: "table",
                    id: "jobs_table",
                    label: "Running",
                    columns: [
                        KBStructuredUITableColumn(id: "session", label: "Session"),
                        KBStructuredUITableColumn(id: "status", label: "Status"),
                        KBStructuredUITableColumn(id: "duration", label: "Duration"),
                    ],
                    rows: [
                        ["Training plan", "running", "2m 14s"],
                    ]
                ),
            ]
        )
    )
}
