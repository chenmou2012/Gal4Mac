import XCTest
@testable import Gal4MacCore

final class LibraryManagerTests: XCTestCase {
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
