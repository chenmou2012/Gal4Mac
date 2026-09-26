import AppKit
import SwiftUI
import Gal4MacCore

/// 展示 ZIP 内容和实际写入位置，由用户确认后再改动游戏存档。
struct SaveImportReviewSheet: View {
    let game: Game
    let onImported: (SaveArchiveManager.ImportResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var preview: SaveArchiveManager.ImportPreview
    @State private var isWorking = false
    @State private var errorMessage: String?

    init(game: Game, initialPreview: SaveArchiveManager.ImportPreview,
         onImported: @escaping (SaveArchiveManager.ImportResult) -> Void) {
        self.game = game
        self.onImported = onImported
        _preview = State(initialValue: initialPreview)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("确认导入存档")
                .font(.title2.bold())
            Text("压缩包：\(preview.archiveURL.lastPathComponent)")
            Text("目标目录：")
                .fontWeight(.semibold)
            Text(preview.targetDirectory.path)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
            Button("选择其他存档目录…", action: chooseDirectory)
                .disabled(isWorking)

            Text("将导入 \(preview.files.count) 个文件；其中 \(preview.overwrittenFiles.count) 个同名文件会被覆盖并备份。")
            if !preview.overwrittenFiles.isEmpty {
                Text("将覆盖：\(preview.overwrittenFiles.prefix(8).joined(separator: "、"))\(preview.overwrittenFiles.count > 8 ? "…" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            Spacer()
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .disabled(isWorking)
                Button(isWorking ? "导入中…" : "确认导入", action: importArchive)
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)
            }
        }
        .padding(20)
        .frame(width: 610, height: 310)
        .background(MythicTheme.background)
        .tint(MythicTheme.accent)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择存档目录"
        panel.message = "请选择 \(game.name) 实际读取存档的目录"
        panel.directoryURL = preview.targetDirectory
        guard panel.runModal() == .OK, let directory = panel.url else { return }
        isWorking = true
        Task.detached { [archiveURL = preview.archiveURL] in
            do {
                let updated = try SaveManager().previewImport(from: archiveURL, to: directory)
                await MainActor.run {
                    preview = updated
                    errorMessage = nil
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }

    private func importArchive() {
        isWorking = true
        let confirmed = preview
        Task.detached {
            do {
                let result = try SaveManager().importSaves(confirmed)
                await MainActor.run {
                    onImported(result)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }
}
