import XCTest
@testable import Gal4MacCore

final class SteamClientSavesTests: XCTestCase {
    func testFindsOnlySyncedFilesForRequestedApp() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let remote = root.appendingPathComponent("userdata/12345/888790/remote", isDirectory: true)
        let other = root.appendingPathComponent("userdata/12345/999999/remote", isDirectory: true)
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try Data("cloud".utf8).write(to: remote.appendingPathComponent("datasc.ksd"))
        try Data("other".utf8).write(to: other.appendingPathComponent("other.ksd"))

        let scanner = SteamClientSaves(steamRoots: [root])
        let files = scanner.files(appID: "888790")
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first?.relativePath, "datasc.ksd")
        XCTAssertEqual(files.first?.account, "12345")
        XCTAssertTrue(scanner.files(appID: "../888790").isEmpty)
    }
}
