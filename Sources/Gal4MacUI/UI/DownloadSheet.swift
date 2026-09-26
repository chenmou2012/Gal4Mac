import SwiftUI
import Gal4MacCore

/// 下载并导入游戏弹窗
/// 集成 aria2 多线程下载 + 自动解压 + 引擎检测
struct DownloadSheet: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss

    @State private var urlString: String = ""
    @State private var isDownloading = false
    @State private var isCancelling = false
    @State private var progressMessage: String = ""
    @State private var progress: Double = 0
    @State private var speedMessage: String = ""
    @State private var downloadAndExtract = DownloadAndExtract()

    private let aria2Installed = Aria2Downloader.isInstalled()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                GalSheetHeader(
                    title: "下载游戏",
                    subtitle: "输入游戏压缩包链接。下载完成后会自动解压并添加到游戏库。",
                    symbol: "arrow.down.circle"
                )
                Spacer(minLength: 0)
                if !aria2Installed {
                    Label("aria2 未安装", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .fixedSize()
                } else {
                    Label("aria2 就绪", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .fixedSize()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("下载链接")
                    .font(.subheadline.weight(.semibold))
                TextField("https://example.com/game.zip", text: $urlString)
                    .textFieldStyle(.plain)
                    .disabled(isDownloading)
                    .padding(12)
                    .galSheetCard()
            }

            // 进度显示
            if isDownloading || !progressMessage.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text(progressMessage)
                            .font(.caption)
                        Spacer()
                        Text(speedMessage)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(13)
                .galSheetCard()
            }

            if !aria2Installed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("aria2 是多线程下载工具，能大幅加速 galgame 压缩包下载。")
                        .font(.caption)
                    Text("安装命令：")
                        .font(.caption.bold())
                    Text("brew install aria2")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .galSheetCard(cornerRadius: 7)
                }
                .padding(12)
                .galSheetCard()
            }

            Spacer()

            HStack {
                if isDownloading {
                    Button(isCancelling ? "正在取消…" : "取消下载") {
                        isCancelling = true
                        downloadAndExtract.cancel()
                    }
                    .disabled(isCancelling)
                } else {
                    Button("取消") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                Spacer()
                Button(isDownloading ? "下载中…" : "开始下载") {
                    startDownload()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(urlString.isEmpty || isDownloading || !aria2Installed)
            }
        }
        .padding(24)
        .frame(width: 600)
        .frame(minHeight: 380, alignment: .topLeading)
    }

    private func startDownload() {
        let url = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        isDownloading = true
        isCancelling = false
        progress = 0
        progressMessage = "准备下载..."
        speedMessage = ""

        // 解压目标目录
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let extractDir = appSupport
            .appendingPathComponent("Gal4Mac/Extracted", isDirectory: true)
            .appendingPathComponent(urlFilenameWithoutExt(url))

        downloadAndExtract.downloadAndExtract(
            url: url,
            to: extractDir,
            onProgress: { msg in
                progressMessage = msg
                if let pct = extractPercent(msg) {
                    progress = pct
                }
            },
            onComplete: { result in
                isDownloading = false
                if isCancelling {
                    isCancelling = false
                    progressMessage = "已取消"
                    return
                }
                switch result {
                case .success(let gameDir):
                    progress = 1.0
                    progressMessage = "✓ 完成"
                    library.addGame(at: gameDir)
                    dismiss()
                case .failure(let error):
                    progressMessage = "❌ \(error.localizedDescription)"
                }
            }
        )
    }

    private func urlFilenameWithoutExt(_ url: String) -> String {
        guard let parsed = URL(string: url) else { return "game" }
        var name = parsed.lastPathComponent
        if let dot = name.lastIndex(of: ".") {
            name = String(name[..<dot])
        }
        return name.isEmpty ? "game" : name
    }

    private func extractPercent(_ msg: String) -> Double? {
        // 匹配 "下载中 45.2%"
        let pattern = #"(\d+\.?\d*)%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = msg as NSString
        if let match = regex.firstMatch(in: msg, range: NSRange(location: 0, length: nsString.length)),
           match.numberOfRanges >= 2 {
            return Double(nsString.substring(with: match.range(at: 1)))! / 100.0
        }
        return nil
    }
}
