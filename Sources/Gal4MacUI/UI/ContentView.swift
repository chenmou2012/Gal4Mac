import SwiftUI
import Gal4MacCore

/// 主视图
struct ContentView: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @State private var showingSettings = false

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 16)
    ]

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            mainContent
        }
        .navigationTitle("Gal4Mac")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    library.scanAll()
                } label: {
                    Label("扫描", systemImage: "arrow.clockwise")
                }
                .disabled(library.isScanning)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    library.showingAddLibrary = true
                } label: {
                    Label("添加库", systemImage: "folder.badge.plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    library.showingImportGame = true
                } label: {
                    Label("导入游戏", systemImage: "square.and.arrow.down")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Label("设置", systemImage: "gear")
                }
            }
        }
        .sheet(isPresented: $library.showingAddLibrary) {
            AddLibrarySheet()
                .environmentObject(library)
        }
        .sheet(isPresented: $library.showingImportGame) {
            ImportGameSheet()
                .environmentObject(library)
        }
        .sheet(item: $library.showingSavesFor) { game in
            SaveManagerSheet(game: game)
                .environmentObject(library)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
                .environmentObject(library)
        }
        .alert("错误", isPresented: Binding(
            get: { library.lastError != nil },
            set: { _ in library.lastError = nil }
        )) {
            Button("好") { library.lastError = nil }
        } message: {
            Text(library.lastError ?? "")
        }
    }

    // MARK: - Sidebar
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(library.config.libraryPaths, id: \.self) { path in
                HStack(spacing: 8) {
                    Image(systemName: library.isAccessible(path) ? "external.drive.connected.to.line.below" : "external.drive.badge.exclamationmark")
                        .foregroundStyle(library.isAccessible(path) ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(path.lastPathComponent)
                            .font(.system(.body, design: .default))
                            .lineLimit(1)
                        Text(path.deletingLastPathComponent().path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button {
                    library.showingAddLibrary = true
                } label: {
                    Label("添加库", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                Spacer()
                if let last = library.config.lastScanAt {
                    Text(last.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 220)
    }

    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        if library.games.isEmpty {
            emptyState
        } else {
            gameGrid
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("游戏库为空")
                .font(.title2)
            Text("添加库路径后扫描，或手动添加游戏")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button {
                    library.showingAddLibrary = true
                } label: {
                    Label("添加库", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    library.showingImportGame = true
                } label: {
                    Label("导入游戏", systemImage: "square.and.arrow.down")
                }

                Button {
                    library.scanAll()
                } label: {
                    Label("扫描", systemImage: "arrow.clockwise")
                }
                .disabled(library.isScanning)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // 总统计栏
    private var statsBar: some View {
        HStack {
            Label("\(library.games.count) 个游戏", systemImage: "gamecontroller.fill")
            Spacer()
            if library.totalPlaytime > 0 {
                Label("总时长 \(library.totalPlaytimeDescription)", systemImage: "clock.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var gameGrid: some View {
        VStack(spacing: 0) {
            statsBar
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(library.games) { game in
                        GameCardView(game: game)
                            .environmentObject(library)
                    }
                }
                .padding()
            }
        }
    }
}
