import AppKit
import SwiftUI
import WebKit

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
        self.ownerID = ownerID
        self.onDownloaded = onDownloaded
        self.onError = onError
        if requestedURL != pageURL || webView.url == nil {
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
            let cloudName = autoCurrent?.name.replacingOccurrences(of: "\\", with: "/")
                .split(separator: "/").last.map(String.init)
            let importedName = cloudName.flatMap { $0.isEmpty ? nil : $0 } ?? filename
            let destination = directory.appendingPathComponent(UUID().uuidString + "-" + filename)
            destinations[ObjectIdentifier(download)] = (destination, importedName, ownerID, autoCurrent?.url)
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
