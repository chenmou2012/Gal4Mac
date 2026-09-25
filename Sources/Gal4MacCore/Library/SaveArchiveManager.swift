import Foundation

/// 将一个存档目录打包，并在导入时保留原有目录结构和可恢复的备份。
public final class SaveArchiveManager {
    public enum ArchiveError: LocalizedError {
        case noFiles
        case invalidArchive
        case archiveChanged
        case invalidTarget(String)
        case dittoFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noFiles: return "存档目录或压缩包中没有可导入的文件"
            case .invalidArchive: return "压缩包结构不受支持，或包含符号链接等非普通文件"
            case .archiveChanged: return "压缩包在确认后发生变化，请重新选择"
            case .invalidTarget(let path): return "目标位置不是普通文件：\(path)"
            case .dittoFailed(let detail): return "ZIP 处理失败：\(detail)"
            }
        }
    }

    public struct ImportPreview: Identifiable {
        public let id = UUID()
        public let archiveURL: URL
        public let targetDirectory: URL
        public let files: [String]
        public let overwrittenFiles: [String]
    }

    public struct ImportResult {
        public let fileCount: Int
        public let backupDirectory: URL?
    }

    private let backupRoot: URL
    private let fm = FileManager.default

    public init(backupRoot: URL = LibraryManager.configDirectory.appendingPathComponent("SaveBackups", isDirectory: true)) {
        self.backupRoot = backupRoot
    }

    public func export(directory: URL, to zipURL: URL) throws {
        let files = try regularFiles(in: directory)
        guard !files.isEmpty else { throw ArchiveError.noFiles }

        let staging = makeTemporaryDirectory()
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        try fm.copyItem(at: directory, to: staging.appendingPathComponent("files", isDirectory: true))
        try Data("Gal4MacSaveArchive/1".utf8).write(to: staging.appendingPathComponent("format.txt"))
        try runDitto(["-c", "-k", staging.path, zipURL.path])
    }

    public func preview(zipURL: URL, targetDirectory: URL) throws -> ImportPreview {
        let extracted = try extract(zipURL)
        defer { try? fm.removeItem(at: extracted) }
        let source = try sourceDirectory(in: extracted)
        let files = try regularFiles(in: source)
        guard !files.isEmpty else { throw ArchiveError.noFiles }

        var overwritten: [String] = []
        for path in files {
            try validateDestination(path, in: targetDirectory)
            if fm.fileExists(atPath: targetDirectory.appendingPathComponent(path).path) {
                overwritten.append(path)
            }
        }
        return ImportPreview(archiveURL: zipURL, targetDirectory: targetDirectory,
                             files: files, overwrittenFiles: overwritten)
    }

    public func importSaves(_ preview: ImportPreview) throws -> ImportResult {
        let extracted = try extract(preview.archiveURL)
        defer { try? fm.removeItem(at: extracted) }
        let source = try sourceDirectory(in: extracted)
        let files = try regularFiles(in: source)
        guard files == preview.files else { throw ArchiveError.archiveChanged }

        let target = preview.targetDirectory
        for path in files { try validateDestination(path, in: target) }
        try fm.createDirectory(at: target, withIntermediateDirectories: true)

        let stage = target.appendingPathComponent(".gal4mac-stage-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: stage) }
        for path in files {
            let staged = stage.appendingPathComponent(path)
            try fm.createDirectory(at: staged.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: source.appendingPathComponent(path), to: staged)
        }

        let overwritten = files.filter { fm.fileExists(atPath: target.appendingPathComponent($0).path) }
        let backup = overwritten.isEmpty ? nil : backupRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        if let backup {
            for path in overwritten {
                let saved = backup.appendingPathComponent(path)
                try fm.createDirectory(at: saved.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: target.appendingPathComponent(path), to: saved)
            }
        }

        var touched: [String] = []
        do {
            for path in files {
                let destination = target.appendingPathComponent(path)
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                touched.append(path)
                if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
                try fm.moveItem(at: stage.appendingPathComponent(path), to: destination)
            }
        } catch {
            for path in touched.reversed() {
                let destination = target.appendingPathComponent(path)
                try? fm.removeItem(at: destination)
                if let backup {
                    let saved = backup.appendingPathComponent(path)
                    if fm.fileExists(atPath: saved.path) { try? fm.copyItem(at: saved, to: destination) }
                }
            }
            throw error
        }
        return ImportResult(fileCount: files.count, backupDirectory: backup)
    }

    private func extract(_ zipURL: URL) throws -> URL {
        let extracted = makeTemporaryDirectory()
        try fm.createDirectory(at: extracted, withIntermediateDirectories: true)
        do {
            try runDitto(["-x", "-k", zipURL.path, extracted.path])
            return extracted
        } catch {
            try? fm.removeItem(at: extracted)
            throw error
        }
    }

    private func sourceDirectory(in extracted: URL) throws -> URL {
        let top = try fm.contentsOfDirectory(at: extracted, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { $0.lastPathComponent != "__MACOSX" && $0.lastPathComponent != ".DS_Store" }
        let roots = [extracted] + top.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        for root in roots {
            let files = root.appendingPathComponent("files", isDirectory: true)
            if fm.fileExists(atPath: root.appendingPathComponent("format.txt").path),
               (try? files.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { return files }
        }
        for root in roots {
            let children = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])
            let legacy = children.filter { $0.lastPathComponent.hasPrefix("save_0_") }
            if legacy.count == 1,
               (try? legacy[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { return legacy[0] }
        }
        if top.count == 1,
           (try? top[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true { return top[0] }
        return extracted
    }

    private func regularFiles(in directory: URL) throws -> [String] {
        guard let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]) else {
            throw ArchiveError.noFiles
        }
        let prefix = directory.resolvingSymlinksInPath().path + "/"
        var files: [String] = []
        while let item = enumerator.nextObject() as? URL {
            let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { throw ArchiveError.invalidArchive }
            let resolved = item.resolvingSymlinksInPath().path
            guard resolved.hasPrefix(prefix) else { throw ArchiveError.invalidArchive }
            let relative = String(resolved.dropFirst(prefix.count))
            if relative == ".DS_Store" || relative.hasPrefix("__MACOSX/") { continue }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else { throw ArchiveError.invalidArchive }
            files.append(relative)
        }
        return files.sorted()
    }

    private func validateDestination(_ path: String, in target: URL) throws {
        var current = target
        for component in path.split(separator: "/") {
            current.appendPathComponent(String(component))
            guard fm.fileExists(atPath: current.path) else { continue }
            let values = try current.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
            if values.isSymbolicLink == true { throw ArchiveError.invalidTarget(current.path) }
            let isLeaf = current == target.appendingPathComponent(path)
            if isLeaf ? values.isRegularFile != true : values.isDirectory != true {
                throw ArchiveError.invalidTarget(current.path)
            }
        }
    }

    private func runDitto(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = arguments
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "ditto 退出码 \(process.terminationStatus)"
            throw ArchiveError.dittoFailed(detail)
        }
    }

    private func makeTemporaryDirectory() -> URL {
        fm.temporaryDirectory.appendingPathComponent("Gal4MacSave-\(UUID().uuidString)", isDirectory: true)
    }
}
