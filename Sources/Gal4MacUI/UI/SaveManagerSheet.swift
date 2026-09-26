import SwiftUI
import Gal4MacCore
import AppKit

/// 存档管理弹窗
struct SaveManagerSheet: View {
    let game: Game
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var steamSession = SteamWebSession.shared

    @State private var saveLocations: [SaveManager.SaveLocation] = []
    @State private var isLoading = false
    @State private var isCheckingSteam = false
    @State private var message: String?
    @State private var showingSteamCloud = false
    @State private var showingSteamSettings = false
    @State private var selectedCloudAppID: Int?
    @State private var pendingImport: SaveArchiveManager.ImportPreview?
    @State private var isVisible = false

    private let saveManager = SaveManager()
    private var matchedSteamGame: SteamGameMetadata? {
        guard let metadata = library.steamMetadata[game.id], metadata.isVerifiedMatch else { return nil }
        return metadata
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("存档管理")
                    .font(.title2.bold())
                Spacer()
                Text(game.name)
                    .foregroundStyle(.secondary)
            }

            Text("自动检测存档位置。导入/导出为 zip 文件。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if matchedSteamGame == nil {
                Text(library.loadingSteamMetadata.contains(game.id)
                     ? "正在匹配 Steam 游戏，完成后可自动下载云存档。"
                     : "未可靠匹配到 Steam 游戏，云存档自动下载不可用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isLoading {
                ProgressView("扫描存档...")
            } else if saveLocations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("未找到存档")
                        .foregroundStyle(.secondary)
                    Button("重新扫描") {
                        loadSaves()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                VStack(spacing: 8) {
                    ForEach(saveLocations, id: \.path) { loc in
                        SaveLocationRow(location: loc) {
                            exportSaves(from: loc)
                        }
                    }
                }
            }

            if let message = message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(MythicTheme.accentLight)
            }

            Divider()

            HStack {
                Button("导入存档…") {
                    importSaves()
                }
                Button(isCheckingSteam ? "正在检查 Steam 游戏库…" : "自动下载 Steam 云存档…") {
                    checkSteamAndDownload()
                }
                .disabled(matchedSteamGame == nil || isCheckingSteam || steamSession.authentication == .checking)
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 540, height: 360)
        .background(MythicTheme.background)
        .tint(MythicTheme.accent)
        .onAppear {
            isVisible = true
            loadSaves()
            library.loadSteamMetadata(for: game)
        }
        .onDisappear { isVisible = false }
        .sheet(isPresented: $showingSteamCloud, onDismiss: {
            loadSaves()
            if steamSession.authentication == .signedOut { showingSteamSettings = true }
        }) {
            if let selectedCloudAppID {
                SteamCloudSheet(game: game, appID: selectedCloudAppID)
            }
        }
        .sheet(isPresented: $showingSteamSettings, onDismiss: {
            if steamSession.authentication == .signedIn { checkSteamAndDownload() }
        }) {
            SettingsSheet(openSteamOnAppear: true).environmentObject(library)
        }
        .sheet(item: $pendingImport) { preview in
            SaveImportReviewSheet(game: game, initialPreview: preview) { result in
                loadSaves()
                message = result.backupDirectory == nil
                    ? "✓ 已导入 \(result.fileCount) 个文件"
                    : "✓ 已导入 \(result.fileCount) 个文件；原文件备份于 \(result.backupDirectory!.path)"
            }
        }
    }

    private func checkSteamAndDownload() {
        guard let metadata = matchedSteamGame else {
            message = "这款游戏尚未可靠匹配到 Steam，无法自动下载。"
            return
        }
        isCheckingSteam = true
        steamSession.verifyAuthentication { isSignedIn in
            guard isVisible else { return }
            guard isSignedIn else {
                isCheckingSteam = false
                showingSteamSettings = true
                return
            }
            Task {
                do {
                    let cloudGames = try await steamSession.cloudGames()
                    guard isVisible else { return }
                    let localNames = [game.name, game.path.lastPathComponent]
                    let matchingCloudGames = cloudGames.filter {
                        SteamMetadataService.cloudTitlesMatch($0.name, localNames: localNames, matchedName: metadata.name)
                    }
                    var ownedAppID: Int?
                    for cloudGame in matchingCloudGames {
                        if try await steamSession.ownsGame(appID: cloudGame.appID) {
                            ownedAppID = cloudGame.appID
                            break
                        }
                    }
                    if ownedAppID == nil && matchingCloudGames.isEmpty {
                        if try await steamSession.ownsGame(appID: metadata.appID) {
                            ownedAppID = metadata.appID
                        }
                    }
                    guard isVisible else { return }
                    if let ownedAppID {
                        selectedCloudAppID = ownedAppID
                        showingSteamCloud = true
                    } else {
                        message = matchingCloudGames.isEmpty
                            ? "当前 Steam 账户未找到与《\(game.name)》对应的云端文件或已拥有的游戏。"
                            : "找到了《\(game.name)》的云端文件，但无法确认当前账户拥有对应的 Steam 版本。"
                    }
                } catch {
                    guard isVisible else { return }
                    message = "无法检查 Steam 游戏库：\(error.localizedDescription)"
                }
                isCheckingSteam = false
            }
        }
    }

    private func loadSaves() {
        isLoading = true
        message = nil
        Task.detached { [game] in
            let locs = SaveManager().locateSaves(for: game)
            await MainActor.run {
                saveLocations = locs
                isLoading = false
                if locs.isEmpty {
                    message = "未在此游戏中找到存档位置"
                }
            }
        }
    }

    private func exportSaves(from location: SaveManager.SaveLocation) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(game.name)_saves.zip"
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.prompt = "导出"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try saveManager.exportSaves(from: [location], to: url)
                message = "✓ 已导出到 \(url.lastPathComponent)"
            } catch {
                message = "✗ 导出失败: \(error.localizedDescription)"
            }
        }
    }

    private func importSaves() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "导入"
        if panel.runModal() == .OK, let url = panel.url {
            guard let directory = saveManager.suggestedImportDirectory(for: game) else {
                message = "无法识别存档位置，请先添加游戏目录"
                return
            }
            Task.detached {
                do {
                    let preview = try SaveManager().previewImport(from: url, to: directory)
                    await MainActor.run {
                        pendingImport = preview
                    }
                } catch {
                    await MainActor.run {
                        message = "✗ 无法读取存档包：\(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

struct SaveLocationRow: View {
    let location: SaveManager.SaveLocation
    let onExport: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(location.path.lastPathComponent)
                    .fontWeight(.medium)
                Text("\(location.fileCount) 个文件 · \(formatSize(location.sizeBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(location.path.deletingLastPathComponent().lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                onExport()
            } label: {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(MythicTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
