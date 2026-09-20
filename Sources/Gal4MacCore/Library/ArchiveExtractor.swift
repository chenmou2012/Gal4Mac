import Foundation

/// 压缩包自动解压
///
/// 支持格式：zip、rar、7z
/// 自动检测压缩包内的游戏目录并解压到目标位置
public final class ArchiveExtractor {

    public enum Format: String {
        case zip, rar, sevenZip, unknown

        public init(fileExtension ext: String) {
            switch ext.lowercased() {
            case "zip": self = .zip
            case "rar": self = .rar
            case "7z": self = .sevenZip
            default: self = .unknown
            }
        }
    }

    public enum ExtractError: LocalizedError {
        case unsupportedFormat(String)
        case unzipFailed(String)
        case noGameFound
        case readError(String)

        public var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let f): return "不支持的压缩格式: \(f)"
            case .unzipFailed(let msg): return "解压失败: \(msg)"
            case .noGameFound: return "压缩包内未找到游戏"
            case .readError(let msg): return "读取失败: \(msg)"
            }
        }
    }

    public init() {}

    /// 检测压缩包格式
    public func detectFormat(at url: URL) -> Format {
        Format(fileExtension: url.pathExtension)
    }

    /// 解压到指定目录
    /// - Parameters:
    ///   - archiveURL: 压缩包路径
    ///   - destination: 解压目标目录（不存在则创建）
    /// - Returns: 解压出的游戏目录路径
    public func extract(archiveURL: URL, to destination: URL) throws -> URL {
        let format = detectFormat(at: archiveURL)
        guard format != .unknown else {
            throw ExtractError.unsupportedFormat(archiveURL.pathExtension)
        }

        // 确保目标目录存在
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        // 选择解压工具
        switch format {
        case .zip:
            try extractZip(archive: archiveURL, to: destination)
        case .rar:
            try extractRar(archive: archiveURL, to: destination)
        case .sevenZip:
            try extract7z(archive: archiveURL, to: destination)
        case .unknown:
            throw ExtractError.unsupportedFormat(archiveURL.pathExtension)
        }

        // 查找解压后的游戏目录
        guard let gameDir = findGameDirectory(in: destination) else {
            throw ExtractError.noGameFound
        }

        return gameDir
    }

    // MARK: - 解压实现

    private func extractZip(archive: URL, to destination: URL) throws {
        // 优先用系统 ditto（更快）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, destination.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            // 失败则尝试 unzip
            try runUnzipToolWithoutCheck(tool: "/usr/bin/unzip",
                                         args: ["-o", archive.path, "-d", destination.path])
        }
    }

    private func extractRar(archive: URL, to destination: URL) throws {
        // 按顺序尝试 unar 在常见路径
        let candidates = [
            "/opt/homebrew/bin/unar",
            "/usr/local/bin/unar",
            "/usr/bin/unar"
        ]
        var lastError: Error?
        for tool in candidates {
            if FileManager.default.isExecutableFile(atPath: tool) {
                do {
                    try runUnzipToolWithoutCheck(
                        tool: tool,
                        args: ["-o", "-d", destination.path, archive.path]
                    )
                    return
                } catch {
                    lastError = error
                }
            }
        }
        throw lastError ?? ExtractError.unsupportedFormat("需要安装 unar")
    }

    private func extract7z(archive: URL, to destination: URL) throws {
        let candidates = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z"]
        for tool in candidates {
            if FileManager.default.isExecutableFile(atPath: tool) {
                try runUnzipToolWithoutCheck(
                    tool: tool,
                    args: ["x", "-y", "-o\(destination.path)", archive.path]
                )
                return
            }
        }
        throw ExtractError.unsupportedFormat("需要安装 7z: brew install p7zip")
    }

    /// 实际执行解压工具
    private func runUnzipToolWithoutCheck(tool: String, args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let err = String(data: data, encoding: .utf8) ?? "unknown"
            throw ExtractError.unzipFailed("\(tool): \(err)")
        }
    }

    // MARK: - 游戏目录查找

    /// 在解压目录中查找游戏根目录
    /// 通常是包含 .exe/.dll/dat 的目录
    private func findGameDirectory(in rootDir: URL) -> URL? {
        let detector = EngineDetector()
        let fm = FileManager.default

        // 1. 检查根目录本身
        if detector.detect(at: rootDir) != .unknown {
            return rootDir
        }

        // 2. 检查所有直接子目录
        guard let contents = try? fm.contentsOfDirectory(
            at: rootDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        // 优先检查顶层目录
        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            // 跳过常见非游戏目录
            let skipDirs: Set<String> = ["__macosx", ".ds_store", "system volume information"]
            if skipDirs.contains(item.lastPathComponent.lowercased()) {
                continue
            }

            // 检查是否是游戏目录
            if detector.detect(at: item) != .unknown {
                return item
            }
        }

        // 3. 递归查找（限制深度）
        for item in contents {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            // 跳过明显不是游戏目录的
            let name = item.lastPathComponent.lowercased()
            if ["commonredist", "redist", "crack", "patch", "update", "_setup", "directx", "vcredist"].contains(name) {
                continue
            }

            if let found = findGameDirectoryRecursive(in: item, depth: 2, detector: detector) {
                return found
            }
        }

        return nil
    }

    private func findGameDirectoryRecursive(
        in dir: URL,
        depth: Int,
        detector: EngineDetector
    ) -> URL? {
        guard depth > 0 else { return nil }
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return nil }

        // 先检查当前目录
        if detector.detect(at: dir) != .unknown {
            return dir
        }

        // 递归
        for item in contents {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir),
                  isDir.boolValue else { continue }
            if let found = findGameDirectoryRecursive(in: item, depth: depth - 1, detector: detector) {
                return found
            }
        }

        return nil
    }
}
