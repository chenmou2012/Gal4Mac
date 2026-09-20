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
                let found = try self.manager.scanAll()
                await MainActor.run {
                    self.games = found
                    self.config = self.manager.loadConfig()
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
                _ = try self.manager.scan(directory: directory)
                let library = self.manager.loadLibrary()
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
    func addGame(at url: URL) {
        do {
            if let game = try manager.addGame(at: url) {
                if !games.contains(where: { $0.path == game.path }) {
                    games.append(game)
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// 启动游戏
    func launch(_ game: Game) {
        launchingGameId = game.id
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                try self.launcher.launch(game: game)
                await MainActor.run {
                    self.launchingGameId = nil
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.launchingGameId = nil
                }
            }
        }
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

    /// 检查路径是否可访问
    func isAccessible(_ url: URL) -> Bool {
        manager.isPathAccessible(url)
    }
}
