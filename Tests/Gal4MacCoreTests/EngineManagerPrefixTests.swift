import XCTest
@testable import Gal4MacCore

final class EngineManagerPrefixTests: XCTestCase {
    func testMigratesLegacyPrefixAndKeepsStableIdentity() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("Same Name")
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("saved configuration".utf8).write(to: legacy.appendingPathComponent("marker"))

        var first = Game(name: "Same Name", path: root.appendingPathComponent("first"),
                         executable: "first.exe", engine: .unity)
        let firstPrefix = try EngineManager.winePrefix(for: first, in: root)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(try String(contentsOf: firstPrefix.appendingPathComponent("marker"), encoding: .utf8),
                       "saved configuration")

        first.name = "Renamed"
        XCTAssertEqual(try EngineManager.winePrefix(for: first, in: root), firstPrefix)

        let second = Game(name: "Same Name", path: root.appendingPathComponent("second"),
                          executable: "second.exe", engine: .unity)
        XCTAssertNotEqual(try EngineManager.winePrefix(for: second, in: root), firstPrefix)
    }
}
