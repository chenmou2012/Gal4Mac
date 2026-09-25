import XCTest
@testable import Gal4MacCore

final class SaveArchiveTests: XCTestCase {
    func testUnityAndSiglusRoundTripWithBackup() throws {
        for (engine, directoryName, filename) in [
            (EngineType.unity, "SaveData", "slot.dat"),
            (EngineType.siglus, "savedata_zh", "global.sav")
        ] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let gameDirectory = root.appendingPathComponent("game")
            let saves = gameDirectory.appendingPathComponent(directoryName)
            let target = root.appendingPathComponent("restore/\(directoryName)")
            try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            try Data("original cloud save".utf8).write(to: saves.appendingPathComponent(filename))
            try Data("local save".utf8).write(to: target.appendingPathComponent(filename))
            let game = Game(name: "Fixture", path: gameDirectory, executable: "game.exe", engine: engine)
            let manager = SaveManager(backupRoot: root.appendingPathComponent("backups"))
            let locations = manager.locateSaves(for: game)
            XCTAssertEqual(locations.first?.path.standardizedFileURL.path, saves.standardizedFileURL.path)

            let zip = root.appendingPathComponent("saves.zip")
            try manager.exportSaves(from: locations, to: zip)
            let preview = try manager.previewImport(from: zip, to: target)
            XCTAssertEqual(preview.files, [filename])
            XCTAssertEqual(preview.overwrittenFiles, [filename])
            let result = try manager.importSaves(preview)
            XCTAssertEqual(result.fileCount, 1)
            XCTAssertEqual(try String(contentsOf: target.appendingPathComponent(filename)), "original cloud save")
            XCTAssertEqual(try String(contentsOf: try XCTUnwrap(result.backupDirectory).appendingPathComponent(filename)), "local save")
        }
    }

    func testRejectsDamagedAndEmptyArchives() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let zip = root.appendingPathComponent("bad.zip")
        try Data("not a zip".utf8).write(to: zip)
        XCTAssertThrowsError(try SaveArchiveManager().preview(zipURL: zip, targetDirectory: root))
        let empty = root.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        XCTAssertThrowsError(try SaveArchiveManager().export(directory: empty, to: zip))
    }

    func testRejectsTargetPathBlockedByAFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source/nested")
        let target = root.appendingPathComponent("target")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try Data("save".utf8).write(to: source.appendingPathComponent("slot.sav"))
        try Data("blocking file".utf8).write(to: target.appendingPathComponent("nested"))
        let manager = SaveArchiveManager(backupRoot: root.appendingPathComponent("backups"))
        let zip = root.appendingPathComponent("nested.zip")
        try manager.export(directory: source.deletingLastPathComponent(), to: zip)
        XCTAssertThrowsError(try manager.preview(zipURL: zip, targetDirectory: target))
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("nested")), "blocking file")
    }

    func testReadsLegacyExportWithoutAddingWrapperDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("gal4mac_export_old/save_0_savedata")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: old.appendingPathComponent("slot.sav"))
        let zip = root.appendingPathComponent("old.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", old.deletingLastPathComponent().path, zip.path]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)

        let target = root.appendingPathComponent("restored")
        let manager = SaveArchiveManager(backupRoot: root.appendingPathComponent("backups"))
        let preview = try manager.preview(zipURL: zip, targetDirectory: target)
        XCTAssertEqual(preview.files, ["slot.sav"])
        _ = try manager.importSaves(preview)
        XCTAssertEqual(try String(contentsOf: target.appendingPathComponent("slot.sav")), "old")
    }

    func testLocalAokanaAndClannadSaveFilesWhenAvailable() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let samples: [(String, EngineType, String, String)] = [
            ("Aokana", .unity, "Aokana.exe", "SaveData"),
            ("CLANNAD", .siglus, "SiglusEngine_Steam.exe", "savedata_zh")
        ]
        for (name, engine, executable, folder) in samples {
            let gameDirectory = repository.appendingPathComponent("GalLib/\(name)")
            guard FileManager.default.fileExists(atPath: gameDirectory.appendingPathComponent(folder).path) else {
                throw XCTSkip("本机没有 \(name) 测试存档")
            }
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let manager = SaveManager(backupRoot: root.appendingPathComponent("backups"))
            let game = Game(name: name, path: gameDirectory, executable: executable, engine: engine)
            let location = try XCTUnwrap(manager.locateSaves(for: game).first)
            XCTAssertEqual(location.path.lastPathComponent, folder)
            let zip = root.appendingPathComponent("\(name).zip")
            try manager.exportSaves(from: [location], to: zip)
            let restored = root.appendingPathComponent("restored")
            let preview = try manager.previewImport(from: zip, to: restored)
            let result = try manager.importSaves(preview)
            XCTAssertEqual(result.fileCount, location.fileCount)
            for path in preview.files {
                XCTAssertEqual(try Data(contentsOf: location.path.appendingPathComponent(path)),
                               try Data(contentsOf: restored.appendingPathComponent(path)))
            }
        }
    }
}
