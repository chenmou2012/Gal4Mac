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

    private let saveManager = SaveManager()

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
                    .foregroundStyle(.blue)
            }

            Divider()

            HStack {
                Button("导入存档…") {
                    importSaves()
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 540, height: 360)
        .onAppear {
            loadSaves()
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
            Task.detached { [game] in
                do {
                    let count = try SaveManager().importSaves(from: url, to: game)
                    await MainActor.run {
                        message = "✓ 已导入 \(count) 个文件"
                        loadSaves()
                    }
                } catch {
                    await MainActor.run {
                        message = "✗ 导入失败: \(error.localizedDescription)"
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
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
