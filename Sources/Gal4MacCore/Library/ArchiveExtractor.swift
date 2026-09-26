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
        case missingVolume(String)

        public var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let f): return "不支持的压缩格式: \(f)"
            case .unzipFailed(let msg): return "解压失败: \(msg)"
            case .noGameFound: return "压缩包内未找到游戏"
            case .readError(let msg): return "读取失败: \(msg)"
            case .missingVolume(let name): return "分卷压缩包不完整，缺少文件: \(name)"
            }
        }
    }

    public init() {}

    /// 检测压缩包格式
    public func detectFormat(at url: URL) -> Format {
        let name = url.lastPathComponent.lowercased()
        if name.range(of: #"\.7z\.\d{3,}$"#, options: .regularExpression) != nil {
            return .sevenZip
        }
        if name.range(of: #"\.zip\.\d{3,}$"#, options: .regularExpression) != nil {
            return .zip
        }
        if name.range(of: #"\.part\d+\.rar$"#, options: .regularExpression) != nil {
            return .rar
        }
        if name.range(of: #"\.r\d{2}$"#, options: .regularExpression) != nil {
            return .rar
        }
        return Format(fileExtension: url.pathExtension)
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

        let firstVolume = try resolveFirstVolume(for: archiveURL)
        try validateVolumes(for: firstVolume)

        // 确保目标目录存在
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        // 选择解压工具
        switch format {
        case .zip:
            try extractZip(archive: firstVolume, to: destination)
        case .rar:
            try extractRar(archive: firstVolume, to: destination)
        case .sevenZip:
            try extract7z(archive: firstVolume, to: destination)
        case .unknown:
            throw ExtractError.unsupportedFormat(archiveURL.pathExtension)
        }

        // 查找解压后的游戏目录
        guard let gameDir = findGameDirectory(in: destination) else {
            throw ExtractError.noGameFound
        }

        return gameDir
    }

    /// 将用户选中的任意分卷定位到第一卷。归档工具需要从首卷启动。
    private func resolveFirstVolume(for url: URL) throws -> URL {
        let name = url.lastPathComponent
        if let match = name.range(of: #"\.part\d+\.rar$"#, options: [.regularExpression, .caseInsensitive]) {
            let partSuffix = String(name[match])
            let digits = String(partSuffix.dropFirst(".part".count).dropLast(".rar".count))
            let prefix = String(name[..<match.lowerBound])
            let firstSuffix = ".part\(String(repeating: "0", count: max(0, digits.count - 1)))1.rar"
            let first = url.deletingLastPathComponent().appendingPathComponent(prefix + firstSuffix)
            guard FileManager.default.fileExists(atPath: first.path) else {
                throw ExtractError.missingVolume(first.lastPathComponent)
            }
            return first
        }

        if name.range(of: #"\.r\d{2}$"#, options: [.regularExpression, .caseInsensitive]) != nil {
            let base = String(name.dropLast(3))
            let first = url.deletingLastPathComponent().appendingPathComponent("\(base).rar")
            guard FileManager.default.fileExists(atPath: first.path) else {
                throw ExtractError.missingVolume(first.lastPathComponent)
            }
            return first
        }

        if let match = name.range(of: #"\.(\d{3,})$"#, options: .regularExpression),
           Int(name[match].dropFirst()) != nil {
            let suffix = String(name[match])
            guard let baseRange = name.range(of: #"\.\d{3,}$"#, options: .regularExpression) else { return url }
            let baseName = String(name[..<baseRange.lowerBound])
            let first = url.deletingLastPathComponent().appendingPathComponent("\(baseName).\(String(repeating: "0", count: max(0, suffix.count - 1)))1")
            guard FileManager.default.fileExists(atPath: first.path) else {
                throw ExtractError.missingVolume(first.lastPathComponent)
            }
            return first
        }

        return url
    }

    /// 检查常见的连续分卷命名，避免将不完整压缩包交给解压工具后只得到模糊错误。
    private func validateVolumes(for first: URL) throws {
        let name = first.lastPathComponent
        let directory = first.deletingLastPathComponent()
        let fm = FileManager.default

        if let match = name.range(of: #"\.part0*1\.rar$"#, options: [.regularExpression, .caseInsensitive]) {
            let prefix = String(name[..<match.lowerBound])
            let padded = String(name[match]).contains("part0")
            var index = 1
            while true {
                let partNumber = padded ? String(format: "%02d", index) : String(index)
                let volume = directory.appendingPathComponent("\(prefix).part\(partNumber).rar")
                if !fm.fileExists(atPath: volume.path) {
                    if index == 1 { throw ExtractError.missingVolume(volume.lastPathComponent) }
                    let siblings = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
                    let laterPartExists = siblings.contains { sibling in
                        let lower = sibling.lowercased()
                        guard lower.hasPrefix("\(prefix.lowercased()).part"),
                              lower.hasSuffix(".rar"),
                              let range = lower.range(of: #"\.part(\d+)\.rar$"#, options: .regularExpression),
                              let laterNumber = Int(lower[range].dropFirst(".part".count).dropLast(".rar".count)) else {
                            return false
                        }
                        return laterNumber > index
                    }
                    if laterPartExists { throw ExtractError.missingVolume(volume.lastPathComponent) }
                    break
                }
                index += 1
            }
        } else if let match = name.range(of: #"\.(\d{3,})$"#, options: .regularExpression) {
            let suffix = String(name[match].dropFirst())
            let base = String(name[..<match.lowerBound])
            let width = suffix.count
            var index = 1
            while true {
                let numbered = String(format: "%0*d", width, index)
                let volume = directory.appendingPathComponent("\(base).\(numbered)")
                if !fm.fileExists(atPath: volume.path) {
                    if index == 1 { throw ExtractError.missingVolume(volume.lastPathComponent) }
                    // A gap followed by later volumes indicates an incomplete set.
                    if let siblings = try? fm.contentsOfDirectory(atPath: directory.path),
                       siblings.contains(where: { $0.hasPrefix("\(base).") && $0 > volume.lastPathComponent }) {
                        throw ExtractError.missingVolume(volume.lastPathComponent)
                    }
                    break
                }
                index += 1
            }
        } else if name.lowercased().hasSuffix(".rar") {
            let base = String(name.dropLast(4))
            var index = 0
            while true {
                let volume = directory.appendingPathComponent(String(format: "%@.r%02d", base, index))
                if !fm.fileExists(atPath: volume.path) {
                    if index == 0 { break }
                    let siblings = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
                    if siblings.contains(where: { $0.hasPrefix("\(base).r") && $0 > volume.lastPathComponent }) {
                        throw ExtractError.missingVolume(volume.lastPathComponent)
                    }
                    break
                }
                index += 1
            }
        }
    }

    // MARK: - 解压实现

    private func extractZip(archive: URL, to destination: URL) throws {
        // 7-Zip handles split ZIP volumes such as game.zip.001 when installed.
        if archive.lastPathComponent.lowercased().range(of: #"\.zip\.\d{3,}$"#, options: .regularExpression) != nil {
            if let tool = ["/opt/homebrew/bin/7z", "/usr/local/bin/7z"].first(where: FileManager.default.isExecutableFile(atPath:)) {
                try runUnzipToolWithoutCheck(tool: tool, args: ["x", "-y", "-o\(destination.path)", archive.path])
                return
            }
            throw ExtractError.unsupportedFormat("分卷 ZIP 需要安装 7z: brew install p7zip")
        }
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
