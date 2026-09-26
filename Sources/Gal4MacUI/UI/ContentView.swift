import SwiftUI
import Gal4MacCore

struct ContentView: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @State private var showingSettings = false
    @State private var showingDownload = false
    @State private var selectedGameID: UUID?
    @State private var searchText = ""

    private var selectedGame: Game? {
        library.games.first { $0.id == selectedGameID } ?? library.games.first
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
            NavigationSplitView {
                gameSidebar
                    .navigationSplitViewColumnWidth(min: 230, ideal: 276, max: 340)
            } detail: {
                ZStack {
                    LibraryBackdrop()
                    if let game = selectedGame {
                        gameDetail(game)
                    } else {
                        emptyState
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationSplitViewStyle(.balanced)

            if let status = library.launchStatus {
                LaunchProgressBanner(
                    status: status,
                    canStop: library.canStopGame,
                    isStopping: library.isStoppingGame,
                    stopAction: { library.stopGame() }
                )
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: library.launchStatus)
        .navigationTitle("Gal4Mac")
        .preferredColorScheme(.dark)
        .toolbar {
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
            if selectedGameID.map(ids.contains) != true, let first = ids.first { selectedGameID = first }
        }
        .onAppear {
            if selectedGameID == nil { selectedGameID = library.games.first?.id }
        }
    }

    private var gameSidebar: some View {
        ZStack {
            LibraryBackdrop()
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GAL4MAC")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .tracking(1.8)
                            .foregroundStyle(GalTheme.accent)
                        Text("游戏收藏")
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                        Text("整理你的故事与冒险")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(library.games.count)")
                        .font(.system(.title3, design: .rounded, weight: .bold).monospacedDigit())
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(GalTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(GalTheme.border, lineWidth: 1))
                }

                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索游戏或引擎", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(GalTheme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(GalTheme.border, lineWidth: 1))

                HStack {
                    Text("我的游戏")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    if library.isScanning {
                        ProgressView().controlSize(.small)
                    }
                }
                .padding(.horizontal, 3)

                if filteredGames.isEmpty {
                    ContentUnavailableView(
                        library.games.isEmpty ? "还没有游戏" : "没有匹配的游戏",
                        systemImage: library.games.isEmpty ? "gamecontroller" : "magnifyingglass",
                        description: Text(library.games.isEmpty ? "添加游戏库或导入游戏开始使用。" : "试试其他名称或引擎。")
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredGames) { game in
                                Button {
                                    selectedGameID = game.id
                                } label: {
                                    GameLibraryRow(game: game, isSelected: selectedGameID == game.id)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(game.name), \(game.engine.displayName)")
                                .accessibilityAddTraits(selectedGameID == game.id ? .isSelected : [])
                                .contextMenu { gameActions(for: game) }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                }

                HStack(spacing: 9) {
                    Circle()
                        .fill(library.isScanning ? Color.orange : Color.green)
                        .frame(width: 7, height: 7)
                    Text(library.isScanning ? "正在扫描游戏库…" : "累计游玩 \(library.totalPlaytimeDescription)")
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(GalTheme.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(GalTheme.border, lineWidth: 1))
            }
            .padding(16)
        }
        .onAppear {
            for game in library.games { library.loadSteamMetadata(for: game) }
        }
    }

    @ViewBuilder
    private func gameDetail(_ game: Game) -> some View {
        let metadata = library.steamMetadata[game.id]
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("你的游戏库")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(GalTheme.accent)
                        Text("继续你的故事")
                            .font(.system(.title2, design: .rounded, weight: .bold))
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
                    canLaunch: library.launchingGameId == nil && library.isAccessible(game.path),
                    isLaunching: library.launchingGameId == game.id,
                    launchAction: { library.launch(game) },
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
                    StatTile(title: "游戏大小", value: game.sizeDescription, symbol: "internaldrive")
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
                        Divider().overlay(GalTheme.border)
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
                .panelSurface(cornerRadius: 20)
            }
            .frame(maxWidth: 1000, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.top, 26)
            .padding(.bottom, 42)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .onAppear { library.loadSteamMetadata(for: game) }
        .onChange(of: game.id) { _, _ in library.loadSteamMetadata(for: game) }
    }

    @ViewBuilder
    private func gameActions(for game: Game) -> some View {
        Button { library.launch(game) } label: { Label("开始游戏", systemImage: "play.fill") }
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
                .foregroundStyle(GalTheme.accent)
                .frame(width: 76, height: 76)
                .background(GalTheme.surfaceRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        .panelSurface(cornerRadius: 24)
        .padding(28)
    }
}

private struct GameShowcase: View {
    let game: Game
    let displayName: String
    let releaseDate: String?
    let canLaunch: Bool
    let isLaunching: Bool
    let launchAction: () -> Void
    let savesAction: () -> Void
    let folderAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [GalTheme.heroTop, GalTheme.heroBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(GalTheme.accent.opacity(0.13))
                    .frame(width: 300, height: 300)
                    .blur(radius: 1)
                    .offset(x: 270, y: -130)
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 250, height: 250)
                    .overlay {
                        EngineLogoView(engine: game.engine, size: 76, color: .white.opacity(0.48))
                    }
                    .offset(x: 300, y: 35)

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
                            .foregroundStyle(GalTheme.gold)
                        Text("兼容性 \(game.rating) / 5")
                            .font(.caption.weight(.semibold))
                        Text("·")
                            .foregroundStyle(.white.opacity(0.55))
                        Text(game.path.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.76))
                    .help("游戏目录：\(game.path.path)")
                }
                .padding(24)
            }
            .frame(minHeight: 226)
            .clipped()

            HStack(spacing: 10) {
                Button(action: launchAction) {
                    HStack(spacing: 9) {
                        if isLaunching {
                            ProgressView().controlSize(.small).tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text(isLaunching ? "正在启动…" : "开始游戏")
                            .fontWeight(.semibold)
                    }
                    .frame(minWidth: 142, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(GalTheme.accent)
                .disabled(!canLaunch)
                .help(canLaunch ? "启动 \(game.name)" : (isLaunching ? "游戏正在启动" : "游戏路径不可访问"))

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
            .background(GalTheme.surfaceRaised)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(GalTheme.border, lineWidth: 1))
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

private enum GalTheme {
    static let background = Color(red: 0.055, green: 0.060, blue: 0.095)
    static let surface = Color(red: 0.105, green: 0.105, blue: 0.155)
    static let surfaceRaised = Color(red: 0.145, green: 0.140, blue: 0.205)
    static let border = Color.white.opacity(0.09)
    static let accent = Color(red: 0.56, green: 0.40, blue: 0.96)
    static let heroTop = Color(red: 0.19, green: 0.16, blue: 0.36)
    static let heroBottom = Color(red: 0.11, green: 0.13, blue: 0.25)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.34)
}

private struct GameLibraryRow: View {
    let game: Game
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(game.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : .primary)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(GalTheme.accent)
                }
            }
            HStack(spacing: 6) {
                Text(game.engine.displayName)
                if game.playtime > 0 {
                    Text("·")
                    Text(game.playtimeDescription)
                }
                Spacer(minLength: 0)
                Label("\(game.rating)", systemImage: "star.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(GalTheme.gold.opacity(0.9))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isSelected ? GalTheme.accent.opacity(0.17) : GalTheme.surface.opacity(0.62))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(isSelected ? GalTheme.accent.opacity(0.42) : GalTheme.border, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
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
                .foregroundStyle(GalTheme.accent)
                .frame(width: 32, height: 32)
                .background(GalTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
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
        .panelSurface(cornerRadius: 16)
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
    let canStop: Bool
    let isStopping: Bool
    let stopAction: () -> Void

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

            if canStop {
                Button(action: stopAction) {
                    Label(isStopping ? "正在停止…" : "停止游戏", systemImage: isStopping ? "hourglass" : "stop.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.78), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isStopping)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 13)
        .panelSurface(cornerRadius: 17)
        .accessibilityElement(children: .combine)
    }
}

private struct LibraryBackdrop: View {
    var body: some View {
        ZStack {
            GalTheme.background
            LinearGradient(
                colors: [GalTheme.accent.opacity(0.08), .clear, .clear],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }
}

private extension View {
    func panelSurface(cornerRadius: CGFloat) -> some View {
        background(GalTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(GalTheme.border, lineWidth: 1)
            }
    }
}
