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
        case pathUnavailable(URL)
        case noLibraryScanned

        public var errorDescription: String? {
            switch self {
            case .invalidExecutable: return "请选择游戏目录中的 .exe 可执行文件"
            case .pathUnavailable(let path): return "游戏库路径不可访问：\(path.path)"
            case .noLibraryScanned: return "没有可访问的游戏库路径，请检查外接磁盘或目录权限"
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
    private let storageDirectory: URL?

    public init(storageDirectory: URL? = nil) {
        self.storageDirectory = storageDirectory
    }

    private var libraryFileURL: URL {
        storageDirectory?.appendingPathComponent("library.json") ?? Self.libraryFile
    }

    private var configFileURL: URL {
        storageDirectory?.appendingPathComponent("config.json") ?? Self.configFile
    }

    /// 按路径组件判断归属，避免 /Games/Gal 匹配 /Games/GalExtra。
    public static func isWithin(_ path: URL, root: URL) -> Bool {
        path.standardizedFileURL.pathComponents.starts(with: root.standardizedFileURL.pathComponents)
    }

    // MARK: - 配置管理

    /// 加载库配置
    public func loadConfig() -> LibraryConfig {
        guard let data = try? Data(contentsOf: configFileURL),
              let config = try? JSONDecoder().decode(LibraryConfig.self, from: data) else {
            // 首次启动：返回默认配置（包含一个默认路径）
            return LibraryConfig(libraryPaths: [LibraryConfig.defaultPath])
        }
        return config
    }

    /// 保存库配置
    public func saveConfig(_ config: LibraryConfig) throws {
        let data = try JSONEncoder().encode(config)
        try FileManager.default.createDirectory(at: configFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: configFileURL, options: .atomic)
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
        guard let data = try? Data(contentsOf: libraryFileURL),
              let games = try? JSONDecoder().decode([Game].self, from: data) else {
            return []
        }
        return games
    }

    /// 保存游戏库
    public func saveLibrary(_ games: [Game]) throws {
        let data = try JSONEncoder().encode(games)
        try FileManager.default.createDirectory(at: libraryFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: libraryFileURL, options: .atomic)
    }

    /// 扫描所有配置的库路径
    @discardableResult
    public func scanAll() throws -> [Game] {
        let config = loadConfig()
        var allFound: [Game] = []
        var scannedPaths: [URL] = []
        var failedPaths: [URL] = []
        for path in config.libraryPaths {
            do {
                let found = try scan(directory: path, mergeToGlobal: false)
                allFound.append(contentsOf: found)
                scannedPaths.append(path)
            } catch {
                failedPaths.append(path)
                print("⚠️ 扫描失败: \(path.path) - \(error.localizedDescription)")
            }
        }
        if scannedPaths.isEmpty && !config.libraryPaths.isEmpty {
            throw LibraryError.noLibraryScanned
        }
        // 合并到全局库
        var library = loadLibrary()
        mergeScannedGames(allFound, into: &library)
        // 仅清理成功扫描的库，保留暂时离线或不可读路径中的游戏记录。
        library.removeAll { game in
            scannedPaths.contains { Self.isWithin(game.path, root: $0) } &&
                !failedPaths.contains { Self.isWithin(game.path, root: $0) } &&
                !FileManager.default.fileExists(atPath: game.path.path)
        }

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
            throw LibraryError.pathUnavailable(directory)
        }

        let contents = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

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
            mergeScannedGames(foundGames, into: &library)
            try saveLibrary(library)
        }

        return foundGames
    }

    /// 将扫描结果合并到已保存条目：修正引擎/可执行文件，同时保留时长等用户数据。
    private func mergeScannedGames(_ scannedGames: [Game], into library: inout [Game]) {
        for scanned in scannedGames {
            guard let index = library.firstIndex(where: {
                $0.path.standardizedFileURL == scanned.path.standardizedFileURL
            }) else {
                library.append(scanned)
                print("✓ 发现游戏: \(scanned.name) (\(scanned.engine.displayName))")
                continue
            }

            library[index].engine = scanned.engine
            library[index].executable = scanned.executable
        }
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
