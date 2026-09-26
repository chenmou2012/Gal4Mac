import Foundation

/// Mythic Engine 管理器
///
/// 封装对 Apple Game Porting Toolkit（通过 Mythic Engine 打包）的调用
/// 提供路径管理、版本检测、prefix 管理等功能
public final class EngineManager {

    /// Mythic Engine 的文件系统根目录
    public static let engineDirectory: URL = {
        // A packaged app carries its own Engine. The command line tool and
        // development builds continue to use the existing Mythic installation.
        if let resources = Bundle.main.resourceURL {
            let bundled = resources.appendingPathComponent("Engine", isDirectory: true)
            if isEnginePresent(at: bundled) {
                return bundled
            }
        }
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("Mythic")
            .appendingPathComponent("Engine")
    }()

    private static func isEnginePresent(at directory: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: directory.appendingPathComponent("wine/bin/wine64").path)
            && fm.fileExists(atPath: directory.appendingPathComponent("Properties.plist").path)
    }

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

    /// 用户本机提供的原生 DirectSound DLL；应用包不分发 Windows 组件。
    public static var nativeDirectSoundDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Gal4Mac/Audio/DirectSound", isDirectory: true)
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
        case dxvkUnavailable
        case wineServerStopFailed(Int32)
        case invalidNativeDirectSound(String)

        public var errorDescription: String? {
            switch self {
            case .engineNotInstalled:
                return "Mythic Engine 不可用。请使用内置 Engine 的 Gal4Mac.app，或先安装 Mythic Engine。"
            case .wineBinaryMissing:
                return "Wine 二进制不存在：\(wineExecutable.path)"
            case .propertiesCorrupted:
                return "Engine Properties.plist 已损坏"
            case .versionTooOld(let required):
                return "Mythic Engine 版本过低，需要 \(required)"
            case .dxvkUnavailable:
                return "Unity 游戏需要 32 位 DXVK，但 Mythic Engine 中未找到所需文件"
            case .wineServerStopFailed(let status):
                return "停止 Wine 游戏失败（退出码 \(status)）"
            case .invalidNativeDirectSound(let path):
                return "原生 DirectSound DLL 架构不匹配：\(path)"
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
        isEnginePresent(at: engineDirectory)
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
        audio: AudioConfig = AudioConfig(),
        engineConfig: EngineOptimizer.WineConfig? = nil
    ) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["WINEPREFIX"] = prefix.path
        env["WINESERVER"] = wineServer.path
        env["DYLD_FALLBACK_LIBRARY_PATH"] = wineLibDirectory.path
        env["DXVK_ASYNC"] = "1"
        env["WINEDEBUG"] = "-all"  // 减少日志噪音

        // Mythic bundles GStreamer with Wine but does not expose its plugin
        // directory in the process environment. Unity's WindowsVideoMedia
        // otherwise cannot find Wine's byte-stream handlers/codecs.
        let gstreamerPlugins = wineLibDirectory.appendingPathComponent("gstreamer-1.0")
        if FileManager.default.fileExists(atPath: gstreamerPlugins.path) {
            env["GST_PLUGIN_PATH"] = gstreamerPlugins.path
            env["GST_PLUGIN_PATH_1_0"] = gstreamerPlugins.path
            env["GST_PLUGIN_SYSTEM_PATH"] = gstreamerPlugins.path
            env["GST_PLUGIN_SYSTEM_PATH_1_0"] = gstreamerPlugins.path
            env["GST_REGISTRY_FORK"] = "no"
        }

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

        // 应用引擎特定的环境变量
        if let config = engineConfig {
            for (key, value) in config.environmentVariables {
                env[key] = value
            }
            // DLL overrides
            if !config.dllOverrides.isEmpty {
                env["WINEDLLOVERRIDES"] = config.dllOverrides.joined(separator: ";")
            }
        }

        return env
    }

    /// 将本机提供的原生 DirectSound 安装到该游戏容器，保留首次替换前的 DLL。
    /// 缺少对应架构的文件时，Wine 仍可回退到内置 DirectSound。
    public static func installNativeDirectSound(prefix: URL) throws {
        let fm = FileManager.default
        let sources: [(name: String, destination: String, machine: UInt16)] = [
            ("x86", "syswow64", 0x014c),
            ("x64", "system32", 0x8664),
        ]
        for item in sources {
            let source = nativeDirectSoundDirectory.appendingPathComponent(item.name).appendingPathComponent("dsound.dll")
            guard fm.fileExists(atPath: source.path) else { continue }
            let data = try Data(contentsOf: source)
            guard peMachine(of: data) == item.machine else {
                throw EngineError.invalidNativeDirectSound(source.path)
            }

            let destinationDirectory = prefix.appendingPathComponent("drive_c/windows/\(item.destination)", isDirectory: true)
            if !fm.fileExists(atPath: destinationDirectory.path) {
                try runWine(prefix: prefix, executable: "cmd", arguments: ["/c", "exit"])
            }
            let destination = destinationDirectory.appendingPathComponent("dsound.dll")
            let previous = try? Data(contentsOf: destination)
            guard previous != data else { continue }

            if let previous {
                let backupDirectory = nativeDirectSoundDirectory
                    .appendingPathComponent("Backups", isDirectory: true)
                    .appendingPathComponent(prefix.lastPathComponent, isDirectory: true)
                try fm.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
                let backup = backupDirectory.appendingPathComponent("dsound-\(item.destination).dll")
                if !fm.fileExists(atPath: backup.path) {
                    try previous.write(to: backup, options: .atomic)
                }
            }
            try data.write(to: destination, options: .atomic)
        }
    }

    private static func peMachine(of data: Data) -> UInt16? {
        guard data.count >= 0x40, data[0] == 0x4d, data[1] == 0x5a else { return nil }
        let offset = Int(data[0x3c]) | Int(data[0x3d]) << 8 | Int(data[0x3e]) << 16 | Int(data[0x3f]) << 24
        guard offset >= 0, offset + 6 <= data.count,
              data[offset] == 0x50, data[offset + 1] == 0x45,
              data[offset + 2] == 0, data[offset + 3] == 0 else { return nil }
        return UInt16(data[offset + 4]) | UInt16(data[offset + 5]) << 8
    }

    /// 自动应用 DirectSound 优化到 Wine prefix。
    public static func applyAudioOptimizations(
        prefix: URL,
        engineConfig: EngineOptimizer.WineConfig? = nil
    ) throws {
        guard FileManager.default.fileExists(atPath: prefix.path) else {
            return  // prefix还不存在，跳过
        }

        let directSoundKey = "HKCU\\Software\\Wine\\DirectSound"
        func configuredValue(_ name: String, fallback: String) -> String {
            engineConfig?.registryEntries.first {
                $0.0.caseInsensitiveCompare(directSoundKey) == .orderedSame && $0.1 == name
            }?.2 ?? fallback
        }
        let regCommands = [
            (directSoundKey, "HardwareAcceleration", configuredValue("HardwareAcceleration", fallback: "Emulation")),
            (directSoundKey, "DefaultSampleRate", configuredValue("DefaultSampleRate", fallback: "44100")),
            (directSoundKey, "DefaultBitsPerSample", configuredValue("DefaultBitsPerSample", fallback: "16"))
        ]

        let processEnv = launchEnvironment(prefix: prefix, engineConfig: engineConfig)

        for (key, name, value) in regCommands {
            let p = Process()
            p.executableURL = wineExecutable
            p.arguments = ["reg", "add", key, "/v", name, "/t", "REG_SZ", "/d", value, "/f"]
            p.environment = processEnv
            try p.run()
            p.waitUntilExit()
        }
    }

    /// 将 Mythic Engine 自带的 32 位 DXVK 安装到游戏 prefix。
    /// 当前检测到的 Unity galgame 是 32 位进程，应使用 syswow64 中的 Direct3D DLL。
    public static func installDXVK32Bit(prefix: URL) throws {
        let fm = FileManager.default
        let windowsDirectory = prefix.appendingPathComponent("drive_c/windows", isDirectory: true)
        var syswow64IsDirectory: ObjCBool = false
        let syswow64 = windowsDirectory.appendingPathComponent("syswow64", isDirectory: true)
        let system32 = windowsDirectory.appendingPathComponent("system32", isDirectory: true)

        if !fm.fileExists(atPath: syswow64.path, isDirectory: &syswow64IsDirectory) || !syswow64IsDirectory.boolValue {
            // 新 prefix 先用 Wine 内置 cmd 初始化，之后再注入 DXVK。
            try runWine(prefix: prefix, executable: "cmd", arguments: ["/c", "exit"])
        }

        var isDirectory: ObjCBool = false
        let destination = fm.fileExists(atPath: syswow64.path, isDirectory: &isDirectory) && isDirectory.boolValue
            ? syswow64
            : system32
        guard fm.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw EngineError.dxvkUnavailable
        }

        for name in ["d3d11.dll", "dxgi.dll"] {
            let source = dxvkDirectory.appendingPathComponent("x32/\(name)")
            guard let data = try? Data(contentsOf: source), !data.isEmpty else {
                throw EngineError.dxvkUnavailable
            }
            try data.write(to: destination.appendingPathComponent(name), options: .atomic)
        }
    }

    /// 执行 wine 命令（前台运行，等待进程退出）
    @discardableResult
    public static func runWine(
        prefix: URL,
        executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        captureOutput: Bool = false,
        audio: AudioConfig = AudioConfig(),
        engineConfig: EngineOptimizer.WineConfig? = nil
    ) throws -> Int32 {
        try validate()

        let process = Process()
        process.executableURL = wineExecutable
        process.arguments = [executable] + arguments
        process.environment = launchEnvironment(prefix: prefix, audio: audio, engineConfig: engineConfig)

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

    /// 异步启动 wine
    public static func runWineAsync(
        prefix: URL,
        executable: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        audio: AudioConfig = AudioConfig(),
        engineConfig: EngineOptimizer.WineConfig? = nil
    ) throws -> (Process, Date) {
        try validate()

        let process = Process()
        process.executableURL = wineExecutable
        process.arguments = [executable] + arguments
        process.environment = launchEnvironment(prefix: prefix, audio: audio, engineConfig: engineConfig)

        if let workDir = workingDirectory {
            process.currentDirectoryURL = workDir
        }

        let startTime = Date()
        try process.run()
        return (process, startTime)
    }

    /// 通过对应 Wine prefix 的 wineserver 结束游戏进程。
    public static func stopWine(prefix: URL, process gameProcess: Process) throws {
        let stopper = Process()
        stopper.executableURL = wineServer
        stopper.arguments = ["-k"]
        stopper.environment = launchEnvironment(prefix: prefix)

        do {
            try stopper.run()
            stopper.waitUntilExit()
            guard stopper.terminationStatus == 0 else {
                throw EngineError.wineServerStopFailed(stopper.terminationStatus)
            }
            if gameProcess.isRunning {
                gameProcess.terminate()
            }
        } catch {
            // wineserver -k 是首选的整组清理方式；如果它失败，至少结束由
            // Gal4Mac 直接启动的 Wine 进程，并把错误交给界面显示。
            if gameProcess.isRunning {
                gameProcess.terminate()
            }
            throw error
        }
    }
}
