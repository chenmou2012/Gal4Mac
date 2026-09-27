import AppKit
import Gal4MacCore
import SwiftUI

private struct CloudDownload: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    var filename: String
}

struct SteamCloudSheet: View {
    let game: Game
    let appID: Int
    let onLoginRequired: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var session = SteamWebSession.shared
    @State private var ownerID = UUID()
    @State private var targetDirectory: URL?
    @State private var downloads: [CloudDownload] = []
    @State private var isChecking = false
    @State private var isDownloading = false
    @State private var isImporting = false
    @State private var completedCount = 0
    @State private var totalCount = 0
    @State private var downloadErrors: [String] = []
    @State private var message: String?
    @State private var showingConfirmation = false
    @State private var showingSteamPage = false

    init(game: Game, appID: Int, onLoginRequired: @escaping () -> Void) {
        self.game = game
        self.appID = appID
        self.onLoginRequired = onLoginRequired
        _targetDirectory = State(initialValue: SaveManager().suggestedImportDirectory(for: game))
    }

    private var isBusy: Bool { isChecking || isDownloading || isImporting }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("同步 Steam 存档").font(.title2.weight(.semibold))
                    Text("\(game.name) · AppID \(appID)")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭") { dismiss() }.disabled(isBusy)
            }

            Text("确认存档目录后，点击下载并导入。已有的同名存档会先备份。")
                .font(.callout).foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "folder.fill").foregroundStyle(GlassPalette.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("导入位置").font(.callout.weight(.medium))
                    Text(targetDirectory?.path ?? "尚未找到存档目录，请手动选择")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2).truncationMode(.middle)
                }
                Spacer(minLength: 10)
                Button("选择目录…") { chooseTarget() }.disabled(isBusy)
            }
            .padding(14)
            .background(GlassPalette.surface, in: RoundedRectangle(cornerRadius: 12))

            SteamRemoteStorageWebView(
                ownerID: ownerID,
                pageURL: SteamWebSession.accountURL,
                onDownloaded: { url, filename in
                    downloads.append(CloudDownload(url: url, filename: filename))
                },
                onError: { downloadErrors.append($0) }
            )
            .frame(height: showingSteamPage ? 190 : 1)
            .clipShape(RoundedRectangle(cornerRadius: showingSteamPage ? 12 : 0))

            if isChecking {
                ProgressView("正在检查这款游戏的云存档…")
            } else if isDownloading {
                VStack(alignment: .leading, spacing: 7) {
                    Text("正在下载 \(completedCount) / \(totalCount)").font(.callout)
                    ProgressView(value: Double(completedCount), total: Double(max(totalCount, 1)))
                }
            } else if isImporting {
                ProgressView("正在导入存档…")
            }

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(downloadErrors.isEmpty ? GlassPalette.secondary : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !downloads.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("待导入文件").font(.headline)
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach($downloads) { $download in
                                HStack(spacing: 10) {
                                    Image(systemName: "doc")
                                    TextField("存档文件名", text: $download.filename)
                                        .textFieldStyle(.roundedBorder)
                                    Button("导入") { importOne(download) }
                                        .disabled(targetDirectory == nil || isBusy)
                                }
                                .padding(10)
                                .background(GlassPalette.surface, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .frame(maxHeight: 130)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button(showingSteamPage ? "收起 Steam 页面" : "查看 Steam 页面") {
                    showingSteamPage.toggle()
                    if showingSteamPage && !isBusy {
                        session.webView.load(URLRequest(url: SteamWebSession.accountURL))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(GlassPalette.secondary)
                .disabled(isBusy)
                Spacer()
                Button("下载并导入") { showingConfirmation = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(targetDirectory == nil || isBusy || session.authentication != .signedIn)
            }
        }
        .padding(22)
        .frame(width: 650, height: 430)
        .background(GlassPalette.background)
        .tint(GlassPalette.blue)
        .interactiveDismissDisabled(isBusy)
        .alert("下载并导入 Steam 云存档？", isPresented: $showingConfirmation) {
            Button("取消", role: .cancel) {}
            Button("下载并导入") { startSync() }
        } message: {
            Text("将从当前 Steam 账户下载 \(game.name) 的云存档并导入到 \(targetDirectory?.path ?? "所选目录")。同名本地文件会先备份。")
        }
        .onDisappear {
            session.release(ownerID: ownerID)
            for download in downloads { try? FileManager.default.removeItem(at: download.url) }
        }
    }

    private func startSync() {
        guard targetDirectory != nil, !isBusy else { return }
        guard session.authentication == .signedIn else {
            onLoginRequired()
            return
        }
        isChecking = true
        message = nil
        downloadErrors = []
        completedCount = 0
        totalCount = 0
        Task { @MainActor in
            do {
                let files = try await session.cloudFiles(appID: appID)
                isChecking = false
                guard !files.isEmpty else {
                    message = "Steam 云端没有这款游戏的存档文件。"
                    return
                }
                isDownloading = true
                session.downloadCloudFiles(
                    files,
                    ownerID: ownerID,
                    onDownloaded: { url, filename in
                        downloads.append(CloudDownload(url: url, filename: filename))
                    },
                    onError: { downloadErrors.append($0) },
                    onProgress: { completed, total in
                        completedCount = completed
                        totalCount = total
                    },
                    onComplete: {
                        isDownloading = false
                        importAll()
                    }
                )
            } catch {
                isChecking = false
                if session.authentication != .signedIn {
                    onLoginRequired()
                } else {
                    message = "读取 Steam 云存档失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func importAll() {
        guard let targetDirectory else { return }
        guard !downloads.isEmpty else {
            message = downloadErrors.isEmpty
                ? "没有下载到可导入的文件。"
                : "下载失败：\(downloadErrors.joined(separator: "；"))"
            return
        }
        let names = downloads.map { $0.filename.lowercased() }
        guard Set(names).count == names.count else {
            message = "云端有同名文件。请检查下面的文件名，再逐个导入。"
            return
        }
        let pending = downloads
        isImporting = true
        Task.detached {
            let importer = SteamCloudImporter()
            var importedIDs = Set<UUID>()
            var failures: [String] = []
            var backupCount = 0
            for download in pending {
                do {
                    let result = try importer.importFile(
                        from: download.url,
                        named: download.filename,
                        into: targetDirectory
                    )
                    importedIDs.insert(download.id)
                    if result.backup != nil { backupCount += 1 }
                } catch {
                    failures.append("\(download.filename)：\(error.localizedDescription)")
                }
            }
            let completedIDs = importedIDs
            let completedBackupCount = backupCount
            let failureCount = failures.count
            await MainActor.run {
                let imported = pending.filter { completedIDs.contains($0.id) }
                downloads.removeAll { completedIDs.contains($0.id) }
                for item in imported { try? FileManager.default.removeItem(at: item.url) }
                var summary = "已导入 \(imported.count) 个存档文件"
                if completedBackupCount > 0 { summary += "；\(completedBackupCount) 个原文件已备份" }
                if !downloadErrors.isEmpty { summary += "；\(downloadErrors.count) 个下载失败" }
                if failureCount > 0 { summary += "；\(failureCount) 个导入失败。请检查下方文件后重试" }
                message = summary + "。"
                isImporting = false
            }
        }
    }

    private func importOne(_ download: CloudDownload) {
        guard let targetDirectory, !isBusy else { return }
        isImporting = true
        Task.detached {
            do {
                let result = try SteamCloudImporter().importFile(
                    from: download.url,
                    named: download.filename.trimmingCharacters(in: .whitespacesAndNewlines),
                    into: targetDirectory
                )
                await MainActor.run {
                    downloads.removeAll { $0.id == download.id }
                    try? FileManager.default.removeItem(at: download.url)
                    message = result.backup == nil
                        ? "已导入 \(result.destination.lastPathComponent)。"
                        : "已导入 \(result.destination.lastPathComponent)，原文件已备份。"
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    message = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }

    private func chooseTarget() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = "选择 \(game.name) 的存档目录"
        panel.directoryURL = targetDirectory ?? game.path
        if panel.runModal() == .OK { targetDirectory = panel.url }
    }
}
