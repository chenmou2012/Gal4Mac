import Foundation

/// 游戏库管理器
///
/// 扫描本地游戏目录、缓存游戏信息、提供游戏列表
public final class LibraryManager {

    /// 游戏库配置文件路径
    public static var configFile: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("Gal4Mac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }

    private let detector = EngineDetector()

    public init() {}

    /// 加载已保存的游戏库
    public func loadLibrary() -> [Game] {
        guard let data = try? Data(contentsOf: Self.configFile),
              let games = try? JSONDecoder().decode([Game].self, from: data) else {
            return []
        }
        return games
    }

    /// 保存游戏库
    public func saveLibrary(_ games: [Game]) throws {
        let data = try JSONEncoder().encode(games)
        try data.write(to: Self.configFile, options: .atomic)
    }

    /// 扫描目录，添加新游戏到库
    @discardableResult
    public func scan(directory: URL) throws -> [Game] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var foundGames: [Game] = []

        for item in contents {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }

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

        // 合并到现有库
        var library = loadLibrary()
        for game in foundGames {
            if !library.contains(where: { $0.path == game.path }) {
                library.append(game)
                print("✓ 发现游戏: \(game.name) (\(game.engine.displayName))")
            }
        }

        try saveLibrary(library)
        return foundGames
    }

    /// 根据名称查找游戏
    public func findGame(named name: String) -> Game? {
        loadLibrary().first { game in
            game.name.localizedCaseInsensitiveContains(name) ||
            game.name == name
        }
    }
}
