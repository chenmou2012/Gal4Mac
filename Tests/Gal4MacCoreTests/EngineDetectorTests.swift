import XCTest
@testable import Gal4MacCore

final class EngineDetectorTests: XCTestCase {

    let detector = EngineDetector()

    func testUnityDetection() throws {
        let url = try makeUnityFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let engine = detector.detect(at: url)
        XCTAssertEqual(engine, .unity, "Aokana 应该是 Unity 引擎")
    }

    func testSiglusDetection() throws {
        let url = try makeSiglusFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let engine = detector.detect(at: url)
        XCTAssertEqual(engine, .siglus, "CLANNAD 应该是 SiglusEngine")
    }

    func testUnityExecutable() throws {
        let url = try makeUnityFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let exe = detector.findExecutable(at: url, engine: .unity)
        XCTAssertNotNil(exe, "应该找到 Unity 可执行文件")
        XCTAssertTrue(exe?.contains("Aokana") ?? false)
    }

    func testSiglusExecutable() throws {
        let url = try makeSiglusFixture()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let exe = detector.findExecutable(at: url, engine: .siglus)
        XCTAssertNotNil(exe)
        XCTAssertTrue(exe?.lowercased().contains("siglus") ?? false)
    }

    func testUnknownEngine() {
        let url = URL(fileURLWithPath: "/tmp")
        let engine = detector.detect(at: url)
        XCTAssertEqual(engine, .unknown)
    }

    func testGenericSystemDirectoryIsNotKiriKiri() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("system"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        FileManager.default.createFile(atPath: directory.appendingPathComponent("game.exe").path, contents: Data())

        XCTAssertEqual(detector.detect(at: directory), .unknown)
        XCTAssertEqual(detector.findExecutable(at: directory, engine: .unknown), "game.exe")
    }

    func testManualExecutableMustBeInsideGameDirectory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        FileManager.default.createFile(atPath: directory.appendingPathComponent("game.exe").path, contents: Data())

        XCTAssertTrue(LibraryManager.isValidExecutable("game.exe", in: directory))
        XCTAssertFalse(LibraryManager.isValidExecutable("../game.exe", in: directory))
        XCTAssertFalse(LibraryManager.isValidExecutable("missing.exe", in: directory))
    }

    func testEngineCompatibility() {
        XCTAssertEqual(EngineType.unity.compatibility, .excellent)
        XCTAssertEqual(EngineType.siglus.compatibility, .excellent)
        XCTAssertEqual(EngineType.kirikiri.compatibility, .good)
    }

    func testUnityLaunchArgs() {
        let args = EngineType.unity.defaultLaunchArgs(width: 1920, height: 1080)
        XCTAssertTrue(args.contains("-screen-fullscreen"))
        XCTAssertTrue(args.contains("1920"))
        XCTAssertTrue(args.contains("1080"))
    }

    func testSiglusLaunchArgs() {
        let args = EngineType.siglus.defaultLaunchArgs(width: 1280, height: 720)
        XCTAssertTrue(args.contains("-window"))
        XCTAssertTrue(args.contains("1280"))
    }

    private func makeUnityFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let game = root.appendingPathComponent("Aokana")
        try FileManager.default.createDirectory(at: game.appendingPathComponent("Aokana_Data"), withIntermediateDirectories: true)
        try Data().write(to: game.appendingPathComponent("Aokana.exe"))
        return game
    }

    private func makeSiglusFixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let game = root.appendingPathComponent("CLANNAD")
        try FileManager.default.createDirectory(at: game.appendingPathComponent("gan"), withIntermediateDirectories: true)
        try Data().write(to: game.appendingPathComponent("Gameexe.dat"))
        try Data().write(to: game.appendingPathComponent("Scene.pck"))
        try Data().write(to: game.appendingPathComponent("SiglusEngine.exe"))
        return game
    }
}
