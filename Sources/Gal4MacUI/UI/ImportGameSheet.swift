import SwiftUI
import Gal4MacCore
import AppKit
import UniformTypeIdentifiers

/// 导入游戏弹窗（支持单游戏目录 或 压缩包）
struct ImportGameSheet: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedURL: URL?
    @State private var selectedEngine: EngineType = .unknown
    @State private var selectedExecutable: String = ""
    @State private var executableOptions: [String] = []
    @State private var isExtracting = false
    @State private var extractMessage: String?

    private let detector = EngineDetector()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导入游戏")
                .font(.title2.bold())

            Text("选择游戏目录，或选择压缩包（zip/rar/7z，支持常见分卷）自动解压。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(displayPath)
                    .font(.callout)
                    .foregroundStyle(selectedURL == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MythicTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Button("选择…") {
                    selectGame()
                }
            }

            // 解压进度
            if isExtracting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(extractMessage ?? "正在解压…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            // 检测结果
            if !isExtracting, selectedURL != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Label("游戏配置", systemImage: "gamecontroller")
                        .font(.headline)

                    Picker("引擎", selection: $selectedEngine) {
                        ForEach(EngineType.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }

                    if !executableOptions.isEmpty {
                        Picker("可执行文件", selection: $selectedExecutable) {
                            ForEach(executableOptions, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }

                    if selectedEngine == .unknown {
                        Text("未识别引擎。可以尝试通用 Wine 启动，兼容性未经验证。")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                    if executableOptions.isEmpty {
                        Text("未找到 .exe 可执行文件")
                            .foregroundStyle(.orange)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MythicTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("导入") {
                    if let url = selectedURL {
                        library.addGame(at: url, engine: selectedEngine, executable: selectedExecutable)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedURL == nil || selectedExecutable.isEmpty || isExtracting)
            }
        }
        .padding(20)
        .frame(width: 540)
        .background(MythicTheme.background)
        .tint(MythicTheme.accent)
    }

    private var displayPath: String {
        if let url = selectedURL {
            return url.path
        }
        return "未选择（支持目录、zip、rar、7z 及分卷）"
    }

    private func selectGame() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择游戏目录或压缩包"
        panel.message = "选择游戏根目录，或者选择 zip/rar/7z 压缩包或分卷首卷自动解压"

        // 允许的文件类型
        var types: [UTType] = [.folder, .zip]
        if let rar = UTType(filenameExtension: "rar") { types.append(rar) }
        if let sevenZ = UTType(filenameExtension: "7z") { types.append(sevenZ) }
        if let volume = UTType(filenameExtension: "001") { types.append(volume) }
        panel.allowedContentTypes = types

        if panel.runModal() == .OK, let url = panel.url {
            handleSelection(url: url)
        }
    }

    /// 处理用户选择：如果是压缩包则解压
    private func handleSelection(url: URL) {
        let format = ArchiveExtractor().detectFormat(at: url)

        if format == .unknown {
            // 普通目录，直接使用
            selectedURL = url
            detectGame(at: url)
        } else {
            // 压缩包，先解压
            extractArchive(at: url)
        }
    }

    /// 解压压缩包
    private func extractArchive(at archiveURL: URL) {
        isExtracting = true
        extractMessage = "解压 \(archiveURL.lastPathComponent)..."

        Task.detached {
            do {
                // 解压到 ~/Library/Application Support/Gal4Mac/Extracted/<游戏名>/
                let appSupport = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first!
                let extractDir = appSupport
                    .appendingPathComponent("Gal4Mac", isDirectory: true)
                    .appendingPathComponent("Extracted", isDirectory: true)
                    .appendingPathComponent(archiveURL.deletingPathExtension().lastPathComponent)

                let extractor = ArchiveExtractor()
                let gameDir = try extractor.extract(archiveURL: archiveURL, to: extractDir)

                await MainActor.run {
                    selectedURL = gameDir
                    isExtracting = false
                    extractMessage = nil
                    detectGame(at: gameDir)
                }
            } catch {
                await MainActor.run {
                    isExtracting = false
                    extractMessage = "❌ \(error.localizedDescription)"
                    selectedURL = nil
                }
            }
        }
    }

    private func detectGame(at url: URL) {
        selectedEngine = detector.detect(at: url)
        executableOptions = ((try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )) ?? [])
            .filter { $0.pathExtension.lowercased() == "exe" }
            .map(\.lastPathComponent)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        selectedExecutable = detector.findExecutable(at: url, engine: selectedEngine)
            ?? executableOptions.first ?? ""
    }
}
