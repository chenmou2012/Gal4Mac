import Foundation
import SwiftUI
import Gal4MacCore

/// 游戏库视图模型
@MainActor
final class GameLibraryViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var config: LibraryConfig = LibraryConfig()
    @Published var isScanning = false
    @Published var lastError: String?
    @Published var showingAddLibrary = false
    @Published var showingAddGame = false
    @Published var showingImportGame = false
    @Published var showingSavesFor: Game?
    @Published var launchingGameId: UUID?

    private let manager = LibraryManager()
    private let launcher = GameLauncher()

    init() {
        loadAll()
    }

    /// 加载所有数据
    func loadAll() {
        games = manager.loadLibrary()
        config = manager.loadConfig()
    }

    /// 扫描所有库
    func scanAll() {
        isScanning = true
        lastError = nil
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let scanner = LibraryManager()
                let found = try scanner.scanAll()
                let config = scanner.loadConfig()
                await MainActor.run {
                    self.games = found
                    self.config = config
                    self.isScanning = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.isScanning = false
                }
            }
        }
    }

    /// 扫描单个目录
    func scan(directory: URL) {
        isScanning = true
        lastError = nil
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let scanner = LibraryManager()
                _ = try scanner.scan(directory: directory)
                let library = scanner.loadLibrary()
                await MainActor.run {
                    self.games = library
                    self.isScanning = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.isScanning = false
                }
            }
        }
    }

    /// 添加库路径
    func addLibrary(_ url: URL) {
        do {
            config = try manager.addLibraryPath(url)
            scanAll()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 移除库路径
    func removeLibrary(_ url: URL) {
        do {
            config = try manager.removeLibraryPath(url)
            // 移除该路径下的游戏
            games.removeAll { $0.path.path.hasPrefix(url.path) }
            try manager.saveLibrary(games)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 手动添加单个游戏
    func addGame(at url: URL, engine: EngineType? = nil, executable: String? = nil) {
        do {
            if let game = try manager.addGame(at: url, engine: engine, executable: executable) {
                if let index = games.firstIndex(where: { $0.path == game.path }) {
                    games[index] = game
                } else {
                    games.append(game)
                }
                lastError = "✓ 已导入: \(game.name) (\(game.engine.displayName))"
            } else {
                lastError = "未找到可执行文件。请确认选择的是游戏根目录。"
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 从压缩包导入（解压后导入）
    func importArchive(at url: URL) {
        // 这个方法现在主要由 ImportGameSheet 直接处理
        addGame(at: url)
    }

    /// 启动游戏
    func launch(_ game: Game) {
        launchingGameId = game.id
        do {
            try launcher.launchAsync(game: game) { [weak self] elapsed in
                guard let self else { return }
                Task { @MainActor in
                    self.launchingGameId = nil
                    // 累加游玩时长
                    if let index = self.games.firstIndex(where: { $0.id == game.id }) {
                        self.games[index].playtime += elapsed
                        self.games[index].lastPlayed = Date()
                        try? self.manager.saveLibrary(self.games)
                    }
                }
            }
        } catch {
            launchingGameId = nil
            lastError = error.localizedDescription
        }
    }

    /// 总游戏时长
    var totalPlaytime: TimeInterval {
        games.reduce(0) { $0 + $1.playtime }
    }

    /// 总游戏时长（人类可读）
    var totalPlaytimeDescription: String {
        Game.formatDuration(totalPlaytime)
    }

    /// 移除游戏
    func removeGame(_ game: Game) {
        games.removeAll { $0.id == game.id }
        do {
            try manager.removeGame(id: game.id)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 更新游戏评分
    func updateRating(for game: Game, rating: Int) {
        guard let index = games.firstIndex(where: { $0.id == game.id }) else { return }
        var updated = games[index]
        updated.rating = rating > 0 ? rating : Game.defaultRating(for: game.engine)
        updated.userRated = rating > 0
        games[index] = updated
        do {
            try manager.saveLibrary(games)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 检查路径是否可访问
    func isAccessible(_ url: URL) -> Bool {
        manager.isPathAccessible(url)
    }
}
