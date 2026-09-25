import Foundation

/// 引擎特定的 Wine 优化配置
///
/// 针对每个 galgame 引擎的最佳 Wine 配置：
/// - 注册表键值
/// - DLL 覆盖
/// - 环境变量
/// - DirectX 配置
public struct EngineOptimizer {

    public struct WineConfig {
        /// 注册表键值对
        public var registryEntries: [(String, String, String)]  // (path, name, value)
        /// DLL 覆盖（格式: "dll=n,b"）
        public var dllOverrides: [String]
        /// 环境变量
        public var environmentVariables: [(String, String)]
        /// DirectX 渲染后端（win, d3d9, d3d11）
        public var dxBackend: DXBackend

        public enum DXBackend: String {
            case automatic
            case directDraw = "ddraw"
            case d3d9
            case d3d11
            case gdi
        }

        public init(
            registryEntries: [(String, String, String)] = [],
            dllOverrides: [String] = [],
            environmentVariables: [(String, String)] = [],
            dxBackend: DXBackend = .automatic
        ) {
            self.registryEntries = registryEntries
            self.dllOverrides = dllOverrides
            self.environmentVariables = environmentVariables
            self.dxBackend = dxBackend
        }
    }

    /// 获取引擎的最佳配置
    public static func config(for engine: EngineType) -> WineConfig {
        switch engine {
        case .kirikiri:
            return kirikiriConfig()
        case .siglus:
            return siglusConfig()
        case .unity:
            return unityConfig()
        case .tyranoScript:
            return tyranoConfig()
        case .renpy:
            return renpyConfig()
        case .realLive, .nscripter:
            return oldEngineConfig()
        default:
            return WineConfig()
        }
    }

    /// KiriKiri/KAG 引擎优化
    /// - 主要问题: 中文/日文显示、DirectSound 缓冲
    private static func kirikiriConfig() -> WineConfig {
        WineConfig(
            registryEntries: [
                // DirectSound 优化（已知杂音问题的解决）
                ("HKCU\\Software\\Wine\\DirectSound", "HardwareAcceleration", "Emulation"),
                ("HKCU\\Software\\Wine\\DirectSound", "DefaultSampleRate", "48000"),
                ("HKCU\\Software\\Wine\\DirectSound", "DefaultBitsPerSample", "16"),
                // 日文/Japanese locale
                ("HKCU\\Software\\Wine\\Locale", "Locale", "ja_JP.UTF-8"),
                // 字体替换（用 macOS 系统字体）
                ("HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes",
                 "MS Gothic", "Hiragino Sans GB"),
                ("HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes",
                 "MS Mincho", "Songti"),
                // 显示性能
                ("HKCU\\Software\\Wine\\Direct3D", "DirectDrawRenderer", "opengl"),
            ],
            dllOverrides: [
                // KiriKiri2 通常使用 d3d9
            ],
            environmentVariables: [
                ("LANG", "ja_JP.UTF-8"),
                ("LC_ALL", "ja_JP.UTF-8")
            ],
            dxBackend: .d3d9
        )
    }

    /// SiglusEngine 优化
    /// - 主要问题: 中文显示（已内置）、音频杂音
    private static func siglusConfig() -> WineConfig {
        WineConfig(
            registryEntries: [
                // DirectSound 优化（CLANNAD 等游戏必备）
                ("HKCU\\Software\\Wine\\DirectSound", "HardwareAcceleration", "Emulation"),
                ("HKCU\\Software\\Wine\\DirectSound", "DefaultSampleRate", "48000"),
                ("HKCU\\Software\\Wine\\DirectSound", "DefaultBitsPerSample", "16"),
                ("HKCU\\Software\\Wine\\DirectSound", "MaxShadowSize", "0"),
                // 字体优化
                ("HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes",
                 "MS Gothic", "Hiragino Sans GB"),
            ],
            dllOverrides: [],
            environmentVariables: [
                ("PULSE_LATENCY_MSEC", "120")
            ],
            dxBackend: .d3d9
        )
    }

    /// Unity galgame 优化
    /// - 主要问题: DX11 性能、视频解码
    private static func unityConfig() -> WineConfig {
        WineConfig(
            registryEntries: [
                ("HKCU\\Software\\Wine\\DirectSound", "HardwareAcceleration", "Emulation"),
                ("HKCU\\Software\\Wine\\DirectSound", "DefaultSampleRate", "48000"),
                ("HKCU\\Software\\Wine\\Direct3D", "DirectDrawRenderer", "opengl"),
                // Unity 高分辨率支持
                ("HKCU\\Software\\Wine\\Direct3D", "RenderTargetModeLockEnabled", "0"),
            ],
            dllOverrides: [],
            environmentVariables: [],
            dxBackend: .d3d11
        )
    }

    /// TyranoScript 优化
    /// - 基于 NW.js 的浏览器引擎
    private static func tyranoConfig() -> WineConfig {
        WineConfig(
            registryEntries: [
                ("HKCU\\Software\\Wine\\DirectSound", "HardwareAcceleration", "Emulation"),
                ("HKCU\\Software\\Wine\\DirectSound", "DefaultSampleRate", "48000"),
            ],
            dllOverrides: [],
            environmentVariables: [],
            dxBackend: .automatic
        )
    }

    /// Ren'Py 优化
    /// - Ren'Py 通常有原生 Mac 版，但用 Wine 跑 Windows 版也可
    private static func renpyConfig() -> WineConfig {
        WineConfig(
            registryEntries: [
                ("HKCU\\Software\\Wine\\DirectSound", "HardwareAcceleration", "Emulation"),
            ],
            dllOverrides: [],
            environmentVariables: [],
            dxBackend: .automatic
        )
    }

    /// 老引擎 (RealLive/NScripter) 优化
    /// - 通常使用 DirectDraw，较为简单
    private static func oldEngineConfig() -> WineConfig {
        WineConfig(
            registryEntries: [
                ("HKCU\\Software\\Wine\\DirectDraw", "Render", "GDI"),
                ("HKCU\\Software\\Wine\\Direct3D", "DirectDrawRenderer", "gdi"),
            ],
            dllOverrides: [
                // 强制使用 GDI 渲染（兼容性最好）
                "ddraw=g"
            ],
            environmentVariables: [],
            dxBackend: .gdi
        )
    }
}

/// 应用引擎优化到 Wine prefix
public final class EngineConfigurator {

    public init() {}

    /// 应用所有引擎的优化到指定的 Wine prefix
    public func applyOptimizations(for engine: EngineType, prefix: URL) throws {
        let config = EngineOptimizer.config(for: engine)
        try applyRegistry(config.registryEntries, prefix: prefix)
        // DLL overrides 和 env vars 在 launch 时设置
    }

    private func applyRegistry(_ entries: [(String, String, String)], prefix: URL) throws {
        for (key, name, value) in entries {
            try runWineReg(prefix: prefix, args: [
                "add", key, "/v", name, "/t", "REG_SZ", "/d", value, "/f"
            ])
        }
    }

    private func runWineReg(prefix: URL, args: [String]) throws {
        let process = Process()
        process.executableURL = EngineManager.wineExecutable
        process.arguments = ["reg"] + args
        process.environment = EngineManager.launchEnvironment(prefix: prefix)
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "Gal4Mac.EngineConfigurator",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Wine 注册表更新失败（退出码 \(process.terminationStatus)）"]
            )
        }
    }
}
