import Foundation

/// 游戏库配置
///
/// 支持多个库位置（本地磁盘、外接硬盘、网络盘）
public struct LibraryConfig: Codable, Equatable {
    /// 所有配置的库位置（每个位置是一个根目录，会扫描其下的子目录）
    public var libraryPaths: [URL]

    /// 上次扫描时间
    public var lastScanAt: Date?

    public init(libraryPaths: [URL] = [], lastScanAt: Date? = nil) {
        self.libraryPaths = libraryPaths
        self.lastScanAt = lastScanAt
    }

    /// 默认库路径（用户的 Games/Gal 目录）
    public static let defaultPath: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Games/Gal")
    }()
}

/// 游戏库管理器
///
/// 扫描本地游戏目录、缓存游戏信息、提供游戏列表
/// 支持多个库路径（本地磁盘、外接硬盘、网络盘）
public final class LibraryManager {

    public enum LibraryError: LocalizedError {
        case invalidExecutable

        public var errorDescription: String? {
            switch self {
            case .invalidExecutable: return "请选择游戏目录中的 .exe 可执行文件"
            }
        }
    }

    /// 配置文件目录
    public static var configDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("Gal4Mac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 游戏库配置文件路径
    public static var libraryFile: URL {
        configDirectory.appendingPathComponent("library.json")
    }

    /// 库配置文件路径（路径列表）
    public static var configFile: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    private let detector = EngineDetector()

    public init() {}

    // MARK: - 配置管理

    /// 加载库配置
    public func loadConfig() -> LibraryConfig {
        guard let data = try? Data(contentsOf: Self.configFile),
              let config = try? JSONDecoder().decode(LibraryConfig.self, from: data) else {
            // 首次启动：返回默认配置（包含一个默认路径）
            return LibraryConfig(libraryPaths: [LibraryConfig.defaultPath])
        }
        return config
    }

    /// 保存库配置
    public func saveConfig(_ config: LibraryConfig) throws {
        let data = try JSONEncoder().encode(config)
        try data.write(to: Self.configFile, options: .atomic)
    }

    /// 添加库路径
    public func addLibraryPath(_ path: URL) throws -> LibraryConfig {
        var config = loadConfig()
        // 标准化路径，避免重复
        let standardized = path.standardizedFileURL
        if !config.libraryPaths.contains(standardized) {
            config.libraryPaths.append(standardized)
            try saveConfig(config)
        }
        return config
    }

    /// 移除库路径
    public func removeLibraryPath(_ path: URL) throws -> LibraryConfig {
        var config = loadConfig()
        config.libraryPaths.removeAll { $0 == path.standardizedFileURL }
        try saveConfig(config)
        return config
    }

    // MARK: - 游戏库管理

    /// 加载已保存的游戏库
    public func loadLibrary() -> [Game] {
        guard let data = try? Data(contentsOf: Self.libraryFile),
              let games = try? JSONDecoder().decode([Game].self, from: data) else {
            return []
        }
        return games
    }

    /// 保存游戏库
    public func saveLibrary(_ games: [Game]) throws {
        let data = try JSONEncoder().encode(games)
        try data.write(to: Self.libraryFile, options: .atomic)
    }

    /// 扫描所有配置的库路径
    @discardableResult
    public func scanAll() throws -> [Game] {
        let config = loadConfig()
        var allFound: [Game] = []
        for path in config.libraryPaths {
            do {
                let found = try scan(directory: path, mergeToGlobal: false)
                allFound.append(contentsOf: found)
            } catch {
                print("⚠️ 扫描失败: \(path.path) - \(error.localizedDescription)")
            }
        }
        // 合并到全局库
        var library = loadLibrary()
        for game in allFound {
            if !library.contains(where: { $0.path == game.path }) {
                library.append(game)
                print("✓ 发现游戏: \(game.name) (\(game.engine.displayName))")
            }
        }
        // 移除已不存在的游戏（路径已删除）
        library.removeAll { !FileManager.default.fileExists(atPath: $0.path.path) }

        try saveLibrary(library)

        // 更新最后扫描时间
        var updatedConfig = config
        updatedConfig.lastScanAt = Date()
        try saveConfig(updatedConfig)

        return library
    }

    /// 扫描指定目录
    @discardableResult
    public func scan(directory: URL, mergeToGlobal: Bool = true) throws -> [Game] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDir),
              isDir.boolValue else {
            return []
        }

        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var foundGames: [Game] = []

        for item in contents {
            var subIsDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &subIsDir),
                  subIsDir.boolValue else { continue }

            let engine = detector.detect(at: item)
            guard engine != .unknown,
                  let executable = detector.findExecutable(at: item, engine: engine) else {
                continue
            }

            let game = Game(
                name: item.lastPathComponent,
                path: item,
                executable: executable,
                engine: engine
            )
            foundGames.append(game)
        }

        if mergeToGlobal {
            var library = loadLibrary()
            for game in foundGames {
                if !library.contains(where: { $0.path == game.path }) {
                    library.append(game)
                    print("✓ 发现游戏: \(game.name) (\(game.engine.displayName))")
                }
            }
            try saveLibrary(library)
        }

        return foundGames
    }

    /// 手动添加单个游戏
    @discardableResult
    public func addGame(at path: URL, engine selectedEngine: EngineType? = nil, executable selectedExecutable: String? = nil) throws -> Game? {
        let engine = selectedEngine ?? detector.detect(at: path)
        guard let executable = selectedExecutable ?? detector.findExecutable(at: path, engine: engine) else {
            return nil
        }

        guard Self.isValidExecutable(executable, in: path) else {
            throw LibraryError.invalidExecutable
        }

        let existing = loadLibrary().first { $0.path.standardizedFileURL == path.standardizedFileURL }

        let game = Game(
            id: existing?.id ?? UUID(),
            name: existing?.name ?? path.lastPathComponent,
            path: path,
            executable: executable,
            engine: engine,
            launchArgs: existing?.launchArgs ?? [],
            detectedAt: existing?.detectedAt ?? Date(),
            lastPlayed: existing?.lastPlayed,
            notes: existing?.notes ?? "",
            rating: existing?.userRated == true ? existing?.rating : nil,
            userRated: existing?.userRated ?? false,
            playtime: existing?.playtime ?? 0
        )

        var library = loadLibrary()
        library.removeAll { $0.path == game.path }
        library.append(game)
        try saveLibrary(library)

        return game
    }

    static func isValidExecutable(_ executable: String, in directory: URL) -> Bool {
        executable == URL(fileURLWithPath: executable).lastPathComponent &&
        executable.lowercased().hasSuffix(".exe") &&
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(executable).path)
    }

    /// 根据名称查找游戏
    public func findGame(named name: String) -> Game? {
        loadLibrary().first { game in
            game.name.localizedCaseInsensitiveContains(name) ||
            game.name == name
        }
    }

    /// 移除游戏
    public func removeGame(id: UUID) throws {
        var library = loadLibrary()
        library.removeAll { $0.id == id }
        try saveLibrary(library)
    }

    /// 检查路径是否可访问（外接硬盘可能未挂载）
    public func isPathAccessible(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
