import Foundation

/// aria2 多线程下载器
///
/// 用于加速 galgame 压缩包下载
public final class Aria2Downloader {

    public enum DownloadError: LocalizedError {
        case aria2NotInstalled
        case alreadyRunning
        case invalidURL
        case failedToStart(String)
        case exitedWithError(Int32)

        public var errorDescription: String? {
            switch self {
            case .aria2NotInstalled:
                return "aria2c 未安装。请运行: brew install aria2"
            case .alreadyRunning:
                return "下载器已在运行"
            case .invalidURL:
                return "无效的下载链接"
            case .failedToStart(let msg):
                return "启动失败: \(msg)"
            case .exitedWithError(let code):
                return "下载失败，退出码 \(code)"
            }
        }
    }

    /// 下载进度信息
    public struct Progress {
        public let downloadedBytes: Int64
        public let totalBytes: Int64
        public let speedBytesPerSec: Int64
        public let progress: Double  // 0.0 ~ 1.0

        public var downloadedDescription: String {
            ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
        }

        public var totalDescription: String {
            ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }

        public var speedDescription: String {
            ByteCountFormatter.string(fromByteCount: speedBytesPerSec, countStyle: .file) + "/s"
        }
    }

    /// aria2 可执行文件路径
    public static var aria2Executable: URL {
        // 按优先级查找
        let candidates = [
            "/opt/homebrew/bin/aria2c",
            "/usr/local/bin/aria2c",
            "/usr/bin/aria2c"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return URL(fileURLWithPath: "/opt/homebrew/bin/aria2c")
    }

    /// 检查 aria2 是否安装
    public static func isInstalled() -> Bool {
        FileManager.default.isExecutableFile(atPath: aria2Executable.path)
    }

    /// 安装指引 URL
    public static let installInstructions = "brew install aria2"

    private var process: Process?
    private var isCancelled = false

    public init() {}

    /// 是否正在下载
    public var isRunning: Bool {
        process?.isRunning ?? false
    }

    /// 下载文件
    /// - Parameters:
    ///   - url: 下载链接（支持 HTTP/HTTPS/FTP/BitTorrent/磁力链接）
    ///   - destination: 保存路径（含文件名）
    ///   - connections: 并发连接数（默认 16）
    ///   - onProgress: 进度回调
    ///   - onComplete: 完成回调
    /// - Returns: AsyncStream<Progress>
    public func download(
        url: String,
        to destination: URL,
        connections: Int = 16,
        onProgress: @escaping (Progress) -> Void = { _ in },
        onComplete: @escaping (Result<URL, Error>) -> Void = { _ in }
    ) throws {
        guard Self.isInstalled() else {
            throw DownloadError.aria2NotInstalled
        }

        guard !isRunning else {
            throw DownloadError.alreadyRunning
        }

        guard let _ = URL(string: url) else {
            throw DownloadError.invalidURL
        }

        isCancelled = false

        // 确保目录存在
        let dir = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = Self.aria2Executable
        process.arguments = [
            url,
            "-d", dir.path,           // 下载目录
            "-o", destination.lastPathComponent,  // 输出文件名
            "-x", String(connections), // 每服务器连接数
            "-s", String(connections), // 分段数
            "-j", String(connections), // 最大并发下载数
            "--summary-interval=1",    // 1秒输出一次进度
            "--console-log-level=warn",
            "-c",                      // 断点续传
            "--check-certificate=false"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 进度解析（aria2 的 stdout 是 key=value 格式）
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            self?.parseProgress(output: str, onProgress: onProgress)
        }

        self.process = process

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                if self?.isCancelled == true {
                    onComplete(.failure(DownloadError.failedToStart("用户取消")))
                } else if proc.terminationStatus == 0 {
                    onComplete(.success(destination))
                } else {
                    onComplete(.failure(DownloadError.exitedWithError(proc.terminationStatus)))
                }
                self?.process = nil
            }
        }

        do {
            try process.run()
        } catch {
            self.process = nil
            throw DownloadError.failedToStart(error.localizedDescription)
        }
    }

    /// 取消下载
    public func cancel() {
        isCancelled = true
        process?.terminate()
    }

    /// 解析 aria2 的输出
    private func parseProgress(output: String, onProgress: @escaping (Progress) -> Void) {
        // aria2 默认输出格式: [#xxxxxx 90MiB/100MiB(90%) CN:16 DL:10MiB ETA:1m]
        // 或者使用 --summary-interval=1 时输出更详细的统计

        let pattern = #"\[#([0-9a-f]+)\s+([\d\.]+)([KMG]iB)?/([\d\.]+)([KMG]iB)?\s+\((\d+)%\)\s+CN:(\d+)\s+DL:([\d\.]+)([KMG]iB)?\s+ETA:(.+?)\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

        let nsString = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if match.numberOfRanges >= 10 {
                let downloadedStr = nsString.substring(with: match.range(at: 2))
                let downloadedUnit = match.range(at: 3).location != NSNotFound
                    ? nsString.substring(with: match.range(at: 3)) : ""
                let totalStr = nsString.substring(with: match.range(at: 4))
                let totalUnit = match.range(at: 5).location != NSNotFound
                    ? nsString.substring(with: match.range(at: 5)) : ""
                let percentStr = nsString.substring(with: match.range(at: 6))
                let speedStr = nsString.substring(with: match.range(at: 8))
                let speedUnit = match.range(at: 9).location != NSNotFound
                    ? nsString.substring(with: match.range(at: 9)) : ""

                let downloaded = parseBytes(downloadedStr, unit: downloadedUnit)
                let total = parseBytes(totalStr, unit: totalUnit)
                let percent = Double(percentStr) ?? 0
                let speed = parseBytes(speedStr, unit: speedUnit)

                let progress = Progress(
                    downloadedBytes: Int64(downloaded),
                    totalBytes: Int64(total),
                    speedBytesPerSec: Int64(speed),
                    progress: percent / 100.0
                )
                DispatchQueue.main.async {
                    onProgress(progress)
                }
            }
        }
    }

    private func parseBytes(_ value: String, unit: String) -> Double {
        let n = Double(value) ?? 0
        switch unit.uppercased() {
        case "KIB": return n * 1024
        case "MIB": return n * 1024 * 1024
        case "GIB": return n * 1024 * 1024 * 1024
        default: return n
        }
    }
}

/// 下载+解压组合
public final class DownloadAndExtract {
    private let downloader = Aria2Downloader()
    private let extractor = ArchiveExtractor()

    public init() {}

    public enum CombinedError: LocalizedError {
        case aria2NotInstalled
        case downloadFailed(String)
        case extractFailed(String)

        public var errorDescription: String? {
            switch self {
            case .aria2NotInstalled:
                return "aria2c 未安装"
            case .downloadFailed(let msg):
                return "下载失败: \(msg)"
            case .extractFailed(let msg):
                return "解压失败: \(msg)"
            }
        }
    }

    /// 下载并自动解压
    /// - Parameters:
    ///   - url: 下载链接
    ///   - destination: 解压目标目录
    ///   - onProgress: 进度回调（下载进度/解压进度）
    ///   - onComplete: 完成回调，返回游戏目录
    public func downloadAndExtract(
        url: String,
        to destination: URL,
        onProgress: @escaping (String) -> Void = { _ in },
        onComplete: @escaping (Result<URL, Error>) -> Void
    ) {
        guard Aria2Downloader.isInstalled() else {
            onComplete(.failure(CombinedError.aria2NotInstalled))
            return
        }

        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let downloadsDir = appSupport
            .appendingPathComponent("Gal4Mac", isDirectory: true)
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)

        // 从 URL 推断文件名
        let filename = urlFilename(url) ?? "download_\(UUID().uuidString.prefix(8))"
        let archivePath = downloadsDir.appendingPathComponent(filename)

        onProgress("开始下载...")

        do {
            try downloader.download(
                url: url,
                to: archivePath,
                onProgress: { progress in
                    onProgress(String(format: "下载中 %.1f%% - %@",
                                      progress.progress * 100,
                                      progress.speedDescription))
                },
                onComplete: { result in
                switch result {
                case .success(let downloadedFile):
                    onProgress("下载完成，正在解压...")

                    // 在后台线程解压
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let gameDir = try self.extractor.extract(
                                archiveURL: downloadedFile,
                                to: destination
                            )
                            // 解压成功后删除压缩包
                            try? FileManager.default.removeItem(at: downloadedFile)

                            DispatchQueue.main.async {
                                onProgress("解压完成")
                                onComplete(.success(gameDir))
                            }
                        } catch {
                            DispatchQueue.main.async {
                                onComplete(.failure(CombinedError.extractFailed(error.localizedDescription)))
                            }
                        }
                    }

                case .failure(let error):
                    onComplete(.failure(CombinedError.downloadFailed(error.localizedDescription)))
                }
            }
            )
        } catch {
            onComplete(.failure(CombinedError.downloadFailed(error.localizedDescription)))
        }
    }

    /// 从 URL 中提取文件名
    private func urlFilename(_ urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        // 优先用 URL 的最后路径段
        var lastPath = url.lastPathComponent
        // 移除查询参数
        if let qIdx = lastPath.firstIndex(of: "?") {
            lastPath = String(lastPath[..<qIdx])
        }
        // 如果没有扩展名或扩展名是 .html 等网页格式，返回 nil
        let ext = (lastPath as NSString).pathExtension.lowercased()
        let validExts = ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"]
        return validExts.contains(ext) ? lastPath : nil
    }
}
