import SwiftUI
import Gal4MacCore
import AppKit

/// 添加库路径弹窗
struct AddLibrarySheet: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var path: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            GalSheetHeader(
                title: "添加游戏库",
                subtitle: "选择包含游戏的文件夹。支持本地磁盘、外接硬盘和网络盘。",
                symbol: "folder.badge.plus"
            )

            VStack(alignment: .leading, spacing: 9) {
                Text("文件夹位置")
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    TextField("输入路径或选择文件夹", text: $path)
                        .textFieldStyle(.plain)
                        .onSubmit { addLibrary() }
                    Button("选择…", action: selectFolder)
                }
                .padding(12)
                .galSheetCard()
            }

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("添加游戏库", action: addLibrary)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
        .frame(minHeight: 240, alignment: .topLeading)
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
struct SettingsView: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @State private var selectedImportGameID: UUID?
    @State private var transferStatus: String?
    @State private var pendingImports: [PendingSaveImport] = []
    @State private var activeImport: PendingSaveImport?

    private struct PendingSaveImport: Identifiable {
        let id = UUID()
        let game: Game
        let preview: SaveArchiveManager.ImportPreview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GalSheetHeader(
                title: "设置",
                subtitle: "管理运行环境、存档备份和游戏库位置。",
                symbol: "gearshape"
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Engine 状态
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Mythic Engine", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        if let version = EngineManager.currentVersion() {
                            Text("版本: \(version.string)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        Text("路径: \(EngineManager.engineDirectory.path)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    .padding(14)
                    .galSheetCard()

                    // 一键存档备份与恢复
                    VStack(alignment: .leading, spacing: 10) {
                        Label("存档备份", systemImage: "archivebox")
                            .font(.headline)
                        HStack {
                            Button("导出全部…", action: exportAllSaves)
                                .disabled(library.games.isEmpty)
                            Button("导入存档包…", action: importSaveArchives)
                                .disabled(library.games.isEmpty)
                            Spacer(minLength: 0)
                        }
                        HStack(spacing: 8) {
                            Text("无法从文件名识别时，导入到")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Picker("目标游戏", selection: $selectedImportGameID) {
                                Text("选择游戏").tag(UUID?.none)
                                ForEach(library.games) { game in
                                    Text(game.displayName).tag(Optional(game.id))
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 210)
                        }
                        if let transferStatus {
                            Label(
                                transferStatus,
                                systemImage: transferStatus.hasPrefix("正在")
                                    ? "arrow.triangle.2.circlepath"
                                    : (transferStatus.contains("失败") || transferStatus.contains("跳过") ? "exclamationmark.triangle" : "checkmark.circle")
                            )
                                .font(.caption)
                                .foregroundStyle(transferStatus.contains("失败") ? .orange : .secondary)
                                .textSelection(.enabled)
                                .lineLimit(3)
                        }
                    }
                    .padding(14)
                    .galSheetCard()

                    // 库路径列表
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("游戏库路径", systemImage: "externaldrive")
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
                            ContentUnavailableView("未配置游戏库", systemImage: "externaldrive", description: Text("添加一个包含游戏的文件夹开始使用。"))
                                .frame(minHeight: 110)
                        } else {
                            List {
                                ForEach(library.config.libraryPaths, id: \.self) { path in
                                    HStack(spacing: 10) {
                                        Image(systemName: library.isAccessible(path) ? "externaldrive.connected.to.line.below" : "externaldrive.badge.exclamationmark")
                                            .foregroundStyle(library.isAccessible(path) ? .green : .orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(path.lastPathComponent)
                                                .font(.callout.weight(.medium))
                                            Text(path.path)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        Spacer()
                                        if !library.isAccessible(path) {
                                            Text("不可访问")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                        Button {
                                            library.removeLibrary(path)
                                        } label: {
                                            Image(systemName: "minus.circle")
                                        }
                                        .buttonStyle(.borderless)
                                        .foregroundStyle(.red)
                                        .help("移除游戏库路径")
                                    }
                                    .padding(.vertical, 3)
                                    .listRowSeparator(.hidden)
                                }
                            }
                            .listStyle(.inset)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 100, maxHeight: 220)
                        }
                    }
                    .padding(14)
                    .galSheetCard()
                }
                .padding(.vertical, 2)
            }

        }
        .padding(24)
        .frame(maxWidth: 760, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $activeImport, onDismiss: showNextImport) { item in
            SaveImportReviewSheet(game: item.game, initialPreview: item.preview) { result in
                transferStatus = "已导入 \(item.game.displayName) 的 \(result.fileCount) 个文件"
                if let backup = result.backupDirectory {
                    transferStatus! += "；覆盖文件的备份保存在 \(backup.path)"
                }
            }
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
                    skipped.append(game.displayName)
                    continue
                }
                for location in locations {
                    let suffix = locations.count > 1 ? "_\(safeSaveFileComponent(location.path.lastPathComponent))" : ""
                    let filename = "\(safeSaveFileComponent(game.displayName))\(suffix)_saves.zip"
                    do {
                        try manager.exportSaves(
                            from: [location],
                            to: uniqueSaveArchiveURL(in: folder, filename: filename)
                        )
                        exported += 1
                    } catch {
                        failures.append("\(game.displayName): \(error.localizedDescription)")
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
                    .sorted { max($0.name.count, $0.displayName.count) > max($1.name.count, $1.displayName.count) }
                    .first { game in
                        [game.displayName, game.name].contains { stem == $0 || stem.hasPrefix("\($0)_") }
                    }
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
    let archiveName = [game.displayName, game.name].first { normalizedStem.hasPrefix("\($0)_") } ?? game.name
    let prefix = "\(archiveName)_"
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
