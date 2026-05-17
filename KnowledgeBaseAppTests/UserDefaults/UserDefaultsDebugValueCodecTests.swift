import XCTest
@testable import KnowledgeBaseApp

final class UserDefaultsDebugValueCodecTests: XCTestCase {
    func testDetectTypeBool() {
        XCTAssertEqual(UserDefaultsDebugValueCodec.detectType(true), .bool)
        XCTAssertEqual(UserDefaultsDebugValueCodec.detectType(NSNumber(value: true)), .bool)
    }

    func testDetectTypeIntegerAndString() {
        XCTAssertEqual(UserDefaultsDebugValueCodec.detectType(42), .integer)
        XCTAssertEqual(UserDefaultsDebugValueCodec.detectType("hello"), .string)
    }

    func testDetectTypeJSON() {
        XCTAssertEqual(UserDefaultsDebugValueCodec.detectType(["a": 1]), .json)
        XCTAssertEqual(UserDefaultsDebugValueCodec.detectType(["x", "y"]), .json)
    }

    func testMakeSnapshotBool() {
        let snapshot = UserDefaultsDebugValueCodec.makeSnapshot(from: true)
        XCTAssertEqual(snapshot.valueType, .bool)
        XCTAssertTrue(snapshot.boolValue)
        XCTAssertEqual(snapshot.valuePreviewText, "true")
    }

    func testMakeStoredValueBool() throws {
        let update = UserDefaultsInspectorUpdate(
            valueType: .bool,
            stringValue: "",
            boolValue: true,
            dateValue: Date(),
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        let stored = try UserDefaultsDebugValueCodec.makeStoredValue(for: update)
        XCTAssertEqual(stored as? Bool, true)
    }

    func testMakeStoredValueInteger() throws {
        let update = UserDefaultsInspectorUpdate(
            valueType: .integer,
            stringValue: "42",
            boolValue: false,
            dateValue: Date(),
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        let stored = try UserDefaultsDebugValueCodec.makeStoredValue(for: update)
        XCTAssertEqual(stored as? Int, 42)
    }

    func testMakeStoredValueInvalidNumberThrows() {
        let update = UserDefaultsInspectorUpdate(
            valueType: .integer,
            stringValue: "not-a-number",
            boolValue: false,
            dateValue: Date(),
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        XCTAssertThrowsError(try UserDefaultsDebugValueCodec.makeStoredValue(for: update)) { error in
            guard case UserDefaultsInspectorServiceError.invalidNumber = error else {
                return XCTFail("Expected invalidNumber, got \(error)")
            }
        }
    }

    func testMakeStoredValueJSONRoundTrip() throws {
        let json = """
        {"name":"kb","count":2}
        """
        let update = UserDefaultsInspectorUpdate(
            valueType: .json,
            stringValue: json,
            boolValue: false,
            dateValue: Date(),
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        let stored = try UserDefaultsDebugValueCodec.makeStoredValue(for: update)
        let dict = stored as? [String: Any]
        XCTAssertEqual(dict?["name"] as? String, "kb")
        XCTAssertEqual(dict?["count"] as? Int, 2)
    }

    func testJSONSnapshotContainsPrettyPrintedKeys() {
        let snapshot = UserDefaultsDebugValueCodec.makeSnapshot(from: ["z": 1, "a": 2])
        XCTAssertEqual(snapshot.valueType, .json)
        XCTAssertTrue(snapshot.stringValue.contains("\"a\""))
        XCTAssertTrue(snapshot.stringValue.contains("\"z\""))
    }
}
