import Foundation

public enum WineLocale: String, Codable, CaseIterable, Sendable {
    case automatic
    case simplifiedChinese
    case japanese

    public var unixLocale: String? {
        switch self {
        case .automatic: return nil
        case .simplifiedChinese: return "zh_CN.UTF-8"
        case .japanese: return "ja_JP.UTF-8"
        }
    }
}

/// Galgame 游戏信息
public struct Game: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var customDisplayName: String?
    public var path: URL
    public var executable: String
    public var engine: EngineType
    public var launchArgs: [String]
    public var detectedAt: Date
    public var lastPlayed: Date?
    public var notes: String
    public private(set) var rating: Int  // 根据引擎兼容性自动计算，1-5 星
    public private(set) var userRated: Bool  // 兼容旧版库文件，始终为 false
    public var playtime: TimeInterval  // 累计游戏时长（秒）
    public var wineLocale: WineLocale

    // 自定义解码，提供向后兼容（旧 JSON 没有新字段时使用默认值）
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.customDisplayName = try? c.decode(String.self, forKey: .customDisplayName)
        self.path = try c.decode(URL.self, forKey: .path)
        self.executable = try c.decode(String.self, forKey: .executable)
        self.engine = try c.decode(EngineType.self, forKey: .engine)
        self.launchArgs = (try? c.decode([String].self, forKey: .launchArgs)) ?? []
        self.detectedAt = (try? c.decode(Date.self, forKey: .detectedAt)) ?? Date()
        self.lastPlayed = try? c.decode(Date.self, forKey: .lastPlayed)
        self.notes = (try? c.decode(String.self, forKey: .notes)) ?? ""
        // Ignore legacy user-edited ratings and restore the system compatibility score.
        self.userRated = false
        self.playtime = (try? c.decode(TimeInterval.self, forKey: .playtime)) ?? 0
        self.wineLocale = (try? c.decode(WineLocale.self, forKey: .wineLocale)) ?? .automatic
        self.rating = Game.defaultRating(for: self.engine)
    }

    public init(
        id: UUID = UUID(),
        name: String,
        customDisplayName: String? = nil,
        path: URL,
        executable: String,
        engine: EngineType,
        launchArgs: [String] = [],
        detectedAt: Date = Date(),
        lastPlayed: Date? = nil,
        notes: String = "",
        playtime: TimeInterval = 0,
        wineLocale: WineLocale = .automatic
    ) {
        self.id = id
        self.name = name
        self.customDisplayName = customDisplayName
        self.path = path
        self.executable = executable
        self.engine = engine
        self.launchArgs = launchArgs
        self.detectedAt = detectedAt
        self.lastPlayed = lastPlayed
        self.notes = notes
        self.userRated = false
        self.playtime = playtime
        self.wineLocale = wineLocale
        self.rating = Game.defaultRating(for: engine)
    }

    /// 根据引擎兼容性给默认评分（1-5）
    public static func defaultRating(for engine: EngineType) -> Int {
        switch engine.compatibility {
        case .excellent: return 5
        case .good: return 4
        case .native: return 5
        case .experimental: return 3
        case .unsupported: return 1
        }
    }

    /// 用于界面展示的名称；没有自定义名称时回退到游戏原名。
    public var displayName: String {
        if let custom = customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return name
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

    /// 游戏时长（人类可读）
    public var playtimeDescription: String {
        Game.formatDuration(playtime)
    }

    /// 格式化时长
    public static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        if total < 60 {
            return "\(total)秒"
        } else if total < 3600 {
            return "\(total / 60)分钟"
        } else if total < 86400 {
            let hours = total / 3600
            let mins = (total % 3600) / 60
            return mins == 0 ? "\(hours)小时" : "\(hours)小时\(mins)分"
        } else {
            let days = total / 86400
            let hours = (total % 86400) / 3600
            return hours == 0 ? "\(days)天" : "\(days)天\(hours)小时"
        }
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
