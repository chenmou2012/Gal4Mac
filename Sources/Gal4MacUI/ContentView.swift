import AppKit
import Gal4MacCore
import SwiftUI

private enum AppPage: String, Hashable {
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

enum GlassPalette {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.085)
    static let surface = Color(red: 0.105, green: 0.115, blue: 0.145)
    static let elevated = Color(red: 0.14, green: 0.15, blue: 0.19)
    static let line = Color.white.opacity(0.09)
    static let blue = Color(red: 0.04, green: 0.51, blue: 1)
    static let secondary = Color(red: 0.68, green: 0.71, blue: 0.77)
}

struct ContentView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @ObservedObject private var steamSession = SteamWebSession.shared
    @State private var page: AppPage = .library
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedGameID: UUID?
    @State private var search = ""
    @State private var engineFilter: EngineType?
    @State private var cloudGame: Game?
    @State private var steamMatchGame: Game?
    @State private var pendingSteamGame: Game?
    @State private var checkingSteamLogin = false
    @State private var steamSettingsMessage: String?
    @State private var settingsSteamOwnerID = UUID()

    private var selectedGame: Game? { library.games.first { $0.id == selectedGameID } }
    private var filteredGames: [Game] {
        library.games.filter { game in
            (engineFilter == nil || game.engine == engineFilter) &&
            (search.isEmpty || game.name.localizedCaseInsensitiveContains(search) || game.engine.displayName.localizedCaseInsensitiveContains(search))
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
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            sidebar
                .toolbar(removing: .sidebarToggle)
        } detail: {
            ZStack {
                GlassPalette.background.ignoresSafeArea()
                if let game = selectedGame, page == .library {
                    gameDetail(game)
                } else {
                    switch page {
                    case .library: libraryPage
                    case .statistics: statisticsPage
                    case .settings: settingsPage
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack {
                    statusBar.frame(maxWidth: 320)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, library.status == nil ? 0 : 12)
            }
            .navigationTitle("")
            .removeDefaultToolbarTitle()
            .toolbar {
                if selectedGame != nil && page == .library {
                    ToolbarItem(placement: .navigation) {
                        Button { selectedGameID = nil } label: {
                            Label("返回游戏库", systemImage: "chevron.left")
                        }
                    }
                }
            }
        }
        .background {
            TitlebarBrandInstaller(library: library).frame(width: 0, height: 0)
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: splitViewVisibility) { _, visibility in
            if visibility != .all { splitViewVisibility = .all }
        }
        .tint(GlassPalette.blue)
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

    private var sidebar: some View {
        List {
            Button {
                page = .library
                selectedGameID = nil
                pendingSteamGame = nil
            } label: {
                Label("游戏库", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(page == .library && selectedGameID == nil ? GlassPalette.blue.opacity(0.22) : Color.clear)

            Section("游戏 · \(library.games.count)") {
                ForEach(library.games.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { game in
                    Button {
                        page = .library
                        selectedGameID = game.id
                        pendingSteamGame = nil
                    } label: {
                        Text(game.name)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(game.name)
                    .listRowBackground(selectedGameID == game.id && page == .library ? GlassPalette.blue.opacity(0.22) : Color.clear)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if library.launchingID != nil, let status = library.status {
                    HStack(alignment: .top, spacing: 10) {
                        ProgressView().controlSize(.small).padding(.top, 2)
                        Text(status)
                            .font(.caption)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(GlassPalette.elevated, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GlassPalette.line))
                    .padding(.bottom, 8)
                }
                Divider().padding(.bottom, 4)
                dockButton(.statistics)
                dockButton(.settings)
            }
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 6)
            .background(.regularMaterial)
        }
        .navigationSplitViewColumnWidth(min: 205, ideal: 228, max: 260)
    }

    private var libraryPage: some View {
        return ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageHeader("游戏库", subtitle: "你的游戏都在这里。") { EmptyView() }

                if let featured = library.mostRecent {
                    featuredCard(featured)
                }

                HStack(spacing: 12) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("搜索游戏或引擎", text: $search)
                            .textFieldStyle(.plain)
                            .accessibilityLabel("搜索游戏或引擎")
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .background(GlassPalette.elevated, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(GlassPalette.line))

                    Picker("引擎", selection: $engineFilter) {
                        Text("全部引擎").tag(EngineType?.none)
                        ForEach(EngineType.allCases.filter { $0 != .unknown }, id: \.self) { engine in
                            Text(engine.displayName).tag(Optional(engine))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("全部游戏").font(.title3.weight(.semibold))
                    Text("\(filteredGames.count)").foregroundStyle(.secondary)
                    Spacer()
                }

                if filteredGames.isEmpty {
                    emptyLibrary
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 230), spacing: 18)], alignment: .leading, spacing: 22) {
                        ForEach(filteredGames) { game in
                            Button {
                                selectedGameID = game.id
                            } label: {
                                GameCard(game: game)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("查看 \(game.name) 的详情")
                        }
                    }
                }
            }
            .frame(maxWidth: 1180, alignment: .leading)
            .padding(32)
        }
    }

    private var emptyLibrary: some View {
        VStack(spacing: 13) {
            Image(systemName: search.isEmpty ? "square.stack.3d.up" : "magnifyingglass")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(GlassPalette.secondary)
            Text(search.isEmpty ? "还没有游戏" : "没有找到匹配的游戏")
                .font(.title3.weight(.semibold))
            Text(search.isEmpty ? "导入一个游戏文件夹，或在设置中添加游戏库路径。" : "试试其他名称或选择全部引擎。")
                .foregroundStyle(.secondary)
            if search.isEmpty {
                Button("导入游戏…") { library.showingImportWizard = true }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 76)
        .background(GlassPalette.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(GlassPalette.line))
    }

    private func featuredCard(_ game: Game) -> some View {
        HStack(spacing: 24) {
            GameArtwork(game: game)
                .frame(width: 112, height: 145)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 10) {
                Label("继续游玩", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GlassPalette.secondary)
                Text(game.name).font(.system(size: 27, weight: .bold, design: .rounded)).lineLimit(2)
                Text("\(game.engine.displayName)  ·  已游玩 \(game.playtimeDescription)")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Button { library.launch(game) } label: {
                        Label("继续游玩", systemImage: "play.fill").frame(height: 40)
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(library.launchingID != nil || !FileManager.default.fileExists(atPath: game.path.path))
                    Button { selectedGameID = game.id } label: { Text("查看详情").frame(height: 40) }
                        .buttonStyle(.bordered)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(height: 190)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [GlassPalette.elevated, GlassPalette.surface, GlassPalette.background], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(GlassPalette.line))
    }

    private func gameDetail(_ game: Game) -> some View {
        let metadata = game.steamAppID.flatMap { library.steamMetadata[$0] }
        return ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .bottom, spacing: 24) {
                    let artwork = GameArtwork(game: game, showsPlaceholder: false)
                    if artwork.hasArtwork {
                        artwork
                            .frame(width: 156, height: 204)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    VStack(alignment: .leading, spacing: 11) {
                        Text(game.name)
                            .font(.system(size: 31, weight: .bold, design: .serif))
                        Text("已游玩 \(game.playtimeDescription)  ·  \(compatibilityLabel(game))")
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(24)
                .frame(minHeight: 250, alignment: .bottomLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(GlassPalette.surface)
                        .overlay {
                            detailHeroBackground(metadata?.libraryHeroURL ?? metadata?.backgroundURL ?? metadata?.headerURL)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(GlassPalette.line))

                HStack(spacing: 10) {
                    Button { library.launch(game) } label: {
                        Label(library.launchingID == game.id ? "运行中" : "启动游戏", systemImage: "play.fill")
                            .frame(height: 40)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(library.launchingID != nil || !FileManager.default.fileExists(atPath: game.path.path))
                    if library.launchingID == game.id && library.canStop {
                        Button { library.stop() } label: { Text("停止游戏").frame(height: 40) }
                            .buttonStyle(.bordered)
                    }
                    Button { NSWorkspace.shared.activateFileViewerSelecting([game.path]) } label: {
                        Label("在 Finder 中显示", systemImage: "folder")
                            .frame(height: 40)
                    }
                    .buttonStyle(.bordered)
                    if game.steamAppID != nil {
                        Button { syncSteamSaves(for: game) } label: {
                            Label(checkingSteamLogin ? "检查 Steam 登录…" : "同步 Steam 存档", systemImage: "icloud.and.arrow.down")
                                .frame(height: 40)
                        }
                        .buttonStyle(.bordered)
                        .disabled(checkingSteamLogin || library.launchingID == game.id)
                    } else {
                        Button { steamMatchGame = game } label: {
                            Label("匹配 Steam 游戏", systemImage: "magnifyingglass")
                                .frame(height: 40)
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer(minLength: 0)
                }

                if let metadata {
                    detailPanel("Steam 介绍", symbol: "text.alignleft") {
                        if let description = metadata.description {
                            Text(description)
                                .font(.callout)
                                .foregroundStyle(GlassPalette.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 14) {
                            if let developer = metadata.developers.first {
                                Text("开发：\(developer)")
                            }
                            if let release = metadata.releaseDate {
                                Text("发行：\(release)")
                            }
                            Spacer()
                            Link("Steam 商店", destination: URL(string: "https://store.steampowered.com/app/\(metadata.appID)/")!)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else if let appID = game.steamAppID, library.loadingSteamAppIDs.contains(appID) {
                    ProgressView("正在加载 Steam 介绍…").controlSize(.small)
                }

                HStack(alignment: .top, spacing: 18) {
                    detailPanel("游戏信息", symbol: "info.circle") {
                        infoRow("可执行文件", game.executable)
                        infoRow("上次游玩", game.lastPlayed?.formatted(date: .abbreviated, time: .shortened) ?? "尚未游玩")
                        VStack(alignment: .leading, spacing: 5) {
                            Text("游戏目录").font(.caption).foregroundStyle(.secondary)
                            Text(game.path.path).font(.caption.monospaced()).textSelection(.enabled)
                                .foregroundStyle(GlassPalette.secondary)
                                .lineLimit(3)
                        }
                    }
                    detailPanel("运行设置", symbol: "slider.horizontal.3") {
                        Text("每款游戏使用独立的 Wine 容器，启动时会自动应用对应引擎的配置。")
                            .font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Picker("Windows 语言环境", selection: Binding(
                            get: { game.wineLocale },
                            set: { library.updateLocale(for: game, to: $0) }
                        )) {
                            Text("自动").tag(WineLocale.automatic)
                            Text("简体中文").tag(WineLocale.simplifiedChinese)
                            Text("日语").tag(WineLocale.japanese)
                        }
                        .padding(.top, 8)
                    }
                }
                Button(role: .destructive) { library.remove(game) } label: {
                    Label("从游戏库移除", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help("只移除游戏库记录，不删除游戏文件")
                }
                .frame(maxWidth: 1100, alignment: .leading)
                .padding(32)
        }
        .task(id: game.steamAppID) { library.loadSteamMetadata(for: game) }
    }

    private func detailHeroBackground(_ url: URL?) -> some View {
        GeometryReader { proxy in
            ZStack {
                if let url {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } placeholder: { Color.clear }
                }
                LinearGradient(
                    colors: [GlassPalette.background.opacity(0.28), GlassPalette.background.opacity(0.68)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var statisticsPage: some View {
        let games = library.games
        let playedGames = games.filter { $0.playtime > 0 }
        let rankedGames = playedGames.sorted { $0.playtime > $1.playtime }
        let recentGames = games
            .filter { $0.lastPlayed != nil }
            .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        let recentCutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        let recentlyPlayedCount = recentGames.filter { ($0.lastPlayed ?? .distantPast) >= recentCutoff }.count
        let engineCounts = EngineType.allCases
            .map { engine in (engine: engine, count: games.filter { $0.engine == engine }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader("游玩统计", subtitle: "本地游戏库概览 · 数据随每次游戏结束更新。") {
                    Label("仅本机", systemImage: "lock.shield")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(GlassPalette.secondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(GlassPalette.surface, in: Capsule())
                        .overlay(Capsule().strokeBorder(GlassPalette.line))
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 172), spacing: 14)], spacing: 14) {
                    metric("累计游玩时长", value: Game.formatDuration(library.totalPlaytime), symbol: "clock")
                    metric("游戏总数", value: "\(games.count)", symbol: "square.stack.3d.up")
                    metric("已游玩作品", value: "\(playedGames.count)", symbol: "gamecontroller")
                    metric("近 30 天游玩", value: "\(recentlyPlayedCount)", symbol: "calendar")
                }

                HStack(alignment: .top, spacing: 18) {
                    detailPanel("游玩时长排行", symbol: "chart.bar.xaxis") {
                        if rankedGames.isEmpty {
                            statisticsEmptyState("开始游玩后，这里会显示累计时长排行。", symbol: "hourglass")
                        } else {
                            VStack(spacing: 15) {
                                ForEach(Array(rankedGames.prefix(8).enumerated()), id: \.element.id) { index, game in
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack(spacing: 10) {
                                            Text(String(format: "%02d", index + 1))
                                                .font(.caption.monospacedDigit().weight(.semibold))
                                                .foregroundStyle(index == 0 ? GlassPalette.blue : GlassPalette.secondary)
                                                .frame(width: 24, alignment: .leading)
                                            Text(game.name).font(.callout.weight(.medium)).lineLimit(1)
                                            Spacer(minLength: 8)
                                            Text(game.playtimeDescription)
                                                .font(.callout.monospacedDigit().weight(.semibold))
                                                .foregroundStyle(.primary)
                                        }
                                        GeometryReader { proxy in
                                            Capsule().fill(GlassPalette.elevated)
                                                .overlay(alignment: .leading) {
                                                    Capsule().fill(GlassPalette.blue.gradient)
                                                        .frame(width: max(3, proxy.size.width * game.playtime / max(rankedGames[0].playtime, 1)))
                                                }
                                        }
                                        .frame(height: 6)
                                        .padding(.leading, 34)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    detailPanel("游戏引擎分布", symbol: "square.stack.3d.up") {
                        if engineCounts.isEmpty {
                            statisticsEmptyState("导入游戏后，这里会显示引擎分布。", symbol: "square.grid.2x2")
                        } else {
                            VStack(spacing: 15) {
                                ForEach(engineCounts, id: \.engine) { item in
                                    VStack(spacing: 7) {
                                        HStack {
                                            Circle().fill(engineColor(item.engine)).frame(width: 8, height: 8)
                                            Text(item.engine.displayName).font(.callout).lineLimit(1)
                                            Spacer(minLength: 8)
                                            Text("\(item.count)")
                                                .font(.callout.monospacedDigit().weight(.semibold))
                                            Text(String(format: "%.0f%%", Double(item.count) / Double(max(games.count, 1)) * 100))
                                                .font(.caption.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                                .frame(width: 42, alignment: .trailing)
                                        }
                                        GeometryReader { proxy in
                                            Capsule().fill(GlassPalette.elevated)
                                                .overlay(alignment: .leading) {
                                                    Capsule().fill(engineColor(item.engine).gradient)
                                                        .frame(width: max(3, proxy.size.width * Double(item.count) / Double(max(games.count, 1))))
                                                }
                                        }
                                        .frame(height: 6)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                detailPanel("最近游玩", symbol: "clock.arrow.circlepath") {
                    if recentGames.isEmpty {
                        statisticsEmptyState("游玩记录会在游戏正常退出后更新。", symbol: "clock")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(recentGames.prefix(5).enumerated()), id: \.element.id) { index, game in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(engineColor(game.engine).opacity(0.18))
                                        .frame(width: 34, height: 34)
                                        .overlay {
                                            Image(systemName: "gamecontroller.fill")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(engineColor(game.engine))
                                        }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(game.name).font(.callout.weight(.medium)).lineLimit(1)
                                        Text(game.engine.displayName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(game.playtimeDescription).font(.callout.monospacedDigit().weight(.medium))
                                        Text(game.lastPlayed?.formatted(date: .abbreviated, time: .shortened) ?? "—")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 11)
                                if index < min(recentGames.count, 5) - 1 {
                                    Divider().overlay(GlassPalette.line)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .padding(30)
        }
    }

    private func statisticsEmptyState(_ message: String, symbol: String) -> some View {
        Label(message, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
    }

    private func engineColor(_ engine: EngineType) -> Color {
        switch engine {
        case .unity: .cyan
        case .siglus: .indigo
        case .kirikiri: .orange
        case .renpy: .pink
        case .tyranoScript: .teal
        case .realLive: .purple
        case .nscripter: .yellow
        case .yuris: .mint
        case .artemis: .red
        case .unknown: GlassPalette.secondary
        }
    }

    private var settingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                pageHeader("设置", subtitle: "管理本地游戏库和运行环境。") { EmptyView() }
                detailPanel("Steam 账户", symbol: "person.crop.circle") {
                    if let game = pendingSteamGame {
                        Label("登录后继续同步 \(game.name) 的云存档。", systemImage: "icloud.and.arrow.down")
                            .font(.callout)
                            .foregroundStyle(GlassPalette.blue)
                    }
                    HStack {
                        Circle()
                            .fill(steamSession.authentication == .signedIn ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(steamSession.authentication == .signedIn ? "已登录 Steam" : "尚未登录 Steam")
                        Spacer()
                        Button("刷新状态") { steamSession.verifyAuthentication { _ in } }
                            .disabled(steamSession.authentication == .checking)
                    }
                    Text("在下方 Steam 网页登录。登录状态会保存在这台 Mac 的应用数据中。")
                        .font(.callout).foregroundStyle(.secondary)
                    if let steamSettingsMessage {
                        Text(steamSettingsMessage).font(.caption).foregroundStyle(.orange)
                    }
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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(GlassPalette.line))
                    .onDisappear { steamSession.release(ownerID: settingsSteamOwnerID) }
                }
                detailPanel("游戏库位置", symbol: "folder") {
                    ForEach(library.config.libraryPaths, id: \.self) { path in
                        HStack {
                            Image(systemName: "folder.fill").foregroundStyle(GlassPalette.blue)
                            Text(path.path).font(.callout).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Button { library.removeLibraryFolder(path) } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.plain)
                                .accessibilityLabel("移除游戏库路径 \(path.path)")
                        }
                        .padding(.vertical, 8)
                    }
                    Button { library.chooseLibraryFolder() } label: { Label("添加文件夹…", systemImage: "plus") }
                        .buttonStyle(.bordered)
                        .padding(.top, 5)
                }
                detailPanel("运行环境", symbol: "shippingbox") {
                    HStack {
                        Circle().fill(library.engineReady ? .green : .orange).frame(width: 8, height: 8)
                        Text(library.engineReady ? "Mythic Engine 已就绪" : "未检测到 Mythic Engine")
                        Spacer()
                    }
                    Text("游戏启动依赖本机安装的 Mythic Engine。")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 850, alignment: .leading)
            .padding(32)
        }
    }

    private var statusBar: some View {
        Group {
            if library.launchingID == nil, let status = library.status {
                HStack(spacing: 10) {
                    if library.isScanning { ProgressView().controlSize(.small) }
                    Text(status).font(.callout).lineLimit(1)
                    Spacer()
                    if !library.isScanning && library.launchingID == nil {
                        Button { library.status = nil } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).accessibilityLabel("关闭状态提示")
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .glassPanel()
            }
        }
    }

    private func dockButton(_ item: AppPage) -> some View {
        Button {
            page = item
            selectedGameID = nil
            if item != .settings { pendingSteamGame = nil }
        } label: {
            Label(item.title, systemImage: item.symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 32)
                .padding(.horizontal, 12)
                .background(page == item ? GlassPalette.blue.opacity(0.26) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
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

    private func pageHeader<Accessory: View>(_ title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 30, weight: .bold, design: .rounded))
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            accessory()
        }
    }

    private func detailPanel<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: symbol).font(.headline)
            Divider().overlay(GlassPalette.line)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(GlassPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(GlassPalette.line))
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing).lineLimit(2)
        }
        .font(.callout)
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol).font(.callout).foregroundStyle(.secondary)
            Text(value).font(.system(size: 27, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GlassPalette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(GlassPalette.line))
    }

    private func compatibilityLabel(_ game: Game) -> String {
        switch game.engine.compatibility {
        case .excellent, .good, .native: "兼容性良好"
        case .experimental: "实验性兼容"
        case .unsupported: "兼容性未知"
        }
    }
}

private struct GameCard: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GameArtwork(game: game)
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipped()
            VStack(alignment: .leading, spacing: 7) {
                Text(game.name).font(.callout.weight(.semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    Text(game.engine.displayName).lineLimit(1)
                    Spacer(minLength: 4)
                    if game.playtime > 0 { Text(game.playtimeDescription).lineLimit(1) }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(13)
        }
        .background(GlassPalette.surface, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(GlassPalette.line))
    }
}

private struct TitlebarBrandInstaller: NSViewRepresentable {
    @ObservedObject var library: LibraryViewModel

    func makeCoordinator() -> Coordinator { Coordinator(library: library) }

    func makeNSView(context: Context) -> WindowAwareView {
        let view = WindowAwareView()
        let coordinator = context.coordinator
        view.onWindowChange = { [weak coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowAwareView, context: Context) {
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(_ nsView: WindowAwareView, coordinator: Coordinator) {
        nsView.onWindowChange = nil
        coordinator.detach()
    }

    final class Coordinator {
        private let library: LibraryViewModel
        private weak var window: NSWindow?
        private var accessories: [NSTitlebarAccessoryViewController] = []

        init(library: LibraryViewModel) {
            self.library = library
        }

        func attach(to window: NSWindow?) {
            guard let window, self.window !== window else { return }
            detach()

            let actions = Gal4MacActionsAccessory(library: library)
            actions.layoutAttribute = .right
            window.addTitlebarAccessoryViewController(actions)
            let brand = Gal4MacTitlebarAccessory()
            brand.layoutAttribute = .left
            window.addTitlebarAccessoryViewController(brand)
            self.window = window
            accessories = [actions, brand]
        }

        func detach() {
            if let window {
                for accessory in accessories {
                    if let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessory }) {
                        window.removeTitlebarAccessoryViewController(at: index)
                    }
                }
            }
            window = nil
            accessories = []
        }
    }

    final class WindowAwareView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowChange?(window)
        }
    }

    final class Gal4MacTitlebarAccessory: NSTitlebarAccessoryViewController {
        override func loadView() {
            let title = NSTextField(labelWithString: "Gal4Mac")
            title.font = .systemFont(ofSize: 13, weight: .semibold)
            title.textColor = .labelColor
            title.sizeToFit()

            let width = title.frame.width + 16
            let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 40))
            container.translatesAutoresizingMaskIntoConstraints = false
            title.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(title)
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: width),
                container.heightAnchor.constraint(equalToConstant: 40),
                title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
                title.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            preferredContentSize = NSSize(width: width, height: 40)
            view = container
        }
    }

    final class Gal4MacActionsAccessory: NSTitlebarAccessoryViewController {
        private let library: LibraryViewModel

        init(library: LibraryViewModel) {
            self.library = library
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func loadView() {
            let host = NSHostingView(rootView: Gal4MacTitlebarActions(library: library))
            host.frame = NSRect(x: 0, y: 0, width: 88, height: 40)
            preferredContentSize = NSSize(width: 88, height: 40)
            view = host
        }
    }
}

private struct Gal4MacTitlebarActions: View {
    @ObservedObject var library: LibraryViewModel

    var body: some View {
        HStack(spacing: 4) {
            Button { library.scan() } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .help("重新扫描游戏库")
            .disabled(library.isScanning)

            Button { library.showingImportWizard = true } label: {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .help("导入游戏")
        }
        .padding(.horizontal, 8)
        .frame(width: 88, height: 40)
    }
}

private struct GameArtwork: View {
    let game: Game
    let showsPlaceholder: Bool

    init(game: Game, showsPlaceholder: Bool = true) {
        self.game = game
        self.showsPlaceholder = showsPlaceholder
    }

    var hasArtwork: Bool { artwork != nil || steamPosterURL != nil }

    private var artwork: NSImage? {
        let names = ["cover.jpg", "cover.png", "Cover.jpg", "Cover.png", "poster.jpg", "poster.png", "icon.png"]
        for name in names {
            if let image = NSImage(contentsOf: game.path.appendingPathComponent(name)) { return image }
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
    }

    @ViewBuilder
    private func placeholder(size: CGSize) -> some View {
        if showsPlaceholder {
            ZStack {
                LinearGradient(colors: [accent.opacity(0.55), GlassPalette.background], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: min(size.width * 0.24, 44), weight: .light))
                    .foregroundStyle(.white.opacity(0.72))
            }
        } else {
            Color.clear
        }
    }

    private var accent: Color {
        switch game.engine {
        case .unity: .cyan
        case .siglus: .indigo
        case .kirikiri: .orange
        case .renpy: .pink
        default: GlassPalette.blue
        }
    }
}

private extension View {
    @ViewBuilder func removeDefaultToolbarTitle() -> some View {
        if #available(macOS 15.0, *) {
            self.toolbar(removing: .title)
        } else {
            self
        }
    }

    @ViewBuilder func glassPanel() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
