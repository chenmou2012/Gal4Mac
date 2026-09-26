import SwiftUI
import Gal4MacCore

struct ContentView: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSettings = false
    @State private var showingDownload = false
    @State private var selectedGameID: UUID?
    @State private var searchText = ""
    @State private var page: Page = .library
    @State private var sidebarCollapsed = false
    @Namespace private var gameCardLayout

    private enum Page: Equatable { case home, library }

    private var selectedGame: Game? {
        library.games.first { $0.id == selectedGameID }
    }

    private var featuredGame: Game? {
        library.games.max { ($0.lastPlayed ?? .distantPast) < ($1.lastPlayed ?? .distantPast) }
    }

    private var filteredGames: [Game] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return library.games }
        return library.games.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.engine.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                gameSidebar
                    .frame(width: sidebarCollapsed ? 72 : 220)

                Rectangle()
                    .fill(MythicTheme.border)
                    .frame(width: 1)

                ZStack {
                    LibraryBackdrop()
                    if let game = selectedGame {
                        gameDetail(game)
                    } else if page == .home {
                        homePage
                    } else {
                        libraryPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let status = library.launchStatus, !library.canStopGame {
                LaunchProgressBanner(status: status)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: library.launchStatus)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: library.canStopGame)
        .navigationTitle("Gal4Mac")
        .preferredColorScheme(.dark)
        .tint(MythicTheme.accent)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                        sidebarCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(sidebarCollapsed ? "展开侧栏" : "收起侧栏")
                .accessibilityLabel(sidebarCollapsed ? "展开侧栏" : "收起侧栏")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button { library.scanAll() } label: {
                    Image(systemName: library.isScanning ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                }
                .help("扫描游戏库")
                .accessibilityLabel(library.isScanning ? "正在扫描游戏库" : "扫描游戏库")
                .disabled(library.isScanning)

                Menu {
                    Button { library.showingAddLibrary = true } label: { Label("添加游戏库", systemImage: "folder.badge.plus") }
                    Button { library.showingImportGame = true } label: { Label("导入游戏", systemImage: "plus") }
                    Button { showingDownload = true } label: { Label("下载游戏", systemImage: "arrow.down.circle") }
                } label: {
                    Image(systemName: "plus")
                }
                .help("添加游戏")
                .accessibilityLabel("添加游戏、游戏库或下载")

                Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                    .help("设置")
                    .accessibilityLabel("设置")
            }
        }
        .sheet(isPresented: $library.showingAddLibrary) { AddLibrarySheet().environmentObject(library) }
        .sheet(isPresented: $library.showingImportGame) { ImportGameSheet().environmentObject(library) }
        .sheet(isPresented: $showingDownload) { DownloadSheet().environmentObject(library) }
        .sheet(item: $library.showingSavesFor) { game in SaveManagerSheet(game: game).environmentObject(library) }
        .sheet(isPresented: $showingSettings) { SettingsSheet().environmentObject(library) }
        .alert("错误", isPresented: Binding(
            get: { library.lastError != nil },
            set: { _ in library.lastError = nil }
        )) {
            Button("好") { library.lastError = nil }
        } message: {
            Text(library.lastError ?? "")
        }
        .onChange(of: library.games.map(\.id)) { _, ids in
            if selectedGameID.map(ids.contains) != true { selectedGameID = nil }
            for game in library.games { library.loadSteamMetadata(for: game) }
        }
        .onAppear {
            for game in library.games { library.loadSteamMetadata(for: game) }
        }
    }

    private var gameSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(MythicTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                if !sidebarCollapsed {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Gal4Mac").font(.system(size: 17, weight: .bold))
                        Text("游戏启动器").font(.caption2).foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, sidebarCollapsed ? 18 : 17)
            .padding(.top, 24)
            .padding(.bottom, 34)

            sidebarHeading("浏览")
            SidebarLink(title: "首页", symbol: "house", isSelected: page == .home && selectedGameID == nil, compact: sidebarCollapsed) {
                page = .home
                selectedGameID = nil
            }
            SidebarLink(title: "游戏库", symbol: "square.grid.2x2", isSelected: page == .library, compact: sidebarCollapsed) {
                page = .library
                selectedGameID = nil
            }

            sidebarHeading("管理").padding(.top, 29)
            SidebarLink(title: "下载游戏", symbol: "arrow.down.circle", isSelected: false, compact: sidebarCollapsed) { showingDownload = true }
            SidebarLink(title: "导入游戏", symbol: "plus.square.on.square", isSelected: false, compact: sidebarCollapsed) { library.showingImportGame = true }
            SidebarLink(title: "设置", symbol: "gearshape", isSelected: false, compact: sidebarCollapsed) { showingSettings = true }

            Spacer(minLength: 20)

            if !sidebarCollapsed {
                VStack(alignment: .leading, spacing: 7) {
                    Text("我的收藏")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(library.games.count) 款游戏")
                        .font(.callout.weight(.semibold))
                    Text(library.isScanning ? "正在扫描游戏库…" : "累计游玩 \(library.totalPlaytimeDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(MythicTheme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 11))
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MythicTheme.sidebar)
    }

    private func sidebarHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: sidebarCollapsed ? .center : .leading)
            .padding(.horizontal, sidebarCollapsed ? 0 : 20)
            .padding(.bottom, 7)
    }

    private var libraryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    Text("游戏库")
                        .font(.system(size: 28, weight: .bold))
                    Text("\(library.games.count) 款游戏")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { library.showingImportGame = true } label: {
                        Label("添加游戏", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索游戏或引擎", text: $searchText)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("搜索游戏或引擎")
                }
                .font(.callout)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .mythicPanel(cornerRadius: 10)

                if filteredGames.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 18)], alignment: .leading, spacing: 18) {
                        ForEach(filteredGames) { game in
                            GameArtworkCard(
                                game: game,
                                artworkURL: library.steamMetadata[game.id]?.artworkURL,
                                canLaunch: library.launchingGameId == nil && library.isAccessible(game.path),
                                isLaunching: library.launchingGameId == game.id,
                                canStop: library.launchingGameId == game.id && library.canStopGame,
                                isStopping: library.launchingGameId == game.id && library.isStoppingGame,
                                openAction: { selectedGameID = game.id },
                                launchAction: { library.launch(game) },
                                stopAction: { library.stopGame() }
                            )
                            .matchedGeometryEffect(id: game.id, in: gameCardLayout, properties: .position)
                            .clipped()
                            .contextMenu { gameActions(for: game) }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    private var homePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("首页")
                        .font(.system(size: 28, weight: .bold))
                    Text("继续上次的冒险")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if let game = featuredGame {
                    GameShowcase(
                        game: game,
                        displayName: library.steamMetadata[game.id]?.name ?? game.name,
                        releaseDate: library.steamMetadata[game.id]?.releaseDate,
                        artworkURL: library.steamMetadata[game.id]?.artworkURL,
                        canLaunch: library.launchingGameId == nil && library.isAccessible(game.path),
                        isLaunching: library.launchingGameId == game.id,
                        canStop: library.launchingGameId == game.id && library.canStopGame,
                        isStopping: library.launchingGameId == game.id && library.isStoppingGame,
                        launchAction: {
                            selectedGameID = game.id
                            page = .library
                            library.launch(game)
                        },
                        stopAction: { library.stopGame() },
                        savesAction: { library.showingSavesFor = game },
                        folderAction: { NSWorkspace.shared.open(game.path) }
                    )
                } else {
                    emptyState
                }

                if !library.games.isEmpty {
                    HStack {
                        Text("我的游戏")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Button("查看全部") {
                            page = .library
                            selectedGameID = nil
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MythicTheme.accentLight)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220, maximum: 310), spacing: 18)], alignment: .leading, spacing: 18) {
                        ForEach(Array(library.games.prefix(3))) { game in
                            GameArtworkCard(
                                game: game,
                                artworkURL: library.steamMetadata[game.id]?.artworkURL,
                                canLaunch: library.launchingGameId == nil && library.isAccessible(game.path),
                                isLaunching: library.launchingGameId == game.id,
                                canStop: library.launchingGameId == game.id && library.canStopGame,
                                isStopping: library.launchingGameId == game.id && library.isStoppingGame,
                                openAction: { selectedGameID = game.id; page = .library },
                                launchAction: {
                                    selectedGameID = game.id
                                    page = .library
                                    library.launch(game)
                                },
                                stopAction: { library.stopGame() }
                            )
                            .contextMenu { gameActions(for: game) }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func gameDetail(_ game: Game) -> some View {
        let metadata = library.steamMetadata[game.id]
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            selectedGameID = nil
                            page = .library
                        } label: {
                            Label("返回游戏库", systemImage: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MythicTheme.accentLight)
                        Text("游戏详情")
                            .font(.system(size: 28, weight: .bold))
                    }
                    Spacer()
                    if library.loadingSteamMetadata.contains(game.id) {
                        ProgressView().controlSize(.small).help("正在载入游戏介绍")
                    }
                }

                GameShowcase(
                    game: game,
                    displayName: metadata?.name ?? game.name,
                    releaseDate: metadata?.releaseDate,
                    artworkURL: metadata?.artworkURL,
                    canLaunch: library.launchingGameId == nil && library.isAccessible(game.path),
                    isLaunching: library.launchingGameId == game.id,
                    canStop: library.launchingGameId == game.id && library.canStopGame,
                    isStopping: library.launchingGameId == game.id && library.isStoppingGame,
                    launchAction: { library.launch(game) },
                    stopAction: { library.stopGame() },
                    savesAction: { library.showingSavesFor = game },
                    folderAction: { NSWorkspace.shared.open(game.path) }
                )

                HStack(alignment: .firstTextBaseline) {
                    Text("游玩记录")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Spacer()
                    Text("本机统计")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], alignment: .leading, spacing: 12) {
                    StatTile(title: "累计游戏时间", value: game.playtimeDescription, symbol: "clock")
                    StatTile(title: "上次游玩", value: game.lastPlayed?.formatted(date: .abbreviated, time: .shortened) ?? "尚未游玩", symbol: "calendar")
                    StatTile(title: "游戏大小", value: library.gameSizeDescription(for: game), symbol: "internaldrive")
                    StatTile(title: "安装状态", value: library.isAccessible(game.path) ? "可用" : "路径不可访问", symbol: library.isAccessible(game.path) ? "checkmark.circle" : "exclamationmark.triangle")
                }

                VStack(alignment: .leading, spacing: 15) {
                    Label("关于这款游戏", systemImage: "text.alignleft")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

                    if let description = metadata?.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if library.loadingSteamMetadata.contains(game.id) {
                        Text("正在查找游戏介绍…")
                            .font(.callout).italic()
                            .foregroundStyle(.secondary)
                    } else {
                        Text("还没有找到商店介绍。你仍可以查看本地游玩记录并启动游戏。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    if let metadata, !metadata.developers.isEmpty || !metadata.publishers.isEmpty {
                        Divider().overlay(MythicTheme.border)
                        HStack(alignment: .top, spacing: 32) {
                            if !metadata.developers.isEmpty {
                                DetailCredit(title: "开发商", value: metadata.developers.joined(separator: "、"))
                            }
                            if !metadata.publishers.isEmpty {
                                DetailCredit(title: "发行商", value: metadata.publishers.joined(separator: "、"))
                            }
                        }
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mythicPanel(cornerRadius: 16)
            }
            .frame(maxWidth: 1100, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 42)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .onAppear { library.loadSteamMetadata(for: game) }
        .onChange(of: game.id) { _, _ in library.loadSteamMetadata(for: game) }
    }

    @ViewBuilder
    private func gameActions(for game: Game) -> some View {
        if library.launchingGameId == game.id && library.canStopGame {
            Button { library.stopGame() } label: { Label("停止游戏", systemImage: "stop.fill") }
                .disabled(library.isStoppingGame)
        } else {
            Button {
                selectedGameID = game.id
                page = .library
                library.launch(game)
            } label: { Label("开始游戏", systemImage: "play.fill") }
                .disabled(library.launchingGameId != nil || !library.isAccessible(game.path))
        }
        Button { library.showingSavesFor = game } label: { Label("存档管理", systemImage: "tray.full") }
        Button { NSWorkspace.shared.open(game.path) } label: { Label("打开游戏目录", systemImage: "folder") }
        Button { NSWorkspace.shared.activateFileViewerSelecting([game.path]) } label: { Label("在 Finder 中显示", systemImage: "folder") }
        Divider()
        Button(role: .destructive) { library.removeGame(game) } label: { Label("从库中移除", systemImage: "trash") }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(MythicTheme.accentLight)
                .frame(width: 76, height: 76)
                .background(MythicTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            VStack(spacing: 7) {
                Text("准备好开始了吗？")
                    .font(.title2.weight(.bold))
                Text("添加游戏库或导入游戏，你的收藏会显示在这里。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 10) {
                Button("添加游戏库") { library.showingAddLibrary = true }
                    .buttonStyle(.borderedProminent)
                Button("导入游戏") { library.showingImportGame = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(36)
        .mythicPanel(cornerRadius: 24)
        .padding(28)
    }
}

private struct GameShowcase: View {
    let game: Game
    let displayName: String
    let releaseDate: String?
    let artworkURL: URL?
    let canLaunch: Bool
    let isLaunching: Bool
    let canStop: Bool
    let isStopping: Bool
    let launchAction: () -> Void
    let stopAction: () -> Void
    let savesAction: () -> Void
    let folderAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [MythicTheme.heroTop, MythicTheme.heroBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let artworkURL {
                    CachedArtworkImage(url: artworkURL) { EmptyView() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.08), .black.opacity(0.35), .black.opacity(0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .overlay {
                        LinearGradient(
                            colors: [.black.opacity(0.42), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                } else {
                    Circle()
                        .fill(MythicTheme.accent.opacity(0.2))
                        .frame(width: 340, height: 340)
                        .blur(radius: 1)
                        .offset(x: 430, y: -150)
                    EngineLogoView(engine: game.engine, size: 112, color: .white.opacity(0.22))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, 58)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        ShowcaseTag(title: game.engine.displayName, symbol: "cpu")
                        if let releaseDate, !releaseDate.isEmpty {
                            ShowcaseTag(title: releaseDate, symbol: "calendar")
                        }
                    }

                    Spacer(minLength: 12)

                    Text(displayName)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                        .lineLimit(3)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 540, alignment: .leading)
                        .shadow(color: .black.opacity(0.22), radius: 12, y: 3)

                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(MythicTheme.gold)
                        Text("兼容性 \(game.rating) / 5")
                            .font(.caption.weight(.semibold))
                        Text("·")
                            .foregroundStyle(.white.opacity(0.55))
                        Text(game.path.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.84))
                    .help("游戏目录：\(game.path.path)")
                }
                .padding(24)
            }
            .frame(height: 278)
            .clipped()

            HStack(spacing: 10) {
                Button(action: canStop ? stopAction : launchAction) {
                    HStack(spacing: 9) {
                        if isLaunching && !canStop {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: canStop ? "stop.fill" : "play.fill")
                        }
                        Text(isStopping ? "正在停止…" : canStop ? "停止游戏" : isLaunching ? "正在启动…" : "开始游戏")
                            .fontWeight(.semibold)
                    }
                    .frame(minWidth: 142, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(canStop ? .red : MythicTheme.accent)
                .disabled(canStop ? isStopping : !canLaunch)
                .help(canStop ? "停止 \(game.name)" : (canLaunch ? "启动 \(game.name)" : (isLaunching ? "游戏正在启动" : "游戏路径不可访问")))

                Button(action: savesAction) {
                    Label("存档", systemImage: "tray.full")
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)

                Button(action: folderAction) {
                    Label("打开目录", systemImage: "folder")
                        .frame(minHeight: 42)
                }
                .buttonStyle(.bordered)
                .help("在 Finder 中打开游戏目录")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(MythicTheme.surfaceRaised)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(MythicTheme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .accessibilityElement(children: .contain)
    }
}

private struct ShowcaseTag: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.black.opacity(0.22), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MythicTheme.accent)
                .frame(width: 32, height: 32)
                .background(MythicTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(14)
        .mythicPanel(cornerRadius: 13)
    }
}

private struct DetailCredit: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct LaunchProgressBanner: View {
    let status: GameLaunchStatus

    var body: some View {
        HStack(spacing: 13) {
            if status.isInProgress {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: status.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(status.message == "启动失败" ? Color.orange : Color.green)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(status.message)
                    .font(.callout.weight(.semibold))
                Text([status.gameName, status.detail].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            if status.isInProgress {
                Text("正在处理")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

        }
        .padding(.horizontal, 17)
        .padding(.vertical, 13)
        .mythicPanel(cornerRadius: 17)
        .accessibilityElement(children: .combine)
    }
}

private struct LibraryBackdrop: View {
    var body: some View {
        ZStack {
            MythicTheme.background
            LinearGradient(
                colors: [MythicTheme.accent.opacity(0.04), .clear, .clear],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }
}
