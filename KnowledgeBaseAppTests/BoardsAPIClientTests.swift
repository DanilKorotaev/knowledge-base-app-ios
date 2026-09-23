import Foundation
import Testing
@testable import KnowledgeBaseApp

@Suite("BoardsAPIClient")
struct BoardsAPIClientTests {
    private func makeClient(useDemoFallback: Bool = true) -> URLSessionBoardsAPIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return URLSessionBoardsAPIClient(
            baseURL: URL(string: "https://kb.test")!,
            authToken: "token",
            urlSession: session,
            useDemoFallback: useDemoFallback
        )
    }

    @Test("stub returns demo boards")
    func stubFetchBoards() async throws {
        let client = StubBoardsAPIClient()
        let boards = try await client.fetchBoards()
        #expect(boards.count == 2)
        #expect(boards.first?.id == DemoBoardsCatalog.demoKPIId)
        let detail = try await client.fetchBoard(id: DemoBoardsCatalog.demoKPIId)
        #expect(detail.document.screen.type == "vstack")
        let flatTypes = Self.collectTypes(detail.document.screen)
        #expect(flatTypes.contains("metric"))
        #expect(flatTypes.contains("table"))
    }

    private static func collectTypes(_ node: KBStructuredUINode) -> [String] {
        [node.type] + (node.children ?? []).flatMap(collectTypes)
    }

    @Test("stub refresh returns same detail")
    func stubRefresh() async throws {
        let client = StubBoardsAPIClient()
        let detail = try await client.refreshBoard(id: DemoBoardsCatalog.demoJobsId)
        #expect(detail.board.kind == "system")
    }

    @Test("stub missing board throws notFound")
    func stubMissing() async {
        let client = StubBoardsAPIClient()
        do {
            _ = try await client.fetchBoard(id: "missing")
            Issue.record("expected notFound")
        } catch let error as BoardsAPIError {
            #expect(error == .notFound)
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test("remote list decodes boards")
    func remoteList() async throws {
        let client = makeClient()
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path.hasSuffix("/api/boards") == true)
            let body = """
            {
              "boards": [
                {
                  "id": "b1",
                  "title": "Fuel",
                  "subtitle": "KPI",
                  "icon": "fuelpump",
                  "kind": "cached_view",
                  "sort_order": 5,
                  "enabled": true,
                  "list_cell": {
                    "kind": "metrics",
                    "title": "Fuel",
                    "metrics": [{"label": "Sum", "value": "100"}]
                  },
                  "rendered_at": "2026-08-27T12:00:00Z"
                },
                {
                  "id": "disabled",
                  "title": "Hidden",
                  "kind": "remote",
                  "sort_order": 1,
                  "enabled": false
                }
              ],
              "total": 2
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let boards = try await client.fetchBoards()
        #expect(boards.count == 1)
        #expect(boards[0].id == "b1")
        #expect(boards[0].listCell?.metrics?.first?.value == "100")
        #expect(boards[0].systemImageName == "fuelpump")
    }

    @Test("remote list 404 falls back to demo")
    func remoteListFallback() async throws {
        let client = makeClient(useDemoFallback: true)
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        defer { MockURLProtocol.requestHandler = nil }

        let boards = try await client.fetchBoards()
        #expect(boards.count == 2)
    }

    @Test("remote list 404 without fallback throws")
    func remoteListNoFallback() async {
        let client = makeClient(useDemoFallback: false)
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        defer { MockURLProtocol.requestHandler = nil }

        do {
            _ = try await client.fetchBoards()
            Issue.record("expected error")
        } catch let error as BoardsAPIError {
            if case .invalidResponse(let code, _) = error {
                #expect(code == 404)
            } else {
                Issue.record("unexpected \(error)")
            }
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test("remote detail decodes document")
    func remoteDetail() async throws {
        let client = makeClient()
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.path.hasSuffix("/api/boards/b1") == true)
            let body = """
            {
              "board": {
                "id": "b1",
                "title": "Fuel",
                "kind": "cached_view",
                "sort_order": 0,
                "enabled": true
              },
              "document": {
                "schema_version": 1,
                "screen": {
                  "type": "vstack",
                  "id": "root",
                  "children": [
                    {"type": "metric", "id": "m1", "label": "Sum", "text": "42"},
                    {
                      "type": "table",
                      "id": "t1",
                      "label": "Rows",
                      "columns": [{"id": "a", "label": "A"}],
                      "rows": [["1"], ["2"]]
                    }
                  ]
                }
              },
              "rendered_at": "2026-08-27T12:00:00Z"
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let detail = try await client.fetchBoard(id: "b1")
        #expect(detail.board.id == "b1")
        #expect(detail.document.screen.supportedChildren.first?.type == "metric")
        let table = detail.document.screen.supportedChildren.first { $0.type == "table" }
        #expect(table?.columns?.count == 1)
        #expect(table?.rows?.count == 2)
    }

    @Test("remote refresh posts and falls back to detail on 404")
    func remoteRefreshFallback() async throws {
        let client = makeClient()
        var paths: [String] = []
        MockURLProtocol.requestHandler = { request in
            let path = request.url?.path ?? ""
            paths.append(path)
            if path.hasSuffix("/refresh") {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (response, Data())
            }
            let body = """
            {
              "board": {
                "id": "b1",
                "title": "Fuel",
                "kind": "cached_view",
                "sort_order": 0,
                "enabled": true
              },
              "document": {
                "schema_version": 1,
                "screen": {"type": "text", "id": "t", "text": "ok"}
              }
            }
            """.data(using: .utf8)!
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, body)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let detail = try await client.refreshBoard(id: "b1")
        #expect(detail.document.screen.text == "ok")
        #expect(paths.contains { $0.hasSuffix("/refresh") })
        #expect(paths.contains { $0.hasSuffix("/api/boards/b1") })
    }
}

@Suite("Boards models")
struct BoardsModelTests {
    @Test("list response accepts items alias")
    func itemsAlias() throws {
        let json = """
        {"items":[{"id":"x","title":"X","kind":"remote","sort_order":1,"enabled":true}],"total":1}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(KBBoardsListResponse.self, from: json)
        #expect(decoded.boards.count == 1)
        #expect(decoded.boards[0].systemImageName == "network")
    }

    @Test("metric and table nodes are supported")
    func metricTableSupported() throws {
        let json = """
        {
          "schema_version": 1,
          "screen": {
            "type": "vstack",
            "id": "root",
            "children": [
              {"type": "metric", "id": "m", "label": "A", "text": "1"},
              {
                "type": "table",
                "id": "t",
                "columns": [{"id": "c", "label": "C"}],
                "rows": [["v"]]
              }
            ]
          }
        }
        """.data(using: .utf8)!
        let doc = try JSONDecoder().decode(KBStructuredUIDocument.self, from: json)
        #expect(doc.screen.supportedChildren.count == 2)
        #expect(doc.screen.supportedChildren[0].isSupported)
        #expect(doc.screen.supportedChildren[1].rows == [["v"]])
    }

    @Test("default system image by kind")
    func defaultIcons() {
        #expect(KBBoard(id: "1", title: "A", kind: "system").systemImageName == "gearshape.2")
        #expect(KBBoard(id: "2", title: "B", kind: "cached_view").systemImageName == "square.grid.2x2")
    }
}

@MainActor
@Suite("BoardsViewModel")
struct BoardsViewModelTests {
    @Test("load populates boards")
    func load() async {
        let vm = BoardsViewModel(client: StubBoardsAPIClient())
        await vm.loadIfNeeded()
        #expect(vm.boards.count == 2)
        #expect(vm.loadError == nil)
        await vm.loadIfNeeded()
        #expect(vm.boards.count == 2)
    }

    @Test("detail load and refresh")
    func detail() async {
        let vm = BoardDetailViewModel(boardId: DemoBoardsCatalog.demoKPIId, client: StubBoardsAPIClient())
        await vm.load()
        #expect(vm.detail?.board.id == DemoBoardsCatalog.demoKPIId)
        await vm.refresh()
        #expect(vm.detail?.document.screen.type == "vstack")
    }

    @Test("detail missing sets error")
    func detailMissing() async {
        let vm = BoardDetailViewModel(boardId: "nope", client: StubBoardsAPIClient())
        await vm.load()
        #expect(vm.detail == nil)
        #expect(vm.loadError != nil)
    }
}
