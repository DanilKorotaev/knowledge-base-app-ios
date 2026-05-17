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

    func testDetectTypeNilDateDoubleAndData() {
        XCTAssertEqual(UserDefaultsDebugValueCodec.detectType(nil), .unknown)
        XCTAssertEqual(UserDefaultsDebugValueCodec.detectType(Date()), .date)
        XCTAssertEqual(UserDefaultsDebugValueCodec.detectType(3.14), .double)
        XCTAssertEqual(UserDefaultsDebugValueCodec.detectType(Data([1, 2, 3])), .data)
    }

    func testMakeSnapshotDateAndDouble() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let dateSnapshot = UserDefaultsDebugValueCodec.makeSnapshot(from: date)
        XCTAssertEqual(dateSnapshot.valueType, .date)
        XCTAssertFalse(dateSnapshot.valuePreviewText.isEmpty)

        let doubleSnapshot = UserDefaultsDebugValueCodec.makeSnapshot(from: 2.5)
        XCTAssertEqual(doubleSnapshot.valueType, .double)
        XCTAssertEqual(doubleSnapshot.stringValue, "2.5")
    }

    func testMakeSnapshotJSONDataAsPrettyJSON() throws {
        let payload = Data("{\"flag\":true}".utf8)
        let snapshot = UserDefaultsDebugValueCodec.makeSnapshot(from: payload)
        XCTAssertEqual(snapshot.valueType, .data)
        XCTAssertTrue(snapshot.decodedDataAsJSON)
        XCTAssertTrue(snapshot.stringValue.contains("flag"))
    }

    func testMakeSnapshotOpaqueDataShowsSize() {
        let snapshot = UserDefaultsDebugValueCodec.makeSnapshot(from: Data([0x00, 0xFF]))
        XCTAssertEqual(snapshot.valueType, .data)
        XCTAssertFalse(snapshot.decodedDataAsJSON)
        XCTAssertTrue(snapshot.dataSize.contains("bytes"))
    }

    func testMakeStoredValueDoubleAndDate() throws {
        let date = Date()
        let dateUpdate = UserDefaultsInspectorUpdate(
            valueType: .date,
            stringValue: "",
            boolValue: false,
            dateValue: date,
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        XCTAssertEqual(try UserDefaultsDebugValueCodec.makeStoredValue(for: dateUpdate) as? Date, date)

        let doubleUpdate = UserDefaultsInspectorUpdate(
            valueType: .double,
            stringValue: "3.5",
            boolValue: false,
            dateValue: Date(),
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        XCTAssertEqual(try UserDefaultsDebugValueCodec.makeStoredValue(for: doubleUpdate) as? Double, 3.5)
    }

    func testMakeStoredValueDataRequiresDecodedJSON() {
        let update = UserDefaultsInspectorUpdate(
            valueType: .data,
            stringValue: "{}",
            boolValue: false,
            dateValue: Date(),
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        XCTAssertThrowsError(try UserDefaultsDebugValueCodec.makeStoredValue(for: update)) { error in
            guard case UserDefaultsInspectorServiceError.dataNotEditable = error else {
                XCTFail("expected dataNotEditable")
                return
            }
        }
    }

    func testMakeStoredValueInvalidJSONThrows() {
        let update = UserDefaultsInspectorUpdate(
            valueType: .json,
            stringValue: "{",
            boolValue: false,
            dateValue: Date(),
            decodedDataAsJSON: false,
            archivedValuePaths: [:]
        )
        XCTAssertThrowsError(try UserDefaultsDebugValueCodec.makeStoredValue(for: update)) { error in
            guard case UserDefaultsInspectorServiceError.invalidJSON = error else {
                return XCTFail("expected invalidJSON, got \(error)")
            }
        }
    }

    func testNSArraySnapshot() {
        let snapshot = UserDefaultsDebugValueCodec.makeSnapshot(from: ["a", "b"] as NSArray)
        XCTAssertEqual(snapshot.valueType, .json)
        XCTAssertTrue(snapshot.stringValue.contains("a"))
    }
}
