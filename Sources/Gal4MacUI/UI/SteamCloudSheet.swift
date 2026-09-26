import AppKit
import SwiftUI
import WebKit
import Gal4MacCore

/// 在 Steam 官方云存档页面登录并接收用户点击下载的文件。
struct SteamCloudSheet: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var targetDirectory: URL?
    @State private var downloads: [PendingSteamDownload] = []
    @State private var steamAppID = ""
    @State private var pageURL = URL(string: "https://store.steampowered.com/account/remotestorage")!
    @State private var isImporting = false
    @State private var message: String?

    init(game: Game) {
        self.game = game
        _targetDirectory = State(initialValue: SaveManager().suggestedImportDirectory(for: game))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                GalSheetHeader(
                    title: "Steam 云存档",
                    subtitle: "登录 Steam 官方页面，下载后确认文件名和存档位置。",
                    symbol: "icloud.and.arrow.down"
                )
                Spacer(minLength: 0)
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 10) {
                TextField("Steam AppID", text: $steamAppID, prompt: Text("例如 888790"))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)
                Button("打开云存档") {
                    pageURL = URL(string: "https://store.steampowered.com/account/remotestorageapp/?appid=\(steamAppID)")!
                }
                .buttonStyle(.borderedProminent)
                .disabled(steamAppID.isEmpty || !steamAppID.allSatisfy(\.isNumber))
                Button("查找已同步文件", action: scanClientSaves)
                    .disabled(steamAppID.isEmpty || !steamAppID.allSatisfy(\.isNumber))
            }
            .padding(12)
            .galSheetCard()

            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("存档目标文件夹")
                        .font(.caption.weight(.semibold))
                    Text(targetDirectory?.path ?? "尚未选择游戏存档目录")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button("选择…", action: chooseTargetDirectory)
            }
            .padding(11)
            .galSheetCard()

            if !downloads.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("待导入文件（\(downloads.count)）", systemImage: "tray.and.arrow.down")
                        .font(.subheadline.weight(.semibold))
                    ForEach($downloads) { $download in
                        HStack(spacing: 9) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(download.sourceLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                TextField("导入后的文件名", text: $download.filename)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Spacer(minLength: 0)
                            Button("导入") { importDownload(download) }
                                .buttonStyle(.borderedProminent)
                                .disabled(targetDirectory == nil || isImporting)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .padding(12)
                .galSheetCard()
            }

            if let message {
                Label(message, systemImage: message.contains("失败") ? "exclamationmark.triangle" : "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(message.contains("失败") ? .orange : .secondary)
                    .lineLimit(2)
            }

            SteamRemoteStorageWebView(
                pageURL: pageURL,
                onDownloaded: { url, filename in
                    downloads.append(PendingSteamDownload(url: url, filename: filename, sourceLabel: "网页下载", removeAfterImport: true))
                    message = "已下载 \(filename)，请选择导入位置并确认文件名。"
                },
                onError: { error in message = "下载失败：\(error)" }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .padding(20)
        .frame(width: 940, height: 760)
        .onDisappear {
            for download in downloads where download.removeAfterImport {
                try? FileManager.default.removeItem(at: download.url)
            }
        }
    }

    private func scanClientSaves() {
        let files = SteamClientSaves().files(appID: steamAppID)
        downloads.removeAll { !$0.removeAfterImport }
        downloads += files.map {
            PendingSteamDownload(url: $0.url, filename: $0.url.lastPathComponent,
                                 sourceLabel: "Steam \($0.account): \($0.relativePath)", removeAfterImport: false)
        }
        message = files.isEmpty
            ? "客户端尚未同步 AppID \(steamAppID) 的存档。请先在 Steam 安装并启动该游戏，或使用下方网页下载。"
            : "找到 \(files.count) 个客户端已同步文件。请选择文件导入。"
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
}

private struct PendingSteamDownload: Identifiable {
    let id = UUID()
    let url: URL
    var filename: String
    let sourceLabel: String
    let removeAfterImport: Bool
}

private struct SteamRemoteStorageWebView: NSViewRepresentable {
    let pageURL: URL
    let onDownloaded: (URL, String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(requestedURL: pageURL, onDownloaded: onDownloaded, onError: onError)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: pageURL))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.requestedURL != pageURL {
            context.coordinator.requestedURL = pageURL
            webView.load(URLRequest(url: pageURL))
        }
        context.coordinator.onDownloaded = onDownloaded
        context.coordinator.onError = onError
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        var requestedURL: URL
        var onDownloaded: (URL, String) -> Void
        var onError: (String) -> Void
        private var destinations: [ObjectIdentifier: (URL, String)] = [:]

        init(requestedURL: URL, onDownloaded: @escaping (URL, String) -> Void, onError: @escaping (String) -> Void) {
            self.requestedURL = requestedURL
            self.onDownloaded = onDownloaded
            self.onError = onError
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            let attachment = (navigationResponse.response as? HTTPURLResponse)?
                .value(forHTTPHeaderField: "Content-Disposition")?
                .localizedCaseInsensitiveContains("attachment") == true
            decisionHandler(attachment || !navigationResponse.canShowMIMEType ? .download : .allow)
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
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
                destinations[ObjectIdentifier(download)] = (destination, filename)
                completionHandler(destination)
            } catch {
                onError(error.localizedDescription)
                completionHandler(nil)
            }
        }

        func downloadDidFinish(_ download: WKDownload) {
            guard let (url, filename) = destinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
            onDownloaded(url, filename)
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            if let (url, _) = destinations.removeValue(forKey: ObjectIdentifier(download)) {
                try? FileManager.default.removeItem(at: url)
            }
            onError(error.localizedDescription)
        }
    }
}
