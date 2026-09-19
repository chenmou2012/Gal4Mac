import Foundation

/// Galgame 游戏信息
public struct Game: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var path: URL
    public var executable: String
    public var engine: EngineType
    public var launchArgs: [String]
    public var detectedAt: Date
    public var lastPlayed: Date?
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        path: URL,
        executable: String,
        engine: EngineType,
        launchArgs: [String] = [],
        detectedAt: Date = Date(),
        lastPlayed: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.executable = executable
        self.engine = engine
        self.launchArgs = launchArgs
        self.detectedAt = detectedAt
        self.lastPlayed = lastPlayed
        self.notes = notes
    }

    /// 可执行文件的完整路径
    public var executablePath: URL {
        path.appendingPathComponent(executable)
    }

    /// 大小（人类可读）
    public var sizeDescription: String {
        let size = directorySize(at: path)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey],
            options: []
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey]),
               let size = attrs.totalFileAllocatedSize {
                total += Int64(size)
            }
        }
        return total
    }
}
