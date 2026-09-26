import AppKit
import SwiftUI
import WebKit
import Gal4MacCore

/// 只为已匹配且归当前 Steam 账户所有的游戏下载云存档。
struct SteamCloudSheet: View {
    let game: Game
    let appID: Int
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var steamSession = SteamWebSession.shared
    @State private var targetDirectory: URL?
    @State private var downloads: [PendingSteamDownload] = []
    @State private var isImporting = false
    @State private var batchImportCompleted = 0
    @State private var batchImportTotal = 0
    @State private var isPreparing = false
    @State private var isDownloading = false
    @State private var completedCount = 0
    @State private var totalCount = 0
    @State private var failedCount = 0
    @State private var message: String?
    @State private var webSessionID = UUID()
    @State private var isVisible = false

    init(game: Game, appID: Int) {
        self.game = game
        self.appID = appID
        _targetDirectory = State(initialValue: SaveManager().suggestedImportDirectory(for: game))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Steam 云存档")
                        .font(.title2.bold())
                    Text("\(game.name) · AppID \(appID)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭") { dismiss() }
            }

            Text("自动下载当前 Steam 账户拥有的这款游戏的云端文件。下载后，请确认文件名和导入位置。")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Text("导入到：")
                Text(targetDirectory?.path ?? "尚未选择游戏存档目录")
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("选择目录…", action: chooseTargetDirectory)
            }
            .padding(12)
            .mythicPanel(cornerRadius: 10)

            if isPreparing {
                ProgressView("正在识别云端文件…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if isDownloading {
                VStack(alignment: .leading, spacing: 7) {
                    Text("正在下载 \(completedCount) / \(totalCount)")
                        .font(.callout.weight(.medium))
                    ProgressView(value: Double(completedCount), total: Double(max(totalCount, 1)))
                        .tint(MythicTheme.accent)
                }
            } else if isImporting {
                ProgressView("正在导入 \(batchImportCompleted) / \(batchImportTotal)")
                    .tint(MythicTheme.accent)
            }

            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if downloads.isEmpty && !isPreparing && !isDownloading {
                ContentUnavailableView(
                    "没有待导入的文件",
                    systemImage: "icloud.and.arrow.down",
                    description: Text("云端没有存档文件，或下载尚未完成。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 9) {
                        ForEach($downloads) { $download in
                            HStack(spacing: 10) {
                                Image(systemName: "doc")
                                    .foregroundStyle(MythicTheme.accentLight)
                                TextField("导入后的文件名", text: $download.filename)
                                    .textFieldStyle(.roundedBorder)
                                Button("导入") { importDownload(download) }
                                    .disabled(targetDirectory == nil || isImporting || isPreparing || isDownloading)
                            }
                            .padding(11)
                            .mythicPanel(cornerRadius: 10)
                        }
                    }
                }
            }

            HStack {
                if !downloads.isEmpty {
                    Button("一键导入全部（\(downloads.count)）", action: importAllDownloads)
                        .buttonStyle(.borderedProminent)
                        .disabled(targetDirectory == nil || isImporting || isPreparing || isDownloading)
                }
                if !isPreparing && !isDownloading && totalCount > 0 {
                    Button("重新检查并下载", action: startAutoDownload)
                        .disabled(isImporting)
                }
                Spacer()
                Text("已下载 \(downloads.count) 个文件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 720, height: 550)
        .background(MythicTheme.background)
        .tint(MythicTheme.accent)
        .onAppear {
            isVisible = true
            startAutoDownload()
        }
        .onDisappear {
            isVisible = false
            steamSession.release(ownerID: webSessionID)
            for download in downloads where download.removeAfterImport {
                try? FileManager.default.removeItem(at: download.url)
            }
        }
        .onChange(of: steamSession.authentication) { _, authentication in
            if authentication == .signedOut { dismiss() }
        }
    }

    private func startAutoDownload() {
        guard !isPreparing && !isDownloading else { return }
        for download in downloads where download.removeAfterImport {
            try? FileManager.default.removeItem(at: download.url)
        }
        downloads.removeAll()
        completedCount = 0
        totalCount = 0
        isPreparing = true
        message = nil
        failedCount = 0
        Task { @MainActor in
            do {
                let owned = try await steamSession.ownsGame(appID: appID)
                guard isVisible else { return }
                guard owned else {
                    message = "当前 Steam 账户的游戏库中没有这款游戏。"
                    isPreparing = false
                    return
                }
                let files = try await steamSession.cloudFiles(appID: appID)
                guard isVisible else { return }
                isPreparing = false
                guard !files.isEmpty else {
                    message = "这款游戏没有可下载的 Steam 云端文件。"
                    return
                }
                isDownloading = true
                steamSession.downloadCloudFiles(
                    files, ownerID: webSessionID,
                    onDownloaded: { url, filename in
                        guard isVisible else {
                            try? FileManager.default.removeItem(at: url)
                            return
                        }
                        downloads.append(PendingSteamDownload(url: url, filename: filename, sourceLabel: "Steam 云端", removeAfterImport: true))
                    },
                    onError: { error in
                        guard isVisible else { return }
                        failedCount += 1
                        message = "部分文件下载失败：\(error)"
                    },
                    onProgress: { completed, total in
                        guard isVisible else { return }
                        completedCount = completed
                        totalCount = total
                    },
                    onComplete: {
                        guard isVisible else { return }
                        isDownloading = false
                        message = failedCount == 0
                            ? "已下载 \(downloads.count) 个文件，请确认后导入。"
                            : "已下载 \(downloads.count) 个文件，\(failedCount) 个文件失败。"
                    }
                )
            } catch {
                guard isVisible else { return }
                isPreparing = false
                message = error.localizedDescription
            }
        }
    }

    private func chooseTargetDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择存档目录"
        panel.message = "请选择 \(game.name) 实际读取存档的目录"
        panel.directoryURL = targetDirectory ?? game.path
        if panel.runModal() == .OK {
            targetDirectory = panel.url
        }
    }

    private func importDownload(_ download: PendingSteamDownload) {
        guard let targetDirectory else { return }
        isImporting = true
        let filename = download.filename.trimmingCharacters(in: .whitespacesAndNewlines)
        Task.detached {
            do {
                let result = try SteamCloudImporter().importFile(
                    from: download.url,
                    named: filename,
                    into: targetDirectory
                )
                await MainActor.run {
                    downloads.removeAll { $0.id == download.id }
                    if download.removeAfterImport { try? FileManager.default.removeItem(at: download.url) }
                    message = result.backup == nil
                        ? "已导入 \(result.destination.lastPathComponent)"
                        : "已导入 \(result.destination.lastPathComponent)；原文件备份于 \(result.backup!.path)"
                    isImporting = false
                }
            } catch {
                await MainActor.run {
                    message = "导入失败：\(error.localizedDescription)"
                    isImporting = false
                }
            }
        }
    }

    private func importAllDownloads() {
        guard let targetDirectory, !downloads.isEmpty, !isImporting else { return }
        let filenames = downloads.map { $0.filename.lowercased() }
        guard Set(filenames).count == filenames.count else {
            message = "云端有重名文件，暂不能批量导入，请逐个检查并导入。"
            return
        }

        let pending = downloads
        isImporting = true
        batchImportCompleted = 0
        batchImportTotal = pending.count
        message = nil
        Task.detached {
            let importer = SteamCloudImporter()
            var importedIDs = Set<UUID>()
            var failures: [String] = []
            var backupCount = 0

            for download in pending {
                do {
                    let filename = download.filename.trimmingCharacters(in: .whitespacesAndNewlines)
                    let result = try importer.importFile(from: download.url, named: filename, into: targetDirectory)
                    importedIDs.insert(download.id)
                    if result.backup != nil { backupCount += 1 }
                } catch {
                    failures.append("\(download.filename)：\(error.localizedDescription)")
                }
                await MainActor.run { batchImportCompleted += 1 }
            }

            let completedIDs = importedIDs
            let failureMessages = failures
            let completedBackupCount = backupCount
            await MainActor.run {
                let imported = pending.filter { completedIDs.contains($0.id) }
                downloads.removeAll { completedIDs.contains($0.id) }
                for download in imported where download.removeAfterImport {
                    try? FileManager.default.removeItem(at: download.url)
                }
                if failureMessages.isEmpty {
                    message = completedBackupCount == 0
                        ? "已一键导入全部 \(imported.count) 个文件。"
                        : "已一键导入全部 \(imported.count) 个文件；\(completedBackupCount) 个同名本地文件已备份。"
                } else {
                    message = "已导入 \(imported.count) 个文件，\(failureMessages.count) 个失败。失败文件仍保留在列表中。\n\(failureMessages.joined(separator: "\n"))"
                }
                isImporting = false
            }
        }
    }
}

private struct PendingSteamDownload: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    var filename: String
    let sourceLabel: String
    let removeAfterImport: Bool
}

struct SteamRemoteStorageWebView: NSViewRepresentable {
    let ownerID: UUID
    let pageURL: URL
    let onDownloaded: (URL, String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> SteamWebSession {
        SteamWebSession.shared
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let webView = SteamWebSession.shared.webView
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
        SteamWebSession.shared.activate(ownerID: ownerID, pageURL: pageURL, onDownloaded: onDownloaded, onError: onError)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        let webView = SteamWebSession.shared.webView
        if webView.superview !== container {
            webView.removeFromSuperview()
            webView.frame = container.bounds
            container.addSubview(webView)
        }
        SteamWebSession.shared.activate(ownerID: ownerID, pageURL: pageURL, onDownloaded: onDownloaded, onError: onError)
    }

    static func dismantleNSView(_ container: NSView, coordinator: SteamWebSession) {
        if coordinator.webView.superview === container {
            coordinator.webView.removeFromSuperview()
        }
    }
}

final class SteamWebSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    enum Authentication: Equatable {
        case unknown, checking, signedIn, signedOut, unavailable
    }

    enum CloudError: LocalizedError {
        case notAuthenticated, invalidResponse, changedPage

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "Steam 登录已失效，请到设置中重新登录。"
            case .invalidResponse: return "无法读取 Steam 游戏库或云存档列表。"
            case .changedPage: return "Steam 页面结构已变化，暂时无法自动下载。"
            }
        }
    }

    struct CloudFile {
        let url: URL
        let name: String
    }

    struct CloudGame {
        let appID: Int
        let name: String
    }

    static let shared = SteamWebSession()
    static let accountURL = URL(string: "https://store.steampowered.com/account/remotestorage")!
    @Published private(set) var authentication: Authentication = .unknown

    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.uiDelegate = self
        return view
    }()
    private var ownerID: UUID?
    private var requestedURL: URL?
    private var onDownloaded: (URL, String) -> Void = { url, _ in try? FileManager.default.removeItem(at: url) }
    private var onError: (String) -> Void = { _ in }
    private var destinations: [ObjectIdentifier: (url: URL, filename: String, ownerID: UUID?, autoURL: URL?)] = [:]
    private var authCompletion: ((Bool) -> Void)?
    private var autoQueue: [CloudFile] = []
    private var autoCurrent: CloudFile?
    private var autoDownloadStarted = false
    private var autoOwnerID: UUID?
    private var autoTotal = 0
    private var autoFinished = 0
    private var autoProgress: ((Int, Int) -> Void)?
    private var autoCompletion: (() -> Void)?

    func ownsGame(appID: Int) async throws -> Bool {
        guard authentication == .signedIn, webView.url?.host == "store.steampowered.com" else {
            throw CloudError.notAuthenticated
        }
        let script = """
            const response = await fetch('/dynamicstore/userdata/?v=1', { credentials: 'same-origin', cache: 'no-store' });
            if (!response.ok) throw new Error('Steam library unavailable');
            const data = await response.json();
            if (!Array.isArray(data.rgOwnedApps)) throw new Error('Steam library missing');
            return data.rgOwnedApps.some(value => Number(value) === appid);
            """
        let result = try await webView.callAsyncJavaScript(
            script, arguments: ["appid": appID], in: nil, contentWorld: .page
        )
        guard let owned = result as? Bool else { throw CloudError.invalidResponse }
        return owned
    }

    func cloudGames() async throws -> [CloudGame] {
        guard authentication == .signedIn, webView.url?.host == "store.steampowered.com" else {
            throw CloudError.notAuthenticated
        }
        let script = """
            const response = await fetch('/account/remotestorage/', { credentials: 'same-origin', cache: 'no-store' });
            if (!response.ok || new URL(response.url).pathname.startsWith('/login')) throw new Error('Steam login required');
            const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
            if (!doc.querySelector('#main_content')) throw new Error('Steam cloud page changed');
            return Array.from(doc.querySelectorAll('a[href*="/account/remotestorageapp/"]')).map(link => {
                const url = new URL(link.href, location.origin);
                const row = link.closest('tr');
                const appid = Number(url.searchParams.get('appid'));
                const name = (row?.querySelector('td')?.textContent || '').trim();
                return url.origin === location.origin && Number.isSafeInteger(appid) && appid > 0 && name
                    ? { appid, name } : null;
            }).filter(Boolean);
            """
        let result = try await webView.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .page)
        guard let records = result as? [[String: Any]] else { throw CloudError.invalidResponse }
        return records.compactMap { record in
            guard let appID = record["appid"] as? Int, let name = record["name"] as? String else { return nil }
            return CloudGame(appID: appID, name: name)
        }
    }

    func cloudFiles(appID: Int) async throws -> [CloudFile] {
        guard authentication == .signedIn, webView.url?.host == "store.steampowered.com" else {
            throw CloudError.notAuthenticated
        }
        let script = """
            const files = [];
            for (let index = 0; index < 10000; index += 50) {
                const page = new URL('/account/remotestorageapp/', location.origin);
                page.searchParams.set('appid', String(appid));
                page.searchParams.set('index', String(index));
                const response = await fetch(page.href, { credentials: 'same-origin', cache: 'no-store' });
                if (!response.ok || new URL(response.url).pathname.startsWith('/login')) throw new Error('Steam login required');
                const doc = new DOMParser().parseFromString(await response.text(), 'text/html');
                const rows = Array.from(doc.querySelectorAll('#main_content table tr'));
                if (!doc.querySelector('#main_content')) throw new Error('Steam cloud page changed');
                for (const row of rows) {
                    const cells = Array.from(row.querySelectorAll(':scope > td'));
                    if (cells.length < 5) continue;
                    const link = Array.from(cells[4].querySelectorAll('a[href]')).find(a =>
                        /下载|download/i.test(a.textContent || '') || a.hasAttribute('download'));
                    if (!link) continue;
                    const url = new URL(link.href, location.origin);
                    const fromSteamAccount = url.origin === location.origin && url.pathname.startsWith('/account/');
                    const fromSteamCDN = url.protocol === 'https:' && url.host === 'cdn.steamusercontent.com'
                        && url.pathname.startsWith('/filedownload/');
                    if (!fromSteamAccount && !fromSteamCDN) continue;
                    const name = (cells[1].textContent || '').trim() || 'steam-save';
                    files.push({ url: url.href, name });
                }
                const hasNext = Array.from(doc.querySelectorAll('a[href*="index="]')).some(link => {
                    const next = new URL(link.href, location.origin);
                    return next.searchParams.get('appid') === String(appid) && Number(next.searchParams.get('index')) === index + 50;
                });
                if (!hasNext) {
                    if (rows.length > 1 && !files.length) throw new Error('Steam download links changed');
                    return files;
                }
            }
            throw new Error('Too many Steam cloud pages');
            """
        let result = try await webView.callAsyncJavaScript(
            script, arguments: ["appid": appID], in: nil, contentWorld: .page
        )
        guard let records = result as? [[String: Any]] else { throw CloudError.invalidResponse }
        let files = records.compactMap { record -> CloudFile? in
            guard let rawURL = record["url"] as? String,
                  let url = URL(string: rawURL),
                  url.scheme == "https",
                  (url.host == "store.steampowered.com" && url.path.hasPrefix("/account/")) ||
                  (url.host == "cdn.steamusercontent.com" && url.path.hasPrefix("/filedownload/"))
            else { return nil }
            return CloudFile(url: url, name: record["name"] as? String ?? "steam-save")
        }
        if !records.isEmpty && files.isEmpty { throw CloudError.changedPage }
        return files
    }

    func downloadCloudFiles(
        _ files: [CloudFile], ownerID: UUID,
        onDownloaded: @escaping (URL, String) -> Void,
        onError: @escaping (String) -> Void,
        onProgress: @escaping (Int, Int) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.ownerID = ownerID
        self.onDownloaded = onDownloaded
        self.onError = onError
        autoOwnerID = ownerID
        autoQueue = files
        autoCurrent = nil
        autoTotal = files.count
        autoFinished = 0
        autoProgress = onProgress
        autoCompletion = onComplete
        onProgress(0, files.count)
        startNextAutoDownload()
    }

    private func startNextAutoDownload() {
        guard autoOwnerID == ownerID else { return }
        guard !autoQueue.isEmpty else {
            autoCompletion?()
            autoCompletion = nil
            autoProgress = nil
            autoOwnerID = nil
            return
        }
        let file = autoQueue.removeFirst()
        autoCurrent = file
        autoDownloadStarted = false
        webView.load(URLRequest(url: file.url))
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            guard let self, self.autoCurrent?.url == file.url, self.autoOwnerID == self.ownerID else { return }
            self.finishAutoDownload(error: "下载 \(file.name) 超时")
        }
    }

    private func finishAutoDownload(error: String? = nil) {
        guard autoCurrent != nil else { return }
        if let error { onError(error) }
        autoCurrent = nil
        autoDownloadStarted = false
        autoFinished += 1
        autoProgress?(autoFinished, autoTotal)
        startNextAutoDownload()
    }

    func verifyAuthentication(_ completion: @escaping (Bool) -> Void) {
        authCompletion = completion
        authentication = .checking
        requestedURL = Self.accountURL
        webView.load(URLRequest(url: Self.accountURL))
    }

    func activate(ownerID: UUID, pageURL: URL, onDownloaded: @escaping (URL, String) -> Void, onError: @escaping (String) -> Void) {
        let newOwner = self.ownerID != ownerID
        self.ownerID = ownerID
        self.onDownloaded = onDownloaded
        self.onError = onError
        if newOwner || requestedURL != pageURL {
            requestedURL = pageURL
            webView.load(URLRequest(url: pageURL))
        }
    }

    func release(ownerID: UUID) {
        guard self.ownerID == ownerID else { return }
        self.ownerID = nil
        onDownloaded = { url, _ in try? FileManager.default.removeItem(at: url) }
        onError = { _ in }
        if autoOwnerID == ownerID {
            autoQueue = []
            autoCurrent = nil
            autoOwnerID = nil
            autoProgress = nil
            autoCompletion = nil
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        if autoCurrent?.url == url && !autoDownloadStarted {
            finishAutoDownload(error: "Steam 没有返回可下载的文件")
        }
        if url.host == "store.steampowered.com", url.path.hasPrefix("/account/remotestorage") {
            authentication = .signedIn
            authCompletion?(true)
            authCompletion = nil
        } else if authCompletion != nil || (url.host == "store.steampowered.com" && url.path.hasPrefix("/login")) {
            authentication = .signedOut
            authCompletion?(false)
            authCompletion = nil
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled
            || (nsError.domain == "WebKitErrorDomain" && nsError.code == 102)
            || nsError.localizedDescription.localizedCaseInsensitiveContains("frame load interrupted") {
            return
        }
        if autoCurrent != nil {
            finishAutoDownload(error: error.localizedDescription)
            return
        }
        authentication = .unavailable
        authCompletion?(false)
        authCompletion = nil
        onError(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let responseURL = navigationResponse.response.url
        let isSteamCloudFile = autoCurrent != nil
            && responseURL?.host == "cdn.steamusercontent.com"
            && responseURL?.path.hasPrefix("/filedownload/") == true
        let attachment = (navigationResponse.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?
            .localizedCaseInsensitiveContains("attachment") == true
        decisionHandler(isSteamCloudFile || attachment || !navigationResponse.canShowMIMEType ? .download : .allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        if autoCurrent != nil { autoDownloadStarted = true }
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        if autoCurrent != nil { autoDownloadStarted = true }
        download.delegate = self
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Gal4MacSteamCloud", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = URL(fileURLWithPath: suggestedFilename).lastPathComponent
            let filename = name.isEmpty ? "steam-save" : name
            let destination = directory.appendingPathComponent(UUID().uuidString + "-" + filename)
            destinations[ObjectIdentifier(download)] = (destination, filename, ownerID, autoCurrent?.url)
            completionHandler(destination)
        } catch {
            onError(error.localizedDescription)
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let (url, filename, downloadOwnerID, autoURL) = destinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        if downloadOwnerID == ownerID {
            onDownloaded(url, filename)
            if autoURL == autoCurrent?.url { finishAutoDownload() }
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let (url, _, downloadOwnerID, autoURL) = destinations.removeValue(forKey: ObjectIdentifier(download)) {
            try? FileManager.default.removeItem(at: url)
            if downloadOwnerID == ownerID { onError(error.localizedDescription) }
            if downloadOwnerID == autoOwnerID && autoURL == autoCurrent?.url { finishAutoDownload() }
        }
    }
}
