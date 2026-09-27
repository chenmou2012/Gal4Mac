import XCTest
@testable import Gal4MacCore

final class LibraryManagerTests: XCTestCase {
    func testReimportKeepsSelectedWineLocale() throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: storage) }
        let gameDirectory = storage.appendingPathComponent("Example")
        try FileManager.default.createDirectory(at: gameDirectory, withIntermediateDirectories: true)
        try Data().write(to: gameDirectory.appendingPathComponent("Example.exe"))
        let manager = LibraryManager(storageDirectory: storage)
        let saved = Game(name: "Example", path: gameDirectory, executable: "Example.exe",
                         engine: .unity, wineLocale: .japanese)
        try manager.saveLibrary([saved])
        XCTAssertEqual(manager.loadLibrary().first?.wineLocale, .japanese)

        XCTAssertEqual(manager.loadLibrary().first?.path.standardizedFileURL.pathComponents,
                       gameDirectory.standardizedFileURL.pathComponents)

        let imported = try manager.addGame(at: gameDirectory, engine: .unity, executable: "Example.exe")

        XCTAssertEqual(imported?.wineLocale, .japanese)
        XCTAssertEqual(manager.loadLibrary().first?.wineLocale, .japanese)
        XCTAssertEqual(manager.loadLibrary().count, 1)
    }

    func testImportPersistsConfirmedSteamIdentityAndDisplayName() throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: storage) }
        let gameDirectory = storage.appendingPathComponent("game-files")
        try FileManager.default.createDirectory(at: gameDirectory, withIntermediateDirectories: true)
        try Data().write(to: gameDirectory.appendingPathComponent("Start.exe"))
        let manager = LibraryManager(storageDirectory: storage)

        let imported = try XCTUnwrap(manager.addGame(
            at: gameDirectory,
            engine: .unknown,
            executable: "Start.exe",
            displayName: "CLANNAD",
            wineLocale: .japanese,
            steamAppID: 324160
        ))

        XCTAssertEqual(imported.name, "CLANNAD")
        XCTAssertEqual(imported.steamAppID, 324160)
        XCTAssertEqual(manager.loadLibrary().first?.steamAppID, 324160)
        XCTAssertEqual(manager.loadLibrary().first?.wineLocale, .japanese)

        _ = try manager.addGame(
            at: gameDirectory,
            engine: .unknown,
            executable: "Start.exe",
            displayName: "自定义名称",
            clearSteamMatch: true
        )
        XCTAssertNil(manager.loadLibrary().first?.steamAppID)
    }

    func testUnavailableLibraryPreservesSavedGames() throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: storage) }
        let root = storage.appendingPathComponent("ExternalLibrary")
        let manager = LibraryManager(storageDirectory: storage)
        let game = Game(name: "Example", path: root.appendingPathComponent("Example"),
                        executable: "Example.exe", engine: .unity)
        try manager.saveConfig(LibraryConfig(libraryPaths: [root]))
        try manager.saveLibrary([game])

        XCTAssertThrowsError(try manager.scanAll())
        XCTAssertEqual(manager.loadLibrary(), [game])
    }

    func testSuccessfulScanRemovesMissingGameOnlyInScannedLibrary() throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: storage) }
        let online = storage.appendingPathComponent("Online")
        let offline = storage.appendingPathComponent("Offline")
        try FileManager.default.createDirectory(at: online, withIntermediateDirectories: true)
        let onlineGame = Game(name: "Gone", path: online.appendingPathComponent("Gone"),
                              executable: "Gone.exe", engine: .unity)
        let offlineGame = Game(name: "Keep", path: offline.appendingPathComponent("Keep"),
                               executable: "Keep.exe", engine: .unity)
        let manager = LibraryManager(storageDirectory: storage)
        try manager.saveConfig(LibraryConfig(libraryPaths: [online, offline]))
        try manager.saveLibrary([onlineGame, offlineGame])

        XCTAssertEqual(try manager.scanAll(), [offlineGame])
        XCTAssertEqual(manager.loadLibrary(), [offlineGame])
    }

    func testPathContainmentUsesComponents() {
        let root = URL(fileURLWithPath: "/Games/Gal")
        XCTAssertTrue(LibraryManager.isWithin(URL(fileURLWithPath: "/Games/Gal/Title"), root: root))
        XCTAssertFalse(LibraryManager.isWithin(URL(fileURLWithPath: "/Games/GalExtra/Title"), root: root))
    }

    func testFailedNestedLibraryIsPreservedWhenParentScans() throws {
        let storage = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: storage) }
        let parent = storage.appendingPathComponent("Library")
        let nested = parent.appendingPathComponent("External")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let game = Game(name: "Keep", path: nested.appendingPathComponent("Keep"),
                        executable: "Keep.exe", engine: .unity)
        let manager = LibraryManager(storageDirectory: storage)
        try manager.saveConfig(LibraryConfig(libraryPaths: [parent, nested]))
        try manager.saveLibrary([game])

        XCTAssertEqual(try manager.scanAll(), [game])
    }
}
