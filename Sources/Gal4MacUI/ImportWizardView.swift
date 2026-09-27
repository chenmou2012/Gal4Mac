import AppKit
import Gal4MacCore
import SwiftUI

private enum ImportStep: Int, CaseIterable {
    case source, extract, configure, complete

    var title: String {
        switch self {
        case .source: "选择来源"
        case .extract: "解压文件"
        case .configure: "名称与配置"
        case .complete: "完成导入"
        }
    }

    var symbol: String {
        switch self {
        case .source: "square.and.arrow.down"
        case .extract: "archivebox"
        case .configure: "slider.horizontal.3"
        case .complete: "checkmark"
        }
    }
}

private enum ImportSourceMode: String, CaseIterable {
    case local = "本地文件"
    case online = "下载链接"
}

@MainActor
private final class ImportWizardModel: ObservableObject {
    @Published var step: ImportStep = .source
    @Published var sourceMode: ImportSourceMode = .local
    @Published var sourceURL: URL?
    @Published var link = ""
    @Published var password = ""
    @Published var isBusy = false
    @Published var progress = 0.0
    @Published var progressText = ""
    @Published var errorMessage: String?
    @Published var gameDirectory: URL?
    @Published var displayName = ""
    @Published var engine: EngineType = .unknown
    @Published var executableOptions: [String] = []
    @Published var executable = ""
    @Published var locale: WineLocale = .automatic
    @Published var steamQuery = ""
    @Published var steamResults: [SteamSearchResult] = []
    @Published var selectedSteamAppID: Int?
    @Published var isSearchingSteam = false
    @Published var steamSearchMessage: String?
    @Published var importedGame: Game?

    private var downloader: Aria2Downloader?
    private var extractionRoot: URL?
    private var extractionInProgress = false
    private var operationID = UUID()
    private var steamSearchID = UUID()

    var isFolder: Bool {
        guard let sourceURL else { return false }
        return (try? sourceURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    func resetSource() {
        sourceURL = nil
        gameDirectory = nil
        errorMessage = nil
        progress = 0
        progressText = ""
    }

    func chooseLocalSource() {
        let panel = NSOpenPanel()
        panel.message = "选择游戏文件夹，或 zip、rar、7z 压缩包及分卷文件"
        panel.prompt = "选择来源"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        guard isDirectory || ArchiveExtractor().detectFormat(at: url) != .unknown else {
            errorMessage = "请选择游戏文件夹或 zip、rar、7z 压缩包。"
            return
        }
        sourceURL = url
        gameDirectory = nil
        errorMessage = nil
    }

    func download() {
        let input = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: input),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              url.host != nil else {
            errorMessage = "请输入有效的 HTTP 或 HTTPS 下载链接。"
            return
        }
        let filename = url.lastPathComponent
        guard !filename.isEmpty, filename != "/",
              ArchiveExtractor().detectFormat(at: URL(fileURLWithPath: filename)) != .unknown else {
            errorMessage = "链接需要直接指向 zip、rar 或 7z 压缩包。"
            return
        }
        guard Aria2Downloader.isInstalled() else {
            errorMessage = "下载需要 aria2。安装命令：brew install aria2"
            return
        }

        let directory = LibraryManager.configDirectory
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = directory.appendingPathComponent(filename)
        let worker = Aria2Downloader()
        downloader = worker
        isBusy = true
        errorMessage = nil
        progress = 0
        progressText = "正在连接…"
        let token = UUID()
        operationID = token

        do {
            try worker.download(url: input, to: destination, onProgress: { [weak self] update in
                Task { @MainActor [weak self] in
                    guard let self, self.operationID == token else { return }
                    self.progress = update.progress
                    self.progressText = "\(update.downloadedDescription) / \(update.totalDescription) · \(update.speedDescription)"
                }
            }, onComplete: { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self, self.operationID == token else { return }
                    self.isBusy = false
                    self.downloader = nil
                    switch result {
                    case .success(let file):
                        self.sourceURL = file
                        self.progress = 1
                        self.progressText = "下载完成"
                        self.step = .extract
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            })
        } catch {
            isBusy = false
            downloader = nil
            errorMessage = error.localizedDescription
        }
    }

    func advanceFromSource() {
        guard sourceURL != nil else { return }
        errorMessage = nil
        step = .extract
    }

    func extract() {
        guard let sourceURL, !isFolder, !isBusy else { return }
        let destination = LibraryManager.configDirectory
            .appendingPathComponent("Imported", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        extractionRoot = destination
        extractionInProgress = true
        isBusy = true
        errorMessage = nil
        progressText = "正在检查分卷并解压…"
        let secret = password.isEmpty ? nil : password
        let token = UUID()
        operationID = token

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try ArchiveExtractor().extract(archiveURL: sourceURL, to: destination, password: secret) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.extractionInProgress = false
                guard self.operationID == token else {
                    DispatchQueue.global(qos: .utility).async { try? FileManager.default.removeItem(at: destination) }
                    return
                }
                self.isBusy = false
                switch result {
                case .success(let directory):
                    self.gameDirectory = directory
                    self.loadConfiguration(for: directory)
                    self.password = ""
                    self.progressText = "解压完成"
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.extractionRoot = nil
                    DispatchQueue.global(qos: .utility).async { try? FileManager.default.removeItem(at: destination) }
                }
            }
        }
    }

    func advanceFromExtraction() {
        guard let sourceURL else { return }
        if isFolder {
            gameDirectory = sourceURL
            loadConfiguration(for: sourceURL)
        }
        guard gameDirectory != nil else { return }
        errorMessage = nil
        step = .configure
    }

    func importGame(using library: LibraryViewModel) {
        guard let gameDirectory else { return }
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "请输入显示名称。"
            return
        }
        guard !executable.isEmpty else {
            errorMessage = "请选择可执行文件。"
            return
        }
        do {
            importedGame = try library.importGame(
                at: gameDirectory,
                name: displayName,
                engine: engine,
                executable: executable,
                locale: locale,
                steamAppID: selectedSteamAppID
            )
            password = ""
            errorMessage = nil
            step = .complete
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelUnfinished() {
        operationID = UUID()
        steamSearchID = UUID()
        downloader?.cancel()
        downloader = nil
        guard importedGame == nil, !extractionInProgress, let extractionRoot else { return }
        DispatchQueue.global(qos: .utility).async { try? FileManager.default.removeItem(at: extractionRoot) }
        self.extractionRoot = nil
    }

    private func loadConfiguration(for directory: URL) {
        let detector = EngineDetector()
        engine = detector.detect(at: directory)
        executableOptions = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "exe" }
            .map(\.lastPathComponent)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        executable = detector.findExecutable(at: directory, engine: engine) ?? executableOptions.first ?? ""
        if directory == extractionRoot, let sourceURL {
            displayName = sourceURL.deletingPathExtension().lastPathComponent
        } else {
            displayName = directory.lastPathComponent
        }
        steamQuery = displayName
        searchSteam(autoSelect: true)
    }

    func searchSteam(autoSelect: Bool = false) {
        let query = steamQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            steamResults = []
            steamSearchMessage = "输入名称后搜索，或使用自定义游戏。"
            return
        }
        let token = UUID()
        steamSearchID = token
        selectedSteamAppID = nil
        isSearchingSteam = true
        steamSearchMessage = nil
        Task {
            do {
                let results = try await SteamMetadataService.search(query)
                guard steamSearchID == token else { return }
                steamResults = results
                if autoSelect, let first = results.first, first.score >= 0.9 {
                    selectedSteamAppID = first.id
                }
                steamSearchMessage = results.isEmpty ? "Steam 未找到匹配结果；可以继续以自定义游戏导入。" : nil
            } catch {
                guard steamSearchID == token else { return }
                steamSearchMessage = "无法连接 Steam；可以继续以自定义游戏导入。"
            }
            if steamSearchID == token { isSearchingSteam = false }
        }
    }
}

struct ImportWizardView: View {
    @EnvironmentObject private var library: LibraryViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ImportWizardModel()
    let onComplete: (Game) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("导入游戏").font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("选择来源，配置运行方式，然后加入游戏库。")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button { close() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("关闭导入向导")
                    .disabled(model.isBusy)
            }
            .padding(.bottom, 28)

            HStack(spacing: 8) {
                ForEach(ImportStep.allCases, id: \.rawValue) { step in
                    HStack(spacing: 7) {
                        Image(systemName: model.step.rawValue > step.rawValue ? "checkmark.circle.fill" : "\(step.rawValue + 1).circle.fill")
                            .foregroundStyle(model.step.rawValue >= step.rawValue ? GlassPalette.blue : GlassPalette.secondary)
                        Text(step.title)
                            .foregroundStyle(model.step == step ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .font(.callout.weight(model.step == step ? .semibold : .regular))
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.bottom, 18)
            Divider()

            Group {
                switch model.step {
                case .source: sourceStep
                case .extract: extractionStep
                case .configure: configurationStep
                case .complete: completionStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 26)

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 14)
            }

            Divider()
            HStack {
                if model.step != .source && model.step != .complete {
                    Button("上一步") {
                        model.errorMessage = nil
                        model.step = ImportStep(rawValue: model.step.rawValue - 1) ?? .source
                    }
                    .disabled(model.isBusy)
                }
                Spacer()
                Button(model.step == .complete ? "完成" : "取消") { close() }
                    .disabled(model.isBusy)
                if model.step != .complete { primaryAction }
            }
            .padding(.top, 18)
        }
        .padding(28)
        .frame(width: 680, height: 530)
        .background(GlassPalette.background)
        .tint(GlassPalette.blue)
        .interactiveDismissDisabled(model.isBusy)
        .onDisappear { model.cancelUnfinished() }
    }

    private var sourceStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("游戏从哪里来？", description: "选择本地游戏文件夹或压缩包，也可以粘贴直链下载。")
            Picker("来源", selection: $model.sourceMode) {
                ForEach(ImportSourceMode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: model.sourceMode) { _, _ in model.resetSource() }

            if model.sourceMode == .local {
                Button { model.chooseLocalSource() } label: {
                    Label("选择文件或文件夹…", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                if let source = model.sourceURL { sourceCard(source) }
            } else {
                TextField("https://example.com/game.zip", text: $model.link)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("压缩包下载链接")
                HStack {
                    Button("开始下载") { model.download() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isBusy || model.link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("支持 HTTP / HTTPS 压缩包直链")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if model.isBusy {
                    ProgressView(value: model.progress)
                    Text(model.progressText).font(.caption).foregroundStyle(.secondary)
                }
                if let source = model.sourceURL { sourceCard(source) }
            }
        }
    }

    private var extractionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("准备游戏文件", description: model.isFolder
                           ? "已选择游戏文件夹，无需解压，可以直接继续。"
                           : "解压前会检查常见分卷是否完整；源压缩包会保留。")
            if let source = model.sourceURL { sourceCard(source) }
            if !model.isFolder {
                VStack(alignment: .leading, spacing: 8) {
                    Text("解压密码（可选）").font(.callout.weight(.medium))
                    SecureField("如压缩包已加密，请输入密码", text: $model.password)
                        .textFieldStyle(.roundedBorder)
                        .disabled(model.isBusy || model.gameDirectory != nil)
                }
                if model.isBusy {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(model.progressText).foregroundStyle(.secondary)
                    }
                } else if let gameDirectory = model.gameDirectory {
                    Label("已找到游戏目录：\(gameDirectory.lastPathComponent)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("开始解压") { model.extract() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var configurationStep: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            sectionHeading("名称与运行配置", description: "确认游戏在库中的名称、启动程序和 Windows 语言环境。")
            VStack(alignment: .leading, spacing: 10) {
                Text("游戏身份").font(.callout.weight(.semibold))
                Text("自动匹配 Steam 游戏，也可以搜索选择或保留自定义。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("搜索 Steam 游戏名称", text: $model.steamQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { model.searchSteam() }
                    Button("搜索") { model.searchSteam() }
                        .disabled(model.isSearchingSteam)
                }
                if model.isSearchingSteam { ProgressView("正在匹配 Steam 游戏…").controlSize(.small) }
                if let message = model.steamSearchMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Picker("匹配结果", selection: $model.selectedSteamAppID) {
                    Text("自定义游戏 · 不关联 Steam").tag(Int?.none)
                    ForEach(model.steamResults) { result in
                        Text("\(result.name) · AppID \(result.id)").tag(Optional(result.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                if let selected = model.steamResults.first(where: { $0.id == model.selectedSteamAppID }) {
                    Text("已关联：\(selected.name)。介绍、背景和云存档将使用这个 AppID。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(15)
            .background(GlassPalette.surface, in: RoundedRectangle(cornerRadius: 12))
            VStack(spacing: 16) {
                LabeledContent("显示名称") {
                    TextField("游戏名称", text: $model.displayName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 400)
                }
                LabeledContent("运行引擎") {
                    Picker("运行引擎", selection: $model.engine) {
                        ForEach(EngineType.allCases, id: \.self) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 400)
                }
                LabeledContent("可执行文件") {
                    Picker("可执行文件", selection: $model.executable) {
                        if model.executableOptions.isEmpty { Text("未找到 .exe 文件").tag("") }
                        ForEach(model.executableOptions, id: \.self) { name in Text(name).tag(name) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 400)
                }
                LabeledContent("Windows 语言") {
                    Picker("Windows 语言", selection: $model.locale) {
                        Text("自动").tag(WineLocale.automatic)
                        Text("简体中文").tag(WineLocale.simplifiedChinese)
                        Text("日语").tag(WineLocale.japanese)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 400)
                }
            }
            .font(.callout)
            if model.engine == .unknown {
                Label("未识别游戏引擎。你可以手动选择，或保留 Unknown 尝试通用配置。", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
          }
        }
    }

    private var completionStep: some View {
        VStack(alignment: .center, spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
            Text("已加入游戏库").font(.title2.weight(.semibold))
            Text(model.importedGame?.name ?? "")
                .font(.title3)
            Text("现在可以在左侧游戏列表中找到并启动它。")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var primaryAction: some View {
        switch model.step {
        case .source:
            Button("继续") { model.advanceFromSource() }
                .buttonStyle(.borderedProminent)
                .disabled(model.sourceURL == nil || model.isBusy)
        case .extract:
            Button("继续") { model.advanceFromExtraction() }
                .buttonStyle(.borderedProminent)
                .disabled(model.isBusy || (!model.isFolder && model.gameDirectory == nil))
        case .configure:
            Button("加入游戏库") { model.importGame(using: library) }
                .buttonStyle(.borderedProminent)
                .disabled(model.executable.isEmpty || model.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        case .complete:
            EmptyView()
        }
    }

    private func sectionHeading(_ title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.title3.weight(.semibold))
            Text(description).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func sourceCard(_ url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: model.isFolder ? "folder.fill" : "archivebox.fill")
                .foregroundStyle(GlassPalette.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text(url.lastPathComponent).font(.callout.weight(.medium))
                Text(url.path).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
        }
        .padding(14)
        .background(GlassPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func close() {
        model.cancelUnfinished()
        if let game = model.importedGame { onComplete(game) }
        dismiss()
    }
}
