import XCTest
@testable import KnowledgeBaseApp

final class UserDefaultsDebugModelsTests: XCTestCase {
    func testArchivedValueStrategyDisplayName() {
        XCTAssertEqual(UserDefaultsInspectorArchivedValueStrategy.keyedArchive.displayName, "NSKeyedArchiver")
        XCTAssertEqual(UserDefaultsInspectorArchivedValueStrategy.plist.displayName, "PropertyList")
    }

    func testSnapshotArchivedFieldsAndEditability() {
        let snapshot = UserDefaultsInspectorValueSnapshot(
            typeName: "Dictionary",
            valueType: .json,
            stringValue: "{}",
            boolValue: false,
            dateValue: Date(),
            dataSize: "",
            decodedDataAsJSON: false,
            archivedValuePaths: ["root": .plist]
        )
        XCTAssertEqual(snapshot.archivedFieldsDetailed, ["root (PropertyList)"])
        XCTAssertEqual(snapshot.archivedFieldsNote, "root (PropertyList)")
        XCTAssertTrue(snapshot.canEditValue)

        let boolSnapshot = UserDefaultsInspectorValueSnapshot(
            typeName: "Bool",
            valueType: .bool,
            stringValue: "true",
            boolValue: true,
            dateValue: Date(),
            dataSize: "",
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        XCTAssertFalse(boolSnapshot.canEditValue)
        XCTAssertEqual(boolSnapshot.valuePreviewText, "true")
    }

    func testSnapshotDateAndDataPreview() {
        let date = Date(timeIntervalSince1970: 0)
        let dateSnapshot = UserDefaultsInspectorValueSnapshot(
            typeName: "Date",
            valueType: .date,
            stringValue: "",
            boolValue: false,
            dateValue: date,
            dataSize: "",
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        XCTAssertFalse(dateSnapshot.valuePreviewText.isEmpty)

        let dataSnapshot = UserDefaultsInspectorValueSnapshot(
            typeName: "Data",
            valueType: .data,
            stringValue: "",
            boolValue: false,
            dateValue: Date(),
            dataSize: "12 bytes",
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        XCTAssertEqual(dataSnapshot.valuePreviewText, "12 bytes")
    }

    func testInspectorItemSearchableText() {
        let known = UserDefaultsKeyRegistry.knownKey(for: UserDefaultsKey.apiBaseURL.rawValue)!
        let item = UserDefaultsInspectorItem(
            key: UserDefaultsKey.apiBaseURL.rawValue,
            knownKey: known,
            rawValue: "https://kb.test",
            snapshot: UserDefaultsDebugValueCodec.makeSnapshot(from: "https://kb.test")
        )
        XCTAssertTrue(item.isKnown)
        XCTAssertTrue(item.searchableText.contains("api_base_url"))
    }
}
