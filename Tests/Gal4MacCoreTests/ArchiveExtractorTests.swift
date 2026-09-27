import XCTest
@testable import Gal4MacCore

final class ArchiveExtractorTests: XCTestCase {
    func testPasswordProtectedZipWithUnknownEngineCanReachConfiguration() throws {
        guard FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/unar") ||
              FileManager.default.isExecutableFile(atPath: "/usr/local/bin/unar") else {
            throw XCTSkip("unar 未安装")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Mystery")
        let output = root.appendingPathComponent("Extracted")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("exe".utf8).write(to: source.appendingPathComponent("Start.exe"))
        let archive = root.appendingPathComponent("Mystery.zip")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = root
        zip.arguments = ["-q", "-P", "secret", "-r", archive.path, "Mystery"]
        try zip.run()
        zip.waitUntilExit()
        XCTAssertEqual(zip.terminationStatus, 0)

        let game = try ArchiveExtractor().extract(archiveURL: archive, to: output, password: "secret")
        XCTAssertTrue(FileManager.default.fileExists(atPath: game.appendingPathComponent("Start.exe").path))
    }
}
