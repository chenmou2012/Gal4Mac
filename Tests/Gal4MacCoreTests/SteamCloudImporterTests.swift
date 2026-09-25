import XCTest
@testable import Gal4MacCore

final class SteamCloudImporterTests: XCTestCase {
    func testImportBacksUpExistingSave() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let download = root.appendingPathComponent("download")
        let destination = root.appendingPathComponent("game/savedata")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("cloud".utf8).write(to: download)
        try Data("local".utf8).write(to: destination.appendingPathComponent("save.dat"))

        let importer = SteamCloudImporter(backupRoot: root.appendingPathComponent("backups"))
        let result = try importer.importFile(from: download, named: "save.dat", into: destination)

        XCTAssertEqual(try String(contentsOf: result.destination), "cloud")
        XCTAssertEqual(try String(contentsOf: try XCTUnwrap(result.backup)), "local")
        XCTAssertEqual(try String(contentsOf: download), "cloud")
    }

    func testRejectsFilenameTraversal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let download = root.appendingPathComponent("download")
        try Data("cloud".utf8).write(to: download)
        let importer = SteamCloudImporter(backupRoot: root.appendingPathComponent("backups"))

        XCTAssertThrowsError(try importer.importFile(from: download, named: "../save.dat", into: root))
        XCTAssertThrowsError(try importer.importFile(from: download, named: "", into: root))
    }
}
