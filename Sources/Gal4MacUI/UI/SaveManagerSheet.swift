import SwiftUI
import Gal4MacCore
import AppKit

/// 存档管理弹窗
struct SaveManagerSheet: View {
    let game: Game
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss

    @State private var saveLocations: [SaveManager.SaveLocation] = []
    @State private var isLoading = false
    @State private var message: String?
    @State private var showingSteamCloud = false
    @State private var pendingImport: SaveArchiveManager.ImportPreview?

    private let saveManager = SaveManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GalSheetHeader(
                title: "存档管理",
                subtitle: "\(game.displayName) · 检查本地存档，并安全导入或导出 ZIP。",
                symbol: "archivebox"
            )

            Group {
                if isLoading {
                    ProgressView("正在扫描存档位置…")
                        .frame(maxWidth: .infinity, minHeight: 150)
                } else if saveLocations.isEmpty {
                    ContentUnavailableView {
                        Label("未找到存档", systemImage: "tray")
                    } description: {
                        Text("可以重新扫描，或从 Steam 云端下载存档。")
                    } actions: {
                        Button("重新扫描", action: loadSaves)
                    }
                    .frame(maxWidth: .infinity, minHeight: 170)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 9) {
                            ForEach(saveLocations, id: \.path) { loc in
                                SaveLocationRow(location: loc) {
                                    exportSaves(from: loc)
                                }
                            }
                        }
                        .padding(12)
                    }
                    .frame(minHeight: 150, maxHeight: 260)
                }
            }
            .galSheetCard()

            if let message {
                Label(
                    message,
                    systemImage: (message.hasPrefix("✗") || message.contains("未找到") || message.contains("无法"))
                        ? "exclamationmark.triangle"
                        : "checkmark.circle"
                )
                    .font(.callout)
                    .foregroundStyle((message.hasPrefix("✗") || message.contains("未找到") || message.contains("无法")) ? .orange : .secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            HStack {
                Button("导入存档…") {
                    importSaves()
                }
                .buttonStyle(.bordered)
                Button("从 Steam 云端下载…") {
                    showingSteamCloud = true
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 600)
        .frame(minHeight: 370, alignment: .topLeading)
        .onAppear {
            loadSaves()
        }
        .sheet(isPresented: $showingSteamCloud, onDismiss: loadSaves) {
            SteamCloudSheet(game: game)
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
        panel.nameFieldStringValue = "\(game.displayName)_saves.zip"
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
        .padding(11)
        .galSheetCard(cornerRadius: 11)
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
