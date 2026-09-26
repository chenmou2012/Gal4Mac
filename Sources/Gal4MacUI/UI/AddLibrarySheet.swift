import SwiftUI
import Gal4MacCore
import AppKit

/// 添加库路径弹窗
struct AddLibrarySheet: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var path: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加库路径")
                .font(.title2.bold())

            Text("选择包含游戏的根目录\n可以是本地磁盘、外接硬盘或网络盘。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField("路径", text: $path)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addLibrary() }
                Button("选择…") {
                    selectFolder()
                }
            }

            Spacer()

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("添加") { addLibrary() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(path.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(MythicTheme.background)
        .tint(MythicTheme.accent)
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择包含游戏的根目录"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }

    private func addLibrary() {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        library.addLibrary(url)
        library.scanAll()
        dismiss()
    }
}

/// 设置弹窗
struct SettingsSheet: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var steamSession = SteamWebSession.shared
    @State private var selectedPage: SettingsPage
    @State private var steamWebID = UUID()
    @State private var selectedImportGameID: UUID?
    @State private var transferStatus: String?
    @State private var pendingImports: [PendingSaveImport] = []
    @State private var activeImport: PendingSaveImport?

    private enum SettingsPage: String, CaseIterable {
        case general = "常规"
        case steam = "Steam"
    }

    init(openSteamOnAppear: Bool = false) {
        _selectedPage = State(initialValue: openSteamOnAppear ? .steam : .general)
    }

    private struct PendingSaveImport: Identifiable {
        let id = UUID()
        let game: Game
        let preview: SaveArchiveManager.ImportPreview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.title2.bold())

            Picker("设置分类", selection: $selectedPage) {
                ForEach(SettingsPage.allCases, id: \.self) { page in
                    Text(page.rawValue).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if selectedPage == .general {
                // Engine 状态
                VStack(alignment: .leading, spacing: 8) {
                    Label("Mythic Engine", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    if let version = EngineManager.currentVersion() {
                        Text("版本: \(version.string)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("路径: \(EngineManager.engineDirectory.path)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                .padding()
                .background(MythicTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // 一键存档备份与恢复
                VStack(alignment: .leading, spacing: 10) {
                    Text("存档")
                        .font(.headline)
                    HStack {
                        Button("一键导出全部存档…", action: exportAllSaves)
                            .disabled(library.games.isEmpty)
                        Button("导入存档包…", action: importSaveArchives)
                            .disabled(library.games.isEmpty)
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 8) {
                        Text("无法从文件名识别游戏时，导入到")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("目标游戏", selection: $selectedImportGameID) {
                            Text("选择游戏").tag(UUID?.none)
                            ForEach(library.games) { game in
                                Text(game.name).tag(Optional(game.id))
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 190)
                    }
                    if let transferStatus {
                        Text(transferStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(3)
                    }
                }
                .padding()
                .background(MythicTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // 库路径列表
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("库路径 (\(library.config.libraryPaths.count))")
                            .font(.headline)
                        Spacer()
                        Button {
                            library.showingAddLibrary = true
                        } label: {
                            Label("添加", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }

                    if library.config.libraryPaths.isEmpty {
                        Text("未配置库路径")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        List {
                            ForEach(library.config.libraryPaths, id: \.self) { path in
                                HStack {
                                    Image(systemName: library.isAccessible(path) ? "external.drive.connected.to.line.below" : "external.drive.badge.exclamationmark")
                                        .foregroundStyle(library.isAccessible(path) ? .green : .orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(path.lastPathComponent)
                                        Text(path.path)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    Spacer()
                                    if !library.isAccessible(path) {
                                        Text("不可访问")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                    Button {
                                        library.removeLibrary(path)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.red)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listStyle(.bordered)
                        .frame(minHeight: 160)
                    }
                }

                Spacer()
            } else {
                steamSettings
            }

            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: selectedPage == .steam ? 920 : 600, height: selectedPage == .steam ? 720 : 620)
        .background(MythicTheme.background)
        .tint(MythicTheme.accent)
        .onDisappear { steamSession.release(ownerID: steamWebID) }
        .sheet(item: $activeImport, onDismiss: showNextImport) { item in
            SaveImportReviewSheet(game: item.game, initialPreview: item.preview) { result in
                transferStatus = "已导入 \(item.game.name) 的 \(result.fileCount) 个文件"
                if let backup = result.backupDirectory {
                    transferStatus! += "；覆盖文件的备份保存在 \(backup.path)"
                }
            }
        }
    }

    private var steamSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Steam 云存档")
                    .font(.headline)
                Spacer()
                Button("检查登录状态") {
                    steamSession.verifyAuthentication { _ in }
                }
                .disabled(steamSession.authentication == .checking)
            }

            Label(steamStatusText, systemImage: steamStatusSymbol)
                .foregroundStyle(steamStatusColor)
                .accessibilityLabel("Steam 登录状态：\(steamStatusText)")

            Text("在下方 Steam 官方页面登录一次。登录状态会用于之后的云存档下载。")
                .font(.callout)
                .foregroundStyle(.secondary)

            SteamRemoteStorageWebView(
                ownerID: steamWebID,
                pageURL: SteamWebSession.accountURL,
                onDownloaded: { url, _ in try? FileManager.default.removeItem(at: url) },
                onError: { _ in }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var steamStatusText: String {
        switch steamSession.authentication {
        case .unknown: return "等待检查"
        case .checking: return "正在检查登录状态…"
        case .signedIn: return "已登录，可下载云存档"
        case .signedOut: return "未登录，请在下方登录"
        case .unavailable: return "无法连接 Steam，请稍后重试"
        }
    }

    private var steamStatusSymbol: String {
        switch steamSession.authentication {
        case .signedIn: return "checkmark.circle.fill"
        case .unavailable: return "exclamationmark.triangle.fill"
        case .unknown, .checking, .signedOut: return "person.crop.circle"
        }
    }

    private var steamStatusColor: Color {
        switch steamSession.authentication {
        case .signedIn: return .green
        case .unavailable: return .orange
        case .unknown, .checking, .signedOut: return .secondary
        }
    }

    private func exportAllSaves() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "导出到此文件夹"
        panel.message = "每个游戏的存档将分别打包为 ZIP 文件。"
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        let games = library.games
        transferStatus = "正在导出存档…"
        Task.detached {
            let manager = SaveManager()
            var exported = 0
            var skipped: [String] = []
            var failures: [String] = []

            for game in games {
                let locations = manager.locateSaves(for: game)
                guard !locations.isEmpty else {
                    skipped.append(game.name)
                    continue
                }
                for location in locations {
                    let suffix = locations.count > 1 ? "_\(safeSaveFileComponent(location.path.lastPathComponent))" : ""
                    let filename = "\(safeSaveFileComponent(game.name))\(suffix)_saves.zip"
                    do {
                        try manager.exportSaves(
                            from: [location],
                            to: uniqueSaveArchiveURL(in: folder, filename: filename)
                        )
                        exported += 1
                    } catch {
                        failures.append("\(game.name): \(error.localizedDescription)")
                    }
                }
            }

            let summary = saveExportSummary(exported: exported, skipped: skipped, failures: failures)
            await MainActor.run {
                transferStatus = summary
            }
        }
    }

    private func importSaveArchives() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "选择存档包"
        panel.message = "可多选此前导出的 ZIP 存档包；覆盖前会显示确认和备份信息。"
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        let archiveURLs = panel.urls
        let games = library.games
        let fallbackGame = games.first { $0.id == selectedImportGameID }
        transferStatus = "正在检查存档包…"
        Task.detached {
            let manager = SaveManager()
            var imports: [PendingSaveImport] = []
            var skipped: [String] = []
            for archiveURL in archiveURLs {
                let stem = archiveURL.deletingPathExtension().lastPathComponent
                let matchedGame = games
                    .sorted { $0.name.count > $1.name.count }
                    .first { stem == $0.name || stem.hasPrefix("\($0.name)_") }
                guard let game = matchedGame ?? fallbackGame,
                      let target = saveImportTarget(for: stem, game: game, manager: manager) else {
                    skipped.append(archiveURL.lastPathComponent)
                    continue
                }
                do {
                    let preview = try manager.previewImport(from: archiveURL, to: target)
                    imports.append(PendingSaveImport(game: game, preview: preview))
                } catch {
                    skipped.append("\(archiveURL.lastPathComponent)（\(error.localizedDescription)）")
                }
            }

            let readyImports = imports
            let skippedFiles = skipped
            let summary = "找到 \(readyImports.count) 个可导入存档包" +
                (skippedFiles.isEmpty ? "" : "；跳过：\(skippedFiles.joined(separator: "、"))")
            await MainActor.run {
                pendingImports = readyImports
                transferStatus = summary
                showNextImport()
            }
        }
    }

    private func showNextImport() {
        guard !pendingImports.isEmpty else {
            activeImport = nil
            return
        }
        activeImport = pendingImports.removeFirst()
    }

}

private func safeSaveFileComponent(_ value: String) -> String {
    value.replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: ":", with: "_")
}

private func uniqueSaveArchiveURL(in folder: URL, filename: String) -> URL {
    let original = URL(fileURLWithPath: filename)
    let name = original.deletingPathExtension().lastPathComponent
    let ext = original.pathExtension
    var candidate = folder.appendingPathComponent(filename)
    var index = 2
    while FileManager.default.fileExists(atPath: candidate.path) {
        candidate = folder.appendingPathComponent("\(name)-\(index).\(ext)")
        index += 1
    }
    return candidate
}

private func saveExportSummary(exported: Int, skipped: [String], failures: [String]) -> String {
    var message = "已导出 \(exported) 个存档包"
    if !skipped.isEmpty { message += "；没有找到存档：\(skipped.joined(separator: "、"))" }
    if !failures.isEmpty { message += "；失败：\(failures.joined(separator: "；"))" }
    return message
}

private func saveImportTarget(for stem: String, game: Game, manager: SaveManager) -> URL? {
    let normalizedStem = stem.replacingOccurrences(of: "-\\d+$", with: "", options: .regularExpression)
    let prefix = "\(game.name)_"
    if normalizedStem.hasPrefix(prefix), normalizedStem.hasSuffix("_saves") {
        let locationName = String(normalizedStem.dropFirst(prefix.count).dropLast("_saves".count))
        if !locationName.isEmpty,
           let location = manager.locateSaves(for: game).first(where: {
               safeSaveFileComponent($0.path.lastPathComponent) == locationName
           }) {
            return location.path
        }
    }
    return manager.suggestedImportDirectory(for: game)
}
