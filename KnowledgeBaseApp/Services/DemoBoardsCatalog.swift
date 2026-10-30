import Foundation

/// Built-in demo boards used by the stub client and as a graceful fallback when the API
/// does not yet expose `/api/boards` (404). No vault paths or domain knowledge.
enum DemoBoardsCatalog {
    static let demoKPIId = "demo-kpi"
    static let demoJobsId = "demo-active-jobs"
    static let demoNavId = "demo-nav"
    static let demoFormId = "demo-form"

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
                        KBBoardListMetric(label: "Last", value: "1 200")
                    ]
                ),
                renderedAt: "2026-08-27T12:00:00Z",
                periodUi: "range"
            ),
            KBBoard(
                id: demoNavId,
                title: "Demo: navigation",
                subtitle: "list_row + chevron (open_board)",
                icon: "list.bullet",
                kind: "cached_view",
                sortOrder: 15,
                enabled: true,
                listCell: KBBoardListCell(
                    kind: "status",
                    title: "Demo: navigation",
                    subtitle: "list_row + chevron",
                    statusText: "3 rows",
                    statusTone: "info"
                ),
                renderedAt: "2026-08-27T12:00:00Z",
                periodUi: "none"
            ),
            KBBoard(
                id: demoFormId,
                title: "Demo: form",
                subtitle: "checkbox / radio / date / submit",
                icon: "checklist",
                kind: "cached_view",
                sortOrder: 16,
                enabled: true,
                listCell: KBBoardListCell(
                    kind: "status",
                    title: "Demo: form",
                    subtitle: "Interactive fields",
                    statusText: "form",
                    statusTone: "info"
                ),
                renderedAt: "2026-08-27T12:00:00Z",
                periodUi: "none"
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
            )
        ]
    }

    static func detail(id: String) -> KBBoardDetail? {
        guard let board = boards().first(where: { $0.id == id }) else { return nil }
        switch id {
        case demoKPIId:
            return KBBoardDetail(board: board, document: kpiDocument, renderedAt: board.renderedAt)
        case demoNavId:
            return KBBoardDetail(board: board, document: navDocument, renderedAt: board.renderedAt)
        case demoFormId:
            return KBBoardDetail(board: board, document: formDocument, renderedAt: board.renderedAt)
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
                        )
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
                        KBStructuredUITableColumn(id: "amount", label: "Amount")
                    ],
                    rows: [
                        ["2026-08-20", "Alpha", "1 200"],
                        ["2026-08-12", "Beta", "890"],
                        ["2026-08-01", "Gamma", "450"]
                    ]
                )
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
                        KBStructuredUITableColumn(id: "duration", label: "Duration")
                    ],
                    rows: [
                        ["Training plan", "running", "2m 14s"]
                    ]
                ),
                KBStructuredUINode(
                    type: "button",
                    id: "demo-job-1",
                    label: "Cancel demo job",
                    actionId: "cancel_job"
                ),
                KBStructuredUINode(
                    type: "chart",
                    id: "demo_chart",
                    label: "Demo series",
                    series: [
                        KBStructuredUISeriesPoint(x: "Mon", y: 3),
                        KBStructuredUISeriesPoint(x: "Tue", y: 5),
                        KBStructuredUISeriesPoint(x: "Wed", y: 4),
                        KBStructuredUISeriesPoint(x: "Thu", y: 7),
                        KBStructuredUISeriesPoint(x: "Fri", y: 6)
                    ]
                )
            ]
        )
    )

    private static let navDocument = KBStructuredUIDocument(
        schemaVersion: 1,
        screen: KBStructuredUINode(
            type: "vstack",
            id: "root",
            children: [
                KBStructuredUINode(type: "text", id: "title", text: "Browse sections"),
                KBStructuredUINode(
                    type: "callout",
                    id: "hint",
                    text: "list_row with action open_board — chevron means navigation, not a form event.",
                    variant: "info"
                ),
                KBStructuredUINode(
                    type: "list_row",
                    id: "row_summary",
                    text: "Demo: summary",
                    label: "Metrics & table",
                    action: .openBoard(id: demoKPIId),
                    systemImage: "chart.bar"
                ),
                KBStructuredUINode(
                    type: "list_row",
                    id: "row_form",
                    text: "Demo: form",
                    label: "Interactive fields",
                    action: .openBoard(id: demoFormId),
                    systemImage: "checklist"
                ),
                KBStructuredUINode(
                    type: "list_row",
                    id: "row_actions",
                    text: "Open Actions tab",
                    label: "Jobs live under Actions",
                    action: .openTab("actions"),
                    systemImage: "bolt.horizontal.circle"
                )
            ]
        )
    )

    private static let formDocument = KBStructuredUIDocument(
        schemaVersion: 1,
        screen: KBStructuredUINode(
            type: "vstack",
            id: "root",
            children: [
                KBStructuredUINode(type: "text", id: "title", text: "Demo form"),
                KBStructuredUINode(
                    type: "callout",
                    id: "hint",
                    text: "Draft values stay local until Submit — then ui-events carries them.",
                    variant: "tip"
                ),
                KBStructuredUINode(
                    type: "checkbox",
                    id: "include_archive",
                    label: "Include archived",
                    value: .bool(false)
                ),
                KBStructuredUINode(
                    type: "radio_group",
                    id: "scope",
                    label: "Scope",
                    value: .string("week"),
                    options: [
                        KBStructuredUIOption(id: "day", label: "Day"),
                        KBStructuredUIOption(id: "week", label: "Week"),
                        KBStructuredUIOption(id: "month", label: "Month")
                    ]
                ),
                KBStructuredUINode(
                    type: "date",
                    id: "from_date",
                    label: "From",
                    value: .string("2026-08-01")
                ),
                KBStructuredUINode(
                    type: "text_field",
                    id: "note",
                    label: "Note",
                    value: .string(""),
                    placeholder: "Optional note"
                ),
                KBStructuredUINode(
                    type: "button",
                    id: "submit",
                    label: "Submit",
                    actionId: "submit_form",
                    submit: true
                )
            ]
        )
    )
}
