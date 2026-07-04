import XCTest
@testable import KnowledgeBaseApp

final class AppLanguageStoreTests: XCTestCase {
    override func tearDown() {
        AppLanguageStore.shared.resetForTesting()
        super.tearDown()
    }

    func testDefaultOverrideIsSystem() {
        AppLanguageStore.shared.resetForTesting()
        XCTAssertEqual(AppLanguageStore.shared.override, .system)
    }

    func testEnglishOverrideResolvesLocale() {
        AppLanguageStore.shared.setOverride(.english)
        XCTAssertEqual(AppLanguageStore.shared.resolvedLocale.identifier, "en")
        XCTAssertEqual(AppLanguageStore.shared.resolvedLanguageCode, "en")
    }

    func testRussianOverrideResolvesLocale() {
        AppLanguageStore.shared.setOverride(.russian)
        XCTAssertEqual(AppLanguageStore.shared.resolvedLocale.identifier, "ru")
        XCTAssertEqual(AppLanguageStore.shared.resolvedLanguageCode, "ru")
    }

    func testEnglishUIStringsWhenOverrideEnglish() {
        AppLanguageStore.shared.setOverride(.english)
        XCTAssertEqual(L10n.string("sync.updating"), "Updating…")
        XCTAssertEqual(L10n.string("voice.not_recognized"), "Voice not recognized")
    }

    func testRussianUIStringsWhenOverrideRussian() {
        AppLanguageStore.shared.setOverride(.russian)
        XCTAssertEqual(L10n.string("sync.updating"), "Обновление…")
        XCTAssertEqual(L10n.string("voice.not_recognized"), "Голосовое не распознано")
    }
}
