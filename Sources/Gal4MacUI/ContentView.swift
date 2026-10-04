import AppKit
import Gal4MacCore
import SwiftUI

private enum SidebarItem: Hashable {
    case library
    case game(UUID)
}

private enum AppPage: String, CaseIterable, Hashable {
    case library, statistics, settings

    var title: String {
        switch self {
        case .library: "游戏库"
        case .statistics: "游玩统计"
        case .settings: "设置"
        }
    }

    var symbol: String {
        switch self {
        case .library: "square.grid.2x2"
        case .statistics: "chart.bar.xaxis"
        case .settings: "gearshape"
        }
    }
}

/// 应用配色，跟随系统浅色/深色外观。
enum GlassPalette {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let elevated = Color(nsColor: .underPageBackgroundColor)
    static let line = Color(nsColor: .separatorColor)
    static let blue = Color.accentColor
    static let secondary = Color.secondary
}

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @ObservedObject private var steamSession = SteamWebSession.shared
    @State private var page: AppPage = .library
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedGameID: UUID?
    @State private var search = ""
    @State private var engineFilter: EngineType?
    @State private var cloudGame: Game?
    @State private var steamMatchGame: Game?
    @State private var pendingSteamGame: Game?
    @State private var checkingSteamLogin = false
    @State private var steamSettingsMessage: String?
    @State private var settingsSteamOwnerID = UUID()
    @State private var gamePendingRemoval: Game?

    private var selectedGame: Game? { library.games.first { $0.id == selectedGameID } }
    private var filteredGames: [Game] {
        library.games.filter { game in
            (engineFilter == nil || game.engine == engineFilter) &&
            (search.isEmpty || game.name.localizedCaseInsensitiveContains(search))
        }
        .sorted {
            switch ($0.lastPlayed, $1.lastPlayed) {
            case let (left?, right?): left > right
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: Binding<SidebarItem?>(
                get: {
                    guard page == .library else { return nil }
                    return selectedGameID.map(SidebarItem.game) ?? .library
                },
                set: {
                    switch $0 {
                    case .library?: show(.library)
                    case .game(let id)?: page = .library; selectedGameID = id; pendingSteamGame = nil
                    case nil: break
                    }
                }
            )) {
                Label(AppPage.library.title, systemImage: AppPage.library.symbol).tag(SidebarItem.library)
                Section("游戏 · \(library.games.count)") {
                    ForEach(library.games.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { game in
                        Text(game.name).lineLimit(1).help(game.name).tag(SidebarItem.game(game.id))
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 2) {
                    ForEach([AppPage.statistics, .settings], id: \.self) { item in
                        Button { show(item) } label: {
                            Label(item.title, systemImage: item.symbol)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(page == item ? Color.accentColor.opacity(0.25) : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
            }
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            Group {
                switch page {
                case .library:
                    if let game = selectedGame { gameDetail(game) } else { libraryPage }
                case .statistics: statisticsPage
                case .settings: settingsPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) { statusBar }
            .navigationTitle(page == .library ? (selectedGame?.name ?? page.title) : page.title)
            .toolbar { toolbarContent }
        }
        .onChange(of: columnVisibility) { _, visibility in
            if visibility != .all { columnVisibility = .all }
        }
        .sheet(isPresented: $library.showingImportWizard) {
            ImportWizardView { game in
                page = .library
                selectedGameID = game.id
            }
            .environmentObject(library)
        }
        .sheet(item: $cloudGame) { game in
            if let appID = game.steamAppID {
                SteamCloudSheet(game: game, appID: appID) {
                    cloudGame = nil
                    pendingSteamGame = game
                    page = .settings
                    selectedGameID = nil
                }
            }
        }
        .sheet(item: $steamMatchGame) { game in
            SteamMatchSheet(game: game) { appID in
                library.updateSteamAppID(for: game, to: appID)
            }
        }
        .confirmationDialog(
            "从游戏库移除？",
            isPresented: Binding(
                get: { gamePendingRemoval != nil },
                set: { if !$0 { gamePendingRemoval = nil } }
            ),
            presenting: gamePendingRemoval
        ) { game in
            Button("移除 \(game.name)", role: .destructive) {
                library.remove(game)
                gamePendingRemoval = nil
            }
            Button("取消", role: .cancel) { gamePendingRemoval = nil }
        } message: { _ in
            Text("只移除游戏库记录，不会删除游戏文件。")
        }
        .alert("操作失败", isPresented: Binding(
            get: { library.error != nil },
            set: { if !$0 { library.error = nil } }
        )) {
            Button("好") { library.error = nil }
        } message: {
            Text(library.error ?? "")
        }
        .onChange(of: library.games.map(\.id)) { _, ids in
            if let selectedGameID, !ids.contains(selectedGameID) { self.selectedGameID = nil }
        }
        .onChange(of: steamSession.authentication) { _, authentication in
            guard authentication == .signedIn, let game = pendingSteamGame else { return }
            pendingSteamGame = nil
            steamSettingsMessage = nil
            page = .library
            selectedGameID = game.id
            cloudGame = game
        }
    }

    private func show(_ item: AppPage) {
        page = item
        selectedGameID = nil
        if item != .settings { pendingSteamGame = nil }
    }

    // MARK: - 工具栏

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        if page == .library, selectedGame != nil {
            ToolbarItem(placement: .navigation) {
                Button { selectedGameID = nil } label: {
                    Label("返回游戏库", systemImage: "chevron.left")
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            if page == .library, selectedGame == nil {
                Menu {
                    Picker("引擎", selection: $engineFilter) {
                        Text("全部引擎").tag(EngineType?.none)
                        ForEach(EngineType.allCases.filter { $0 != .unknown }, id: \.self) { engine in
                            Text(engine.displayName).tag(Optional(engine))
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("按引擎筛选", systemImage: engineFilter == nil
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                .help("按引擎筛选")
            }
            Button { library.scan() } label: { Label("重新扫描", systemImage: "arrow.clockwise") }
                .help("重新扫描游戏库")
                .disabled(library.isScanning)
            Button { library.showingImportWizard = true } label: { Label("导入游戏", systemImage: "plus") }
                .help("导入游戏")
        }
    }

    // MARK: - 游戏库

    private var libraryPage: some View {
        Group {
            if filteredGames.isEmpty {
                emptyLibrary
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 20)], alignment: .leading, spacing: 24) {
                        ForEach(filteredGames) { game in
                            Button { selectedGameID = game.id } label: { GameCard(game: game) }
                                .buttonStyle(.plain)
                                .accessibilityLabel("查看 \(game.name) 的详情")
                                .contextMenu { gameMenu(for: game) }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "搜索游戏")
    }

    @ViewBuilder private var emptyLibrary: some View {
        if !search.isEmpty || engineFilter != nil {
            ContentUnavailableView {
                Label("没有找到匹配的游戏", systemImage: "magnifyingglass")
            } description: {
                Text("试试其他名称或选择全部引擎。")
            } actions: {
                Button("清除筛选") {
                    search = ""
                    engineFilter = nil
                }
            }
        } else {
            ContentUnavailableView {
                Label("还没有游戏", systemImage: "square.stack.3d.up")
            } description: {
                Text("导入一个游戏文件夹，或在设置中添加游戏库路径。")
            } actions: {
                Button("导入游戏…") { library.showingImportWizard = true }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder private func gameMenu(for game: Game) -> some View {
        Button("启动游戏") { library.launch(game) }
            .disabled(!canLaunch(game))
        Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([game.path]) }
        Divider()
        Button("从游戏库移除…", role: .destructive) { gamePendingRemoval = game }
    }

    private func canLaunch(_ game: Game) -> Bool {
        library.launchingID == nil && FileManager.default.fileExists(atPath: game.path.path)
    }

    // MARK: - 游戏详情

    private func gameDetail(_ game: Game) -> some View {
        let metadata = game.steamAppID.flatMap { library.steamMetadata[$0] }
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 20) {
                    GameArtwork(game: game)
                        .frame(width: 120, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(game.name)
                            .font(.title.bold())
                            .textSelection(.enabled)
                        Text("\(game.engine.displayName) · 已游玩 \(game.playtimeDescription) · \(compatibilityLabel(game))")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        HStack(spacing: 8) { gameActionButtons(for: game) }
                            .controlSize(.large)
                    }
                }
                .frame(minHeight: 160)

                if let metadata {
                    VStack(alignment: .leading, spacing: 8) {
                        if let description = metadata.description {
                            Text(description)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 14) {
                            if let developer = metadata.developers.first { Text("开发：\(developer)") }
                            if let release = metadata.releaseDate { Text("发行：\(release)") }
                            Link("Steam 商店", destination: URL(string: "https://store.steampowered.com/app/\(metadata.appID)/")!)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else if let appID = game.steamAppID, library.loadingSteamAppIDs.contains(appID) {
                    ProgressView("正在加载 Steam 介绍…").controlSize(.small)
                }

                GroupBox {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow {
                            Text("语言环境").foregroundStyle(.secondary)
                            Picker("语言环境", selection: Binding(
                                get: { game.wineLocale },
                                set: { library.updateLocale(for: game, to: $0) }
                            )) {
                                Text("自动").tag(WineLocale.automatic)
                                Text("简体中文").tag(WineLocale.simplifiedChinese)
                                Text("日语").tag(WineLocale.japanese)
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                        GridRow {
                            Text("可执行文件").foregroundStyle(.secondary)
                            Text(game.executable).textSelection(.enabled)
                        }
                        GridRow {
                            Text("游戏目录").foregroundStyle(.secondary)
                            Text(game.path.path)
                                .font(.callout.monospaced())
                                .textSelection(.enabled)
                                .lineLimit(3)
                        }
                        GridRow {
                            Text("上次游玩").foregroundStyle(.secondary)
                            Text(game.lastPlayed?.formatted(date: .abbreviated, time: .shortened) ?? "尚未游玩")
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("从游戏库移除…", role: .destructive) { gamePendingRemoval = game }
                    .help("只移除游戏库记录，不删除游戏文件")
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(24)
        }
        .task(id: game.steamAppID) { library.loadSteamMetadata(for: game) }
    }

    @ViewBuilder private func gameActionButtons(for game: Game) -> some View {
        if library.launchingID == game.id {
            Button("停止游戏") { library.stop() }
                .disabled(!library.canStop)
        } else {
            Button { library.launch(game) } label: { Label("启动游戏", systemImage: "play.fill") }
                .buttonStyle(.borderedProminent)
                .disabled(!canLaunch(game))
        }
        Button { NSWorkspace.shared.activateFileViewerSelecting([game.path]) } label: {
            Label("在 Finder 中显示", systemImage: "folder")
        }
        if game.steamAppID != nil {
            Button { syncSteamSaves(for: game) } label: {
                Label(checkingSteamLogin ? "检查 Steam 登录…" : "同步 Steam 存档", systemImage: "icloud.and.arrow.down")
            }
            .disabled(checkingSteamLogin || library.launchingID == game.id)
        } else {
            Button { steamMatchGame = game } label: {
                Label("匹配 Steam 游戏", systemImage: "magnifyingglass")
            }
        }
    }

    private func syncSteamSaves(for game: Game) {
        guard game.steamAppID != nil, !checkingSteamLogin else { return }
        checkingSteamLogin = true
        steamSession.verifyAuthentication { signedIn in
            checkingSteamLogin = false
            if signedIn {
                cloudGame = game
            } else {
                pendingSteamGame = game
                page = .settings
                selectedGameID = nil
                steamSettingsMessage = steamSession.authentication == .unavailable
                    ? "无法连接 Steam，请检查网络后刷新登录状态。"
                    : nil
            }
        }
    }

    private func compatibilityLabel(_ game: Game) -> String {
        switch game.engine.compatibility {
        case .excellent, .good, .native: "兼容性良好"
        case .experimental: "实验性兼容"
        case .unsupported: "兼容性未知"
        }
    }

    // MARK: - 统计

    private var statisticsPage: some View {
        let games = library.games
        let ranked = games.filter { $0.playtime > 0 }.sorted { $0.playtime > $1.playtime }
        let recent = games.filter { $0.lastPlayed != nil }
            .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        let recentCount = recent.filter { ($0.lastPlayed ?? .distantPast) >= cutoff }.count
        let average = ranked.isEmpty ? "—" : Game.formatDuration(library.totalPlaytime / Double(ranked.count))
        let engineCounts = EngineType.allCases
            .map { engine in (engine: engine, count: games.filter { $0.engine == engine }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    metric("累计时长", value: Game.formatDuration(library.totalPlaytime))
                    metric("游戏总数", value: "\(games.count)")
                    metric("已游玩", value: "\(ranked.count)")
                    metric("未游玩", value: "\(games.count - ranked.count)")
                    metric("近 30 天游玩", value: "\(recentCount)")
                    metric("平均每款时长", value: average)
                    metric("最常玩", value: ranked.first?.name ?? "—")
                    metric("最近游玩", value: recent.first?.name ?? "—")
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { statisticsPanels(ranked, engineCounts, games.count) }
                    VStack(spacing: 16) { statisticsPanels(ranked, engineCounts, games.count) }
                }

                GroupBox("最近游玩") {
                    if recent.isEmpty {
                        emptyHint("游戏正常退出后，这里会显示最近的游玩记录。")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(recent.prefix(8).enumerated()), id: \.element.id) { index, game in
                                if index > 0 { Divider() }
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(game.name).lineLimit(1)
                                        Text(game.engine.displayName).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(game.playtimeDescription).monospacedDigit()
                                        Text(game.lastPlayed?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }

                Text("统计仅保存在本机，随每次游戏结束更新。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(24)
        }
    }

    @ViewBuilder private func statisticsPanels(_ ranked: [Game], _ engineCounts: [(engine: EngineType, count: Int)], _ total: Int) -> some View {
        GroupBox("游玩时长排行") {
            if ranked.isEmpty {
                emptyHint("游戏正常退出后，这里会显示累计时长。")
            } else {
                VStack(spacing: 12) {
                    ForEach(ranked.prefix(8)) { game in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(game.name).lineLimit(1)
                                Spacer(minLength: 8)
                                Text(game.playtimeDescription).monospacedDigit().foregroundStyle(.secondary)
                            }
                            ProgressView(value: game.playtime, total: max(ranked[0].playtime, 1))
                        }
                    }
                }
                .padding(8)
            }
        }
        GroupBox("引擎分布") {
            if engineCounts.isEmpty {
                emptyHint("导入游戏后，这里会显示引擎分布。")
            } else {
                VStack(spacing: 12) {
                    ForEach(engineCounts, id: \.engine) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(item.engine.displayName).lineLimit(1)
                                Spacer(minLength: 8)
                                Text("\(item.count) · \(Int((Double(item.count) / Double(max(total, 1)) * 100).rounded()))%")
                                    .monospacedDigit().foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(item.count), total: Double(max(total, 1)))
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
    }

    private func metric(_ title: String, value: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.title3.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }

    // MARK: - 设置

    private var settingsPage: some View {
        Form {
            Section("游戏库位置") {
                ForEach(library.config.libraryPaths, id: \.self) { path in
                    HStack {
                        Label(path.path, systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button { library.removeLibraryFolder(path) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("移除游戏库路径 \(path.path)")
                    }
                }
                Button("添加文件夹…") { library.chooseLibraryFolder() }
            }

            Section("运行环境") {
                LabeledContent("Mythic Engine") {
                    Label(library.engineReady ? "已就绪" : "未检测到",
                          systemImage: library.engineReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(library.engineReady ? .green : .orange)
                }
            }

            Section {
                if let game = pendingSteamGame {
                    Label("登录后继续同步 \(game.name) 的云存档。", systemImage: "icloud.and.arrow.down")
                        .foregroundStyle(.tint)
                }
                LabeledContent("状态") {
                    HStack {
                        Text(steamSession.authentication == .signedIn ? "已登录" : "未登录")
                        Button("刷新") { steamSession.verifyAuthentication { _ in } }
                            .disabled(steamSession.authentication == .checking)
                        if steamSession.authentication == .signedIn {
                            Button("退出登录", role: .destructive) {
                                Task { await steamSession.signOut() }
                            }
                        }
                    }
                }
                if let steamSettingsMessage {
                    Text(steamSettingsMessage).foregroundStyle(.orange)
                }
                if steamSession.authentication != .signedIn {
                    SteamRemoteStorageWebView(
                        ownerID: settingsSteamOwnerID,
                        pageURL: SteamWebSession.accountURL,
                        onDownloaded: { url, _ in
                            try? FileManager.default.removeItem(at: url)
                            steamSettingsMessage = "请从游戏详情页同步该游戏的存档。"
                        },
                        onError: { steamSettingsMessage = $0 }
                    )
                    .frame(height: 360)
                    .onDisappear { steamSession.release(ownerID: settingsSteamOwnerID) }
                }
            } header: {
                Text("Steam 账户")
            } footer: {
                Text(steamSession.authentication == .signedIn ? "登录状态保存在这台 Mac 上。" : "在上方网页登录 Steam，登录状态保存在这台 Mac 上。")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 720)
    }

    // MARK: - 状态提示

    @ViewBuilder private var statusBar: some View {
        if let status = library.status {
            let busy = library.isScanning || library.launchingID != nil
            HStack(spacing: 10) {
                if busy { ProgressView().controlSize(.small) }
                Text(status).font(.callout).lineLimit(2)
                if !busy {
                    Button { library.status = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("关闭状态提示")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .padding(.bottom, 16)
            .frame(maxWidth: 480)
        }
    }
}

private struct GameCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GameArtwork(game: game)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(GlassPalette.line))
            Text(game.name).font(.callout.weight(.medium)).lineLimit(1)
            Text(game.playtime > 0 ? "\(game.engine.displayName) · \(game.playtimeDescription)" : game.engine.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}

@MainActor
private final class GameArtworkCache {
    static let shared = GameArtworkCache()
    private let images = NSCache<NSString, NSImage>()

    func image(for url: URL) -> NSImage? { images.object(forKey: url.path as NSString) }
    func insert(_ image: NSImage, for url: URL) { images.setObject(image, forKey: url.path as NSString) }
}

private struct GameArtwork: View {
    let game: Game
    @State private var artwork: NSImage?

    private var artworkURL: URL? {
        let names = ["cover.jpg", "cover.png", "Cover.jpg", "Cover.png", "poster.jpg", "poster.png", "icon.png"]
        for name in names {
            let url = game.path.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private var steamPosterURL: URL? {
        guard let appID = game.steamAppID else { return nil }
        return URL(string: "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/\(appID)/library_600x900.jpg")
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let artwork {
                    Image(nsImage: artwork).resizable().scaledToFill()
                } else if let steamPosterURL {
                    AsyncImage(url: steamPosterURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            placeholder(size: proxy.size)
                        }
                    }
                } else {
                    placeholder(size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
        .task(id: game.path) {
            guard let url = artworkURL else { return }
            if let cached = GameArtworkCache.shared.image(for: url) {
                artwork = cached
                return
            }
            let data = await Task.detached(priority: .utility) { try? Data(contentsOf: url) }.value
            guard !Task.isCancelled, let data, let image = NSImage(data: data) else { return }
            GameArtworkCache.shared.insert(image, for: url)
            artwork = image
        }
    }

    private func placeholder(size: CGSize) -> some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: "gamecontroller")
                .font(.system(size: min(size.width * 0.22, 40), weight: .light))
                .foregroundStyle(.secondary)
        }
    }
}
