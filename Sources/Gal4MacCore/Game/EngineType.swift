import Foundation

/// Galgame 引擎类型
///
/// 通过文件特征识别不同galgame引擎，每种引擎有不同的启动参数和兼容性处理
public enum EngineType: String, Codable, CaseIterable, Sendable {
    /// Unity (32-bit 或 64-bit Windows)
    case unity = "Unity"

    /// SiglusEngine (Key社等使用)
    case siglus = "SiglusEngine"

    /// KiriKiri/KAG (主流galgame引擎，覆盖60%市场)
    case kirikiri = "KiriKiri"

    /// TyranoScript (浏览器引擎)
    case tyranoScript = "TyranoScript"

    /// Ren'Py (跨平台，有原生Mac版)
    case renpy = "Ren'Py"

    /// RealLive (Leaf社老引擎)
    case realLive = "RealLive"

    /// NScripter / ONScripter (老引擎)
    case nscripter = "NScripter"

    /// YU-RIS 引擎
    case yuris = "YU-RIS"

    /// Artemis (月姬重制版等)
    case artemis = "Artemis"

    /// 未知/不支持的引擎
    case unknown = "Unknown"

    /// 引擎的人类可读描述
    public var displayName: String {
        switch self {
        case .unity: return "Unity"
        case .siglus: return "SiglusEngine"
        case .kirikiri: return "KiriKiri / KAG"
        case .tyranoScript: return "TyranoScript"
        case .renpy: return "Ren'Py"
        case .realLive: return "RealLive"
        case .nscripter: return "NScripter / ONScripter"
        case .yuris: return "YU-RIS"
        case .artemis: return "Artemis"
        case .unknown: return "Unknown"
        }
    }

    /// 引擎在 Apple Silicon 上的兼容度（基于 Mythic Engine 测试结果）
    public var compatibility: Compatibility {
        switch self {
        case .unity, .siglus: return .excellent
        case .kirikiri, .tyranoScript: return .good
        case .renpy: return .native  // Ren'Py 通常有原生Mac版
        case .realLive, .nscripter: return .experimental
        case .yuris, .artemis: return .experimental
        case .unknown: return .unsupported
        }
    }

    /// 默认启动参数（窗口模式）
    public func defaultLaunchArgs(width: Int = 1280, height: Int = 720) -> [String] {
        switch self {
        case .unity:
            return [
                "-screen-fullscreen", "0",
                "-screen-width", String(width),
                "-screen-height", String(height),
                "-screen-quality", "beautiful"
            ]
        case .siglus:
            return [
                "-window",
                "-width", String(width),
                "-height", String(height)
            ]
        case .kirikiri:
            // KiriKiri 默认参数
            return [
                "-window",
                "-width", String(width),
                "-height", String(height)
            ]
        case .tyranoScript:
            return []  // TyranoScript 通常无参数或用浏览器
        case .renpy:
            return []  // Ren'Py 原生
        default:
            return []
        }
    }
}

public enum Compatibility: String {
    case excellent = "Excellent"
    case good = "Good"
    case native = "Native"
    case experimental = "Experimental"
    case unsupported = "Unsupported"

    public var emoji: String {
        switch self {
        case .excellent: return "🟢"
        case .good: return "🟡"
        case .native: return "✨"
        case .experimental: return "🟠"
        case .unsupported: return "🔴"
        }
    }
}
