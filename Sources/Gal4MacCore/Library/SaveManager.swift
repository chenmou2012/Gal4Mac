import Foundation

/// 存档管理器
///
/// 不同galgame引擎的存档位置和格式不同，本模块负责自动识别和导入导出
public final class SaveManager {

    public enum SaveError: LocalizedError {
        case noSavesFound
        case saveLocationUnknown
        case exportFailed(String)
        case importFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noSavesFound: return "未找到存档"
            case .saveLocationUnknown: return "无法识别存档位置"
            case .exportFailed(let msg): return "导出失败: \(msg)"
            case .importFailed(let msg): return "导入失败: \(msg)"
            }
        }
    }

    private let archive: SaveArchiveManager

    public init(backupRoot: URL = LibraryManager.configDirectory.appendingPathComponent("SaveBackups", isDirectory: true)) {
        archive = SaveArchiveManager(backupRoot: backupRoot)
    }

    /// 存档位置信息
    public struct SaveLocation {
        public let path: URL
        public let engine: EngineType
        public let sizeBytes: Int64
        public let fileCount: Int
    }

    /// 查找游戏的存档位置
    public func locateSaves(for game: Game) -> [SaveLocation] {
        var locations: [SaveLocation] = []

        // 检查游戏目录下的标准存档位置
        let candidates = saveLocationCandidates(for: game.engine, gameDir: game.path, gameName: game.name)

        for candidate in candidates {
            if let loc = inspectLocation(candidate, engine: game.engine) {
                locations.append(loc)
            }
        }

        return locations
    }

    /// 导出存档到 zip 文件
    public func exportSaves(from locations: [SaveLocation], to outputURL: URL) throws {
        guard locations.count == 1 else { throw SaveError.exportFailed("请选择一个存档目录") }
        try archive.export(directory: locations[0].path, to: outputURL)
    }

    public func suggestedImportDirectory(for game: Game) -> URL? {
        locateSaves(for: game).first?.path
            ?? saveLocationCandidates(for: game.engine, gameDir: game.path, gameName: game.name).first
    }

    public func previewImport(from zipURL: URL, to directory: URL) throws -> SaveArchiveManager.ImportPreview {
        try archive.preview(zipURL: zipURL, targetDirectory: directory)
    }

    public func importSaves(_ preview: SaveArchiveManager.ImportPreview) throws -> SaveArchiveManager.ImportResult {
        try archive.importSaves(preview)
    }

    /// 保留旧 API；目标目录由引擎规则选择。
    public func importSaves(from zipURL: URL, to game: Game) throws -> Int {
        guard let directory = suggestedImportDirectory(for: game) else { throw SaveError.saveLocationUnknown }
        return try importSaves(previewImport(from: zipURL, to: directory)).fileCount
    }

    // MARK: - 私有方法

    private func saveLocationCandidates(for engine: EngineType, gameDir: URL, gameName: String) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser

        switch engine {
        case .kirikiri:
            // KiriKiri 通常在游戏目录下的 savedata/
            return [gameDir.appendingPathComponent("savedata")]
        case .siglus:
            // SiglusEngine 用 savedata 或 savedata_zh
            return [
                gameDir.appendingPathComponent("savedata_zh"),
                gameDir.appendingPathComponent("savedata")
            ]
        case .unity:
            // Unity 多种多样，尝试常见位置
            return [
                gameDir.appendingPathComponent("SaveData"),
                gameDir.appendingPathComponent("Saves"),
                gameDir.appendingPathComponent("Save"),
                home.appendingPathComponent("AppData/LocalLow/\(gameName)")
            ]
        case .tyranoScript:
            // TyranoScript 用 localStorage（但游戏目录可能有导出存档）
            return [
                gameDir.appendingPathComponent("savedata"),
                gameDir.appendingPathComponent("save")
            ]
        case .renpy:
            return [gameDir.appendingPathComponent("save")]
        default:
            return [gameDir.appendingPathComponent("savedata")]
        }
    }

    private func inspectLocation(_ url: URL, engine: EngineType) -> SaveLocation? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir),
              isDir.boolValue else { return nil }

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey]
        ) else { return nil }

        // 至少要有 1 个文件才认为有存档
        guard !contents.isEmpty else { return nil }

        var totalSize: Int64 = 0
        for item in contents {
            if let size = try? item.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize {
                totalSize += Int64(size)
            }
        }

        return SaveLocation(
            path: url,
            engine: engine,
            sizeBytes: totalSize,
            fileCount: contents.count
        )
    }
}
