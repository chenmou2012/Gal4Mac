import AppKit
import Foundation
import Gal4MacCore

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var games: [Game] = []
    @Published private(set) var config = LibraryConfig()
    @Published private(set) var isScanning = false
    @Published private(set) var launchingID: UUID?
    @Published private(set) var canStop = false
    @Published var showingImportWizard = false
    @Published var status: String?
    @Published var error: String?
    @Published private(set) var steamMetadata: [Int: SteamGameMetadata] = [:]
    @Published private(set) var loadingSteamAppIDs: Set<Int> = []

    private let manager = LibraryManager()
    private var process: Process?
    private var prefix: URL?
    private var launchToken: UUID?

    init() {
        reload()
    }

    var totalPlaytime: TimeInterval { games.reduce(0) { $0 + $1.playtime } }
    var mostRecent: Game? { games.filter { $0.lastPlayed != nil }.max { ($0.lastPlayed ?? .distantPast) < ($1.lastPlayed ?? .distantPast) } }
    var engineReady: Bool { EngineManager.isInstalled() }

    func reload() {
        games = manager.loadLibrary()
        config = manager.loadConfig()
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        status = "正在扫描游戏库…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try LibraryManager().scanAll() }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isScanning = false
                switch result {
                case .success:
                    self.reload()
                    self.status = "扫描完成 · \(self.games.count) 款游戏"
                case .failure(let error):
                    self.status = nil
                    self.error = error.localizedDescription
                }
            }
        }
    }

    func importGame(at url: URL, name: String, engine: EngineType, executable: String, locale: WineLocale, steamAppID: Int?) throws -> Game {
        guard let game = try manager.addGame(
            at: url,
            engine: engine,
            executable: executable,
            displayName: name,
            wineLocale: locale,
            steamAppID: steamAppID,
            clearSteamMatch: steamAppID == nil
        ) else {
            throw ImportError.noExecutable
        }
        reload()
        status = "已导入 \(game.name)"
        return game
    }

    func importExtractedGame(at url: URL, into libraryPath: URL, name: String, engine: EngineType, executable: String, locale: WineLocale, steamAppID: Int?, completion: @escaping (Result<Game, Error>) -> Void) {
        guard config.libraryPaths.contains(where: { $0.standardizedFileURL == libraryPath.standardizedFileURL }) else {
            completion(.failure(LibraryManager.LibraryError.pathUnavailable(libraryPath)))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result {
                try LibraryManager().importExtractedGame(
                    at: url,
                    into: libraryPath,
                    engine: engine,
                    executable: executable,
                    displayName: name,
                    wineLocale: locale,
                    steamAppID: steamAppID
                )
            }
            DispatchQueue.main.async {
                if case .success(let game) = result {
                    self?.reload()
                    self?.status = "已导入 \(game.name)"
                }
                completion(result)
            }
        }
    }

    func loadSteamMetadata(for game: Game) {
        guard let appID = game.steamAppID,
              steamMetadata[appID] == nil,
              !loadingSteamAppIDs.contains(appID) else { return }
        loadingSteamAppIDs.insert(appID)
        Task {
            if let metadata = try? await SteamMetadataService.details(appID: appID) {
                steamMetadata[appID] = metadata
            }
            loadingSteamAppIDs.remove(appID)
        }
    }

    func updateSteamAppID(for game: Game, to appID: Int) {
        guard appID > 0, let index = games.firstIndex(where: { $0.id == game.id }) else { return }
        let previous = games[index].steamAppID
        games[index].steamAppID = appID
        do { try manager.saveLibrary(games) }
        catch {
            games[index].steamAppID = previous
            self.error = error.localizedDescription
        }
    }

    enum ImportError: LocalizedError {
        case noExecutable
        var errorDescription: String? { "未找到可用的 .exe 文件。请选择游戏根目录。" }
    }

    func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.message = "选择用于扫描游戏的文件夹"
        panel.prompt = "添加游戏库"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            config = try manager.addLibraryPath(url)
            scan()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func removeLibraryFolder(_ url: URL) {
        do {
            config = try manager.removeLibraryPath(url)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateLocale(for game: Game, to locale: WineLocale) {
        guard let index = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[index].wineLocale = locale
        do { try manager.saveLibrary(games) }
        catch { self.error = error.localizedDescription }
    }

    func remove(_ game: Game) {
        do {
            try manager.removeGame(id: game.id)
            reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func launch(_ game: Game) {
        guard launchingID == nil else { return }
        let token = UUID()
        launchToken = token
        launchingID = game.id
        canStop = false
        status = "正在启动 \(game.name)…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try GameLauncher().launchAsync(
                    game: game,
                    onProgress: { stage in
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.launchToken == token else { return }
                            self.status = stage.message
                        }
                    },
                    onProcessStarted: { process, prefix in
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.launchToken == token else { return }
                            self.process = process
                            self.prefix = prefix
                            self.canStop = true
                            self.status = "\(game.name) 运行中"
                        }
                    },
                    onExit: { elapsed in
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.launchToken == token else { return }
                            self.launchingID = nil
                            self.canStop = false
                            self.process = nil
                            self.prefix = nil
                            self.status = "本次游玩 \(Game.formatDuration(elapsed))"
                            if let index = self.games.firstIndex(where: { $0.id == game.id }) {
                                self.games[index].playtime += elapsed
                                self.games[index].lastPlayed = Date()
                                do { try self.manager.saveLibrary(self.games) }
                                catch { self.error = error.localizedDescription }
                            }
                        }
                    }
                )
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.launchToken == token else { return }
                    self.launchingID = nil
                    self.canStop = false
                    self.status = nil
                    self.error = error.localizedDescription
                }
            }
        }
    }

    func stop() {
        guard canStop, let process, let prefix else { return }
        canStop = false
        status = "正在停止游戏…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do { try GameLauncher().stop(process: process, prefix: prefix) }
            catch {
                DispatchQueue.main.async { [weak self] in
                    self?.canStop = true
                    self?.error = error.localizedDescription
                }
            }
        }
    }
}
