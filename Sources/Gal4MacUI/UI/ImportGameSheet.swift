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
    @State private var displayName = ""
    @State private var executableOptions: [String] = []
    @State private var isExtracting = false
    @State private var extractMessage: String?

    private let detector = EngineDetector()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GalSheetHeader(
                title: "导入游戏",
                subtitle: "选择游戏文件夹，或导入 ZIP、RAR、7Z 压缩包并自动解压。",
                symbol: "square.and.arrow.down"
            )

            HStack(spacing: 12) {
                Image(systemName: selectedURL == nil ? "folder" : "folder.fill")
                    .foregroundStyle(selectedURL == nil ? .secondary : Color.accentColor)
                Text(displayPath)
                    .font(.callout)
                    .foregroundStyle(selectedURL == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("选择…", action: selectGame)
            }
            .padding(12)
            .galSheetCard()

            // 解压进度
            if isExtracting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(extractMessage ?? "正在解压…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .galSheetCard()
            }

            // 检测结果
            if !isExtracting, selectedURL != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Label("游戏配置", systemImage: "gamecontroller")
                        .font(.headline)

                    TextField("显示名称", text: $displayName)
                    Text("此名称会显示在侧栏、统计和游戏详情中。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .galSheetCard()
            }

            Spacer()

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("导入") {
                    if let url = selectedURL {
                        library.addGame(at: url, engine: selectedEngine, executable: selectedExecutable, customDisplayName: displayName)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedURL == nil || selectedExecutable.isEmpty || isExtracting)
            }
        }
        .padding(24)
        .frame(width: 560)
        .frame(minHeight: 390, alignment: .topLeading)
    }

    private var displayPath: String {
        if let url = selectedURL {
            return url.path
        }
        return "未选择（支持目录、zip、rar、7z）"
    }

    private func selectGame() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择游戏目录或压缩包"
        panel.message = "选择游戏根目录，或者选择 zip/rar/7z 压缩包自动解压"

        // 允许的文件类型
        var types: [UTType] = [.folder, .zip]
        if let rar = UTType(filenameExtension: "rar") { types.append(rar) }
        if let sevenZ = UTType(filenameExtension: "7z") { types.append(sevenZ) }
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
        let existing = library.games.first { $0.path.standardizedFileURL == url.standardizedFileURL }
        displayName = existing?.customDisplayName ?? url.lastPathComponent
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
