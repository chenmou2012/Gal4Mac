import Foundation

/// Mythic Engine 管理器
///
/// 封装对 Apple Game Porting Toolkit（通过 Mythic Engine 打包）的调用
/// 提供路径管理、版本检测、prefix 管理等功能
public final class EngineManager {

    /// Mythic Engine 的文件系统根目录
    public static let engineDirectory: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("Mythic")
            .appendingPathComponent("Engine")
    }()

    /// wine64 二进制路径
    public static var wineExecutable: URL {
        engineDirectory.appendingPathComponent("wine/bin/wine64")
    }

    /// wineserver 二进制路径
    public static var wineServer: URL {
        engineDirectory.appendingPathComponent("wine/bin/wineserver")
    }

    /// wine 库目录
    public static var wineLibDirectory: URL {
        engineDirectory.appendingPathComponent("wine/lib")
    }

    /// DXVK 目录
    public static var dxvkDirectory: URL {
        engineDirectory.appendingPathComponent("DXVK")
    }

    /// winetricks 脚本
    public static var winetricks: URL {
        engineDirectory.appendingPathComponent("winetricks")
    }

    /// Mythic Container (Wine prefix) 根目录
    public static var containersDirectory: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("Mythic")
            .appendingPathComponent("Containers")
    }()

    /// Engine Properties.plist（包含版本信息）
    public static var propertiesFile: URL {
        engineDirectory.appendingPathComponent("Properties.plist")
    }

    /// 初始化错误
    public enum EngineError: LocalizedError {
        case engineNotInstalled
        case wineBinaryMissing
        case propertiesCorrupted
        case versionTooOld(String)

        public var errorDescription: String? {
            switch self {
            case .engineNotInstalled:
                return "Mythic Engine 未安装。请先运行 `brew install --cask mythic` 并启动 Mythic 让其下载 Engine。"
            case .wineBinaryMissing:
                return "Wine 二进制不存在：\(wineExecutable.path)"
            case .propertiesCorrupted:
                return "Engine Properties.plist 已损坏"
            case .versionTooOld(let required):
                return "Mythic Engine 版本过低，需要 \(required)"
            }
        }
    }

    /// 当前 Engine 版本
    public struct Version: Equatable, Comparable {
        public let major: Int
        public let minor: Int
        public let patch: Int
        public let build: Int

        public var string: String {
            "\(major).\(minor).\(patch).\(build)"
        }

        public static let minimum: Version = .init(major: 2, minor: 6, patch: 0, build: 0)

        public static func < (lhs: Version, rhs: Version) -> Bool {
            if lhs.major != rhs.major { return lhs.major < rhs.major }
            if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
            if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
            return lhs.build < rhs.build
        }
    }

    private init() {}

    /// 检查 Engine 是否已安装
    public static func isInstalled() -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: wineExecutable.path) &&
               fm.fileExists(atPath: propertiesFile.path)
    }

    /// 获取当前 Engine 版本
    public static func currentVersion() -> Version? {
        guard let data = try? Data(contentsOf: propertiesFile) else { return nil }
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any] else { return nil }

        guard let version = plist["version"] as? [String: Any] else { return nil }

        return Version(
            major: version["major"] as? Int ?? 0,
            minor: version["minor"] as? Int ?? 0,
            patch: version["patch"] as? Int ?? 0,
            build: Int(version["build"] as? String ?? "0") ?? 0
        )
    }

    /// 检查 Engine 状态
    public static func validate() throws {
        guard isInstalled() else {
            throw EngineError.engineNotInstalled
        }

        guard FileManager.default.fileExists(atPath: wineExecutable.path) else {
            throw EngineError.wineBinaryMissing
        }

        guard let version = currentVersion() else {
            throw EngineError.propertiesCorrupted
        }

        if version < Version.minimum {
            throw EngineError.versionTooOld("\(Version.minimum.string)+")
        }
    }

    /// 获取指定游戏的 Wine prefix 路径
    public static func winePrefix(for gameName: String) -> URL {
        containersDirectory.appendingPathComponent(gameName)
    }

    /// 音频配置选项
    public struct AudioConfig {
        /// 音频缓冲区延迟（毫秒），用于消除杂音。常用值：60, 120, 200
        public var latencyMs: Int?

        /// 强制使用的音频驱动：coreaudio (macOS默认), oss, alsa
        public var driver: String?

        /// 是否禁用硬件音频加速（解决严重杂音）
        public var disableHardwareAcceleration: Bool

        /// SDL 音频驱动
        public var sdlDriver: String?

        public init(
            latencyMs: Int? = nil,
            driver: String? = nil,
            disableHardwareAcceleration: Bool = false,
            sdlDriver: String? = nil
        ) {
            self.latencyMs = latencyMs
            self.driver = driver
            self.disableHardwareAcceleration = disableHardwareAcceleration
            self.sdlDriver = sdlDriver
        }

        /// 默认音频配置（保守，适合大多数游戏）
        public static let conservative = AudioConfig(
            latencyMs: 60,
            disableHardwareAcceleration: false
        )

        /// 高质量音频配置（适合音乐为主的游戏）
        public static let highQuality = AudioConfig(
            latencyMs: 120,
            disableHardwareAcceleration: true
        )
    }

    /// 启动 Engine 的环境变量
    public static func launchEnvironment(
        prefix: URL,
        audio: AudioConfig = AudioConfig()
    ) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefix.path
        env["WINESERVER"] = wineServer.path
        env["DYLD_FALLBACK_LIBRARY_PATH"] = wineLibDirectory.path
        env["DXVK_ASYNC"] = "1"
        env["WINEDEBUG"] = "-all"  // 减少日志噪音

        // 音频优化环境变量
        if let latency = audio.latencyMs {
            env["PULSE_LATENCY_MSEC"] = String(latency)
        }
        if let driver = audio.driver {
            env["SDL_AUDIODRIVER"] = driver
        }
        if let sdl = audio.sdlDriver {
            env["SDL_AUDIODRIVER"] = sdl
        }
        // 注意：不要设置 WINEDLLOVERRIDES="dsound=n,b" 或 "dsound=b"
        // 这会破坏DirectSound，导致无声音
        // 改用注册表方式：HKCU\Software\Wine\DirectSound\HardwareAcceleration=Emulation

        return env
    }

    /// 自动应用 DirectSound 优化到 Wine prefix
    /// 这是解决杂音的真正有效方法（基于Mythic Engine + Wine 7.7测试）
    public static func applyAudioOptimizations(prefix: URL) throws {
        guard FileManager.default.fileExists(atPath: prefix.path) else {
            return  // prefix还不存在，跳过
        }

        let regCommands = [
            ("HKCU\\Software\\Wine\\DirectSound", "HardwareAcceleration", "Emulation"),
            ("HKCU\\Software\\Wine\\DirectSound", "DefaultSampleRate", "48000"),
            ("HKCU\\Software\\Wine\\DirectSound", "DefaultBitsPerSample", "16")
        ]

        let env = ProcessInfo.processInfo.environment
        var processEnv = env
        processEnv["WINEPREFIX"] = prefix.path
        processEnv["WINESERVER"] = wineServer.path
        processEnv["DYLD_FALLBACK_LIBRARY_PATH"] = wineLibDirectory.path

        for (key, name, value) in regCommands {
            let p = Process()
            p.executableURL = wineExecutable
            p.arguments = ["reg", "add", key, "/v", name, "/t", "REG_SZ", "/d", value, "/f"]
            p.environment = processEnv
            try p.run()
            p.waitUntilExit()
        }
    }

    /// 执行 wine 命令
    @discardableResult
    public static func runWine(
        prefix: URL,
        executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        captureOutput: Bool = false,
        audio: AudioConfig = AudioConfig()
    ) throws -> Int32 {
        try validate()

        let process = Process()
        process.executableURL = wineExecutable
        process.arguments = [executable] + arguments
        process.environment = launchEnvironment(prefix: prefix, audio: audio)

        if let workDir = workingDirectory {
            process.currentDirectoryURL = workDir
        }

        if captureOutput {
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
        }

        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
