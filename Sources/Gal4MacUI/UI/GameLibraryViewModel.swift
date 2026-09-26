import Foundation
import SwiftUI
import Gal4MacCore

struct GameLaunchStatus: Equatable {
    let gameName: String
    let message: String
    let detail: String?
    let symbol: String
    let isInProgress: Bool
}

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
    @Published var canStopGame = false
    @Published var isStoppingGame = false
    @Published var launchStatus: GameLaunchStatus?
    @Published var steamMetadata: [UUID: SteamGameMetadata] = [:]
    @Published var loadingSteamMetadata: Set<UUID> = []
    @Published private var gameSizes: [UUID: String] = [:]

    private let manager = LibraryManager()
    private var requestedSteamMetadata: Set<UUID> = []
    private var activeLaunchToken: UUID?
    private var activeGameProcess: Process?
    private var activeWinePrefix: URL?
    private var sizeScanTask: Task<Void, Never>?
    private var sizeScanToken = UUID()

    init() {
        loadAll()
        if games.isEmpty, config.libraryPaths.contains(where: manager.isPathAccessible) {
            scanAll()
        }
    }

    /// 加载所有数据
    func loadAll() {
        games = manager.loadLibrary()
        config = manager.loadConfig()
        requestedSteamMetadata = []
        steamMetadata = [:]
        refreshGameSizes()
    }

    func gameSizeDescription(for game: Game) -> String {
        gameSizes[game.id] ?? "计算中…"
    }

    /// 在后台逐个统计大小，并缓存到下次扫描。
    private func refreshGameSizes(recalculate: Bool = false) {
        sizeScanTask?.cancel()
        sizeScanToken = UUID()
        let token = sizeScanToken
        if recalculate { gameSizes.removeAll() }
        let ids = Set(games.map(\.id))
        gameSizes = gameSizes.filter { ids.contains($0.key) }
        let pending = games.filter { gameSizes[$0.id] == nil }
        sizeScanTask = Task.detached(priority: .utility) { [weak self] in
            for game in pending {
                if Task.isCancelled { return }
                let description = FileManager.default.fileExists(atPath: game.path.path)
                    ? game.sizeDescription : "路径不可用"
                await MainActor.run { [weak self] in
                    guard let self, self.sizeScanToken == token,
                          self.games.contains(where: { $0.id == game.id }) else { return }
                    self.gameSizes[game.id] = description
                }
            }
        }
    }

    func loadSteamMetadata(for game: Game) {
        guard !requestedSteamMetadata.contains(game.id) else { return }
        requestedSteamMetadata.insert(game.id)
        loadingSteamMetadata.insert(game.id)
        Task {
            do {
                let executableName = URL(fileURLWithPath: game.executable).deletingPathExtension().lastPathComponent
                let metadata = try await SteamMetadataService.lookup(names: [
                    game.name,
                    game.path.deletingPathExtension().lastPathComponent,
                    executableName
                ])
                if let metadata {
                    steamMetadata[game.id] = metadata
                }
            } catch {
                // Keep local library details available when Steam cannot be reached.
            }
            loadingSteamMetadata.remove(game.id)
        }
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
                    self.refreshGameSizes(recalculate: true)
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
                    self.refreshGameSizes(recalculate: true)
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
            games.removeAll { game in
                LibraryManager.isWithin(game.path, root: url) &&
                    !config.libraryPaths.contains { LibraryManager.isWithin(game.path, root: $0) }
            }
            try manager.saveLibrary(games)
            refreshGameSizes()
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
                gameSizes.removeValue(forKey: game.id)
                refreshGameSizes()
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
        guard launchingGameId == nil else { return }
        let launchToken = UUID()
        activeLaunchToken = launchToken
        launchingGameId = game.id
        canStopGame = false
        isStoppingGame = false
        activeGameProcess = nil
        activeWinePrefix = nil
        launchStatus = GameLaunchStatus(
            gameName: game.name,
            message: GameLaunchStage.checkingEnvironment.message,
            detail: game.engine.displayName,
            symbol: GameLaunchStage.checkingEnvironment.symbol,
            isInProgress: true
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try GameLauncher().launchAsync(
                    game: game,
                    onProgress: { stage in
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.activeLaunchToken == launchToken else { return }
                            self.launchStatus = GameLaunchStatus(
                                gameName: game.name,
                                message: stage.message,
                                detail: game.engine.displayName,
                                symbol: stage.symbol,
                                isInProgress: true
                            )
                        }
                    },
                    onProcessStarted: { process, prefix in
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.activeLaunchToken == launchToken else { return }
                            self.activeGameProcess = process
                            self.activeWinePrefix = prefix
                            self.canStopGame = true
                        }
                    },
                    onExit: { [weak self] elapsed in
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.activeLaunchToken == launchToken else { return }
                            let wasStoppedByUser = self.isStoppingGame
                            self.launchingGameId = nil
                            self.canStopGame = false
                            self.isStoppingGame = false
                            self.activeGameProcess = nil
                            self.activeWinePrefix = nil
                            self.launchStatus = GameLaunchStatus(
                                gameName: game.name,
                                message: wasStoppedByUser ? "游戏已停止" : "游戏已退出",
                                detail: "本次游玩 \(Game.formatDuration(elapsed))",
                                symbol: wasStoppedByUser ? "stop.circle.fill" : "checkmark.circle.fill",
                                isInProgress: false
                            )
                            self.scheduleLaunchStatusClear(token: launchToken)

                            // 累加时长
                            if let index = self.games.firstIndex(where: { $0.id == game.id }) {
                                self.games[index].playtime += elapsed
                                self.games[index].lastPlayed = Date()
                                try? self.manager.saveLibrary(self.games)
                            }
                        }
                    }
                )
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.activeLaunchToken == launchToken else { return }
                    self.launchingGameId = nil
                    self.canStopGame = false
                    self.isStoppingGame = false
                    self.activeGameProcess = nil
                    self.activeWinePrefix = nil
                    self.launchStatus = GameLaunchStatus(
                        gameName: game.name,
                        message: "启动失败",
                        detail: error.localizedDescription,
                        symbol: "exclamationmark.triangle.fill",
                        isInProgress: false
                    )
                    self.lastError = error.localizedDescription
                    self.scheduleLaunchStatusClear(token: launchToken)
                }
            }
        }
    }

    /// 停止当前由 Gal4Mac 启动的游戏。
    func stopGame() {
        guard canStopGame,
              !isStoppingGame,
              let process = activeGameProcess,
              let prefix = activeWinePrefix,
              let launchToken = activeLaunchToken,
              let game = games.first(where: { $0.id == launchingGameId }) else { return }

        isStoppingGame = true
        launchStatus = GameLaunchStatus(
            gameName: game.name,
            message: "正在停止游戏",
            detail: game.engine.displayName,
            symbol: "stop.fill",
            isInProgress: true
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try GameLauncher().stop(process: process, prefix: prefix)
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.activeLaunchToken == launchToken else { return }
                    self.isStoppingGame = false
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private func scheduleLaunchStatusClear(token: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.activeLaunchToken == token else { return }
            self.launchStatus = nil
            self.activeLaunchToken = nil
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
        refreshGameSizes()
        do {
            try manager.removeGame(id: game.id)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateWineLocale(for game: Game, locale: WineLocale) {
        guard let index = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[index].wineLocale = locale
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
