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

    public init() {}

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
        let fm = FileManager.default

        // 创建临时目录
        let tempDir = fm.temporaryDirectory.appendingPathComponent("gal4mac_export_\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        // 复制所有存档到临时目录
        for (index, loc) in locations.enumerated() {
            let dest = tempDir.appendingPathComponent("save_\(index)_\(loc.path.lastPathComponent)")
            do {
                try fm.copyItem(at: loc.path, to: dest)
            } catch {
                throw SaveError.exportFailed(error.localizedDescription)
            }
        }

        // 打包为 zip（用 ditto）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", tempDir.path, outputURL.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw SaveError.exportFailed("ditto 失败")
        }
    }

    /// 从 zip 文件导入存档
    public func importSaves(from zipURL: URL, to game: Game) throws -> Int {
        let fm = FileManager.default

        // 解压到临时目录
        let tempDir = fm.temporaryDirectory.appendingPathComponent("gal4mac_import_\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, tempDir.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw SaveError.importFailed("解压失败")
        }

        // 查找存档位置
        let locations = saveLocationCandidates(for: game.engine, gameDir: game.path, gameName: game.name)

        var imported = 0
        // 简单策略：复制临时目录下的所有文件到第一个可写位置
        guard let target = locations.first else {
            throw SaveError.saveLocationUnknown
        }

        // 确保目标目录存在
        if !fm.fileExists(atPath: target.path) {
            try fm.createDirectory(at: target, withIntermediateDirectories: true)
        }

        // 复制文件
        if let contents = try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for item in contents {
                let dest = target.appendingPathComponent(item.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.copyItem(at: item, to: dest)
                imported += 1
            }
        }

        return imported
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
