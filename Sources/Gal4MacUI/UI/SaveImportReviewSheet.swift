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
        VStack(alignment: .leading, spacing: 18) {
            GalSheetHeader(
                title: "确认导入存档",
                subtitle: "检查文件和目标位置后再继续。覆盖的原文件会先备份。",
                symbol: "archivebox"
            )

            VStack(alignment: .leading, spacing: 11) {
                Label(preview.archiveURL.lastPathComponent, systemImage: "doc.zipper")
                    .lineLimit(1)
                    .truncationMode(.middle)
                Divider()
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "folder")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 7) {
                        Text("存档目标文件夹")
                            .font(.subheadline.weight(.semibold))
                        Text(preview.targetDirectory.path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                        Button("选择其他文件夹…", action: chooseDirectory)
                            .disabled(isWorking)
                    }
                }
            }
            .padding(14)
            .galSheetCard()

            HStack(spacing: 10) {
                Image(systemName: preview.overwrittenFiles.isEmpty ? "checkmark.circle" : "exclamationmark.arrow.circlepath")
                    .foregroundStyle(preview.overwrittenFiles.isEmpty ? .green : .orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("导入 \(preview.files.count) 个文件 · 覆盖 \(preview.overwrittenFiles.count) 个")
                        .font(.subheadline.weight(.semibold))
                    if !preview.overwrittenFiles.isEmpty {
                        Text("将替换：\(preview.overwrittenFiles.prefix(8).joined(separator: "、"))\(preview.overwrittenFiles.count > 8 ? "…" : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .galSheetCard()

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .textSelection(.enabled)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .disabled(isWorking)
                    .keyboardShortcut(.cancelAction)
                Button(isWorking ? "导入中…" : "确认导入", action: importArchive)
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking || preview.files.isEmpty)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620)
        .frame(minHeight: 410, alignment: .topLeading)
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
