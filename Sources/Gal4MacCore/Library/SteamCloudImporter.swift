import Foundation

/// 将用户从 Steam 云端下载的文件安装到指定游戏存档目录。
public final class SteamCloudImporter {
    public enum ImportError: LocalizedError {
        case invalidFilename
        case missingDownload
        case invalidTarget

        public var errorDescription: String? {
            switch self {
            case .invalidFilename: return "请输入不含路径分隔符的存档文件名"
            case .missingDownload: return "下载的存档文件不存在"
            case .invalidTarget: return "目标位置不是普通存档文件"
            }
        }
    }

    public struct ImportResult {
        public let destination: URL
        public let backup: URL?
    }

    private let backupRoot: URL
    private let fm = FileManager.default

    public init(backupRoot: URL = LibraryManager.configDirectory.appendingPathComponent("SteamCloudBackups", isDirectory: true)) {
        self.backupRoot = backupRoot
    }

    public func importFile(from download: URL, named filename: String, into directory: URL) throws -> ImportResult {
        guard !filename.isEmpty,
              filename != ".", filename != "..",
              filename == URL(fileURLWithPath: filename).lastPathComponent,
              !filename.contains("/"), !filename.contains("\\") else {
            throw ImportError.invalidFilename
        }
        guard (try? download.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            throw ImportError.missingDownload
        }

        let destination = directory.appendingPathComponent(filename)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: destination.path),
           (try? destination.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) != true {
            throw ImportError.invalidTarget
        }

        let staging = directory.appendingPathComponent(".gal4mac-import-\(UUID().uuidString)")
        try fm.copyItem(at: download, to: staging)
        defer { try? fm.removeItem(at: staging) }

        var backup: URL?
        if fm.fileExists(atPath: destination.path) {
            let saved = backupRoot
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
                .appendingPathComponent(filename)
            try fm.createDirectory(at: saved.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: destination, to: saved)
            backup = saved
        }

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.moveItem(at: staging, to: destination)
        } catch {
            if let backup {
                try? fm.removeItem(at: destination)
                try? fm.copyItem(at: backup, to: destination)
            }
            throw error
        }

        return ImportResult(destination: destination, backup: backup)
    }
}
