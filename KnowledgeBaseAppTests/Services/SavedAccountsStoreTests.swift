@testable import KnowledgeBaseApp
import XCTest

final class SavedAccountsStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SavedAccountsStore.clearAll()
    }

    override func tearDown() {
        SavedAccountsStore.clearAll()
        super.tearDown()
    }

    func testUpsertSwitchPointerAndRemove() {
        let alice = SavedAccount(
            id: SavedAccount.makeId(apiBaseURL: "https://api.example.com", userId: 1),
            apiBaseURL: "https://api.example.com",
            userId: 1,
            login: "alice",
            accessToken: "a-token",
            refreshToken: "a-refresh",
            vaultRootRelative: "users/alice",
            kbFolder: "/"
        )
        let bob = SavedAccount(
            id: SavedAccount.makeId(apiBaseURL: "https://api.example.com", userId: 2),
            apiBaseURL: "https://api.example.com",
            userId: 2,
            login: "bob",
            accessToken: "b-token",
            refreshToken: "b-refresh",
            vaultRootRelative: nil,
            kbFolder: nil
        )

        SavedAccountsStore.upsert(alice)
        XCTAssertEqual(SavedAccountsStore.activeAccountId, alice.id)
        XCTAssertEqual(SavedAccountsStore.loadAll().count, 1)

        SavedAccountsStore.upsert(bob)
        XCTAssertEqual(SavedAccountsStore.activeAccountId, bob.id)
        XCTAssertEqual(SavedAccountsStore.loadAll().map(\.login).sorted(), ["alice", "bob"])

        SavedAccountsStore.updateTokens(id: alice.id, accessToken: "a2", refreshToken: "r2")
        XCTAssertEqual(SavedAccountsStore.account(id: alice.id)?.accessToken, "a2")
        XCTAssertEqual(SavedAccountsStore.account(id: alice.id)?.refreshToken, "r2")

        let remaining = SavedAccountsStore.remove(id: bob.id)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.login, "alice")
        XCTAssertEqual(SavedAccountsStore.activeAccountId, alice.id)
    }

    func testMakeIdIncludesHostAndUser() {
        let id = SavedAccount.makeId(apiBaseURL: "https://API.Example.com:8443/v1", userId: 42)
        XCTAssertTrue(id.contains("u42"))
        XCTAssertTrue(id.lowercased().contains("api.example.com"))
    }
}
