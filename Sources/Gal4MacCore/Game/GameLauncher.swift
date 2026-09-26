import Foundation

public enum GameLaunchStage: String, Equatable, Sendable {
    case checkingEnvironment
    case preparingWine
    case configuringWine
    case checkingFiles
    case startingGame
    case runningGame

    public var message: String {
        switch self {
        case .checkingEnvironment: return "正在检查兼容环境"
        case .preparingWine: return "正在准备 Wine 容器"
        case .configuringWine: return "正在配置字体与音频环境"
        case .checkingFiles: return "正在检查游戏文件"
        case .startingGame: return "正在启动游戏进程"
        case .runningGame: return "游戏运行中"
        }
    }

    public var symbol: String {
        switch self {
        case .checkingEnvironment: return "checkmark.shield"
        case .preparingWine: return "shippingbox"
        case .configuringWine: return "slider.horizontal.3"
        case .checkingFiles: return "doc.text.magnifyingglass"
        case .startingGame: return "play.fill"
        case .runningGame: return "gamecontroller.fill"
        }
    }
}

/// 游戏启动器
///
/// 根据检测到的引擎类型，生成正确的启动参数并执行 wine 命令
public final class GameLauncher {

    public enum LaunchError: LocalizedError {
        case gameNotFound
        case executableMissing(String)
        case engineNotSupported
        case engineNotReady
        case launchFailed(String)

        public var errorDescription: String? {
            switch self {
            case .gameNotFound:
                return "游戏不存在"
            case .executableMissing(let exe):
                return "可执行文件不存在: \(exe)"
            case .engineNotSupported:
                return "引擎不支持"
            case .engineNotReady:
                return "Engine 未就绪，请先安装 Mythic Engine"
            case .launchFailed(let msg):
                return "启动失败: \(msg)"
            }
        }
    }

    private let detector = EngineDetector()
    private let engine = EngineManager.self

    public init() {}

    /// 启动游戏（同步版本，等待进程结束）
    public func launch(
        game: Game,
        fullscreen: Bool = false,
        width: Int = 1280,
        height: Int = 720,
        additionalArgs: [String] = [],
        audio: EngineManager.AudioConfig = EngineManager.AudioConfig(),
        onExit: ((TimeInterval) -> Void)? = nil
    ) throws {
        // 1. 检查 Engine
        do {
            try engine.validate()
        } catch {
            throw LaunchError.engineNotReady
        }

        // 2. 准备 Wine prefix
        let prefix = engine.winePrefix(for: game.name)
        let engineConfig = Self.launchConfig(for: game)

        if engineConfig.dxBackend == .d3d11 {
            try engine.installDXVK32Bit(prefix: prefix)
        }

        // 先用游戏的语言环境启动 Wine，再配置其余注册表项。
        try engine.prepareMenuFont(prefix: prefix, engineConfig: engineConfig)

        // 应用引擎专属 Wine 注册表项（例如 Siglus 的 DirectSound 参数）。
        try EngineConfigurator().applyOptimizations(config: engineConfig, prefix: prefix)

        // 3. 自动应用音频优化到 Wine prefix
        do {
            try engine.applyAudioOptimizations(prefix: prefix, engineConfig: engineConfig)
        } catch {
            // 忽略错误
        }
        try engine.installNativeDirectSound(prefix: prefix)

        // 4. 检查可执行文件
        let exePath = game.executablePath
        guard FileManager.default.fileExists(atPath: exePath.path) else {
            throw LaunchError.executableMissing(game.executable)
        }

        // 5. 准备启动参数
        let args = launchArguments(for: game, fullscreen: fullscreen, width: width, height: height, additionalArgs: additionalArgs)

        // 6. 启动
        print("🚀 启动 \(game.displayName) (\(game.engine.displayName))")
        if audio.latencyMs != nil {
            print("🔊 音频延迟: \(audio.latencyMs!)ms")
        }
        // 应用引擎特定环境变量
        for (key, value) in engineConfig.environmentVariables {
            print("⚙️  \(key)=\(value)")
        }

        do {
            let startTime = Date()
            try engine.runWine(
                prefix: prefix,
                executable: game.executable,
                arguments: args,
                workingDirectory: game.path,
                audio: audio,
                engineConfig: engineConfig
            )
            // 进程退出，累加时长
            let elapsed = Date().timeIntervalSince(startTime)
            onExit?(elapsed)
        } catch {
            throw LaunchError.launchFailed(error.localizedDescription)
        }
    }

    /// 启动游戏（异步版本，立即返回）
    /// - Parameters:
    ///   - onExit: 进程退出时的回调（返回游玩秒数）
    public func launchAsync(
        game: Game,
        fullscreen: Bool = false,
        width: Int = 1280,
        height: Int = 720,
        additionalArgs: [String] = [],
        audio: EngineManager.AudioConfig = EngineManager.AudioConfig(),
        onProgress: ((GameLaunchStage) -> Void)? = nil,
        onProcessStarted: ((Process, URL) -> Void)? = nil,
        onExit: @escaping (TimeInterval) -> Void
    ) throws {
        // 1. 检查 Engine
        onProgress?(.checkingEnvironment)
        do {
            try engine.validate()
        } catch {
            throw LaunchError.engineNotReady
        }

        // 2. 准备 Wine prefix
        onProgress?(.preparingWine)
        let prefix = engine.winePrefix(for: game.name)
        let engineConfig = Self.launchConfig(for: game)

        if engineConfig.dxBackend == .d3d11 {
            try engine.installDXVK32Bit(prefix: prefix)
        }

        onProgress?(.configuringWine)
        try engine.prepareMenuFont(prefix: prefix, engineConfig: engineConfig)

        // 同步版本使用相同的引擎专属 Wine 配置。
        try EngineConfigurator().applyOptimizations(config: engineConfig, prefix: prefix)

        // 3. 自动应用音频优化
        do {
            try engine.applyAudioOptimizations(prefix: prefix, engineConfig: engineConfig)
        } catch {}
        try engine.installNativeDirectSound(prefix: prefix)

        // 4. 检查可执行文件
        onProgress?(.checkingFiles)
        let exePath = game.executablePath
        guard FileManager.default.fileExists(atPath: exePath.path) else {
            throw LaunchError.executableMissing(game.executable)
        }

        // 5. 准备启动参数
        let args = launchArguments(for: game, fullscreen: fullscreen, width: width, height: height, additionalArgs: additionalArgs)

        // 6. 异步启动
        onProgress?(.startingGame)
        let (process, startTime) = try engine.runWineAsync(
            prefix: prefix,
            executable: game.executable,
            arguments: args,
            workingDirectory: game.path,
            audio: audio,
            engineConfig: engineConfig
        )
        onProcessStarted?(process, prefix)
        onProgress?(.runningGame)

        // 7. 后台监控进程退出
        DispatchQueue.global(qos: .background).async {
            process.waitUntilExit()
            let elapsed = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async {
                onExit(elapsed)
            }
        }
    }

    /// 停止指定游戏对应的 Wine prefix。
    public func stop(process: Process, prefix: URL) throws {
        try engine.stopWine(prefix: prefix, process: process)
    }

    /// 替换或添加参数
    public static func launchConfig(for game: Game) -> EngineOptimizer.WineConfig {
        var config = EngineOptimizer.config(for: game.engine)
        let directSoundKey = "HKCU\\Software\\Wine\\DirectSound"
        let dllOverridesKey = "HKCU\\Software\\Wine\\DllOverrides"
        let driversKey = "HKCU\\Software\\Wine\\Drivers"
        config.registryEntries.removeAll { key, name, _ in
            (key.caseInsensitiveCompare(directSoundKey) == .orderedSame &&
                ["HardwareAcceleration", "DefaultSampleRate", "DefaultBitsPerSample", "MaxShadowSize"].contains(name)) ||
            (key.caseInsensitiveCompare(dllOverridesKey) == .orderedSame && name == "dsound") ||
            (key.caseInsensitiveCompare(driversKey) == .orderedSame && name == "Audio")
        }
        config.registryEntries += [
            (directSoundKey, "HardwareAcceleration", "Emulation"),
            (directSoundKey, "DefaultSampleRate", "44100"),
            (directSoundKey, "DefaultBitsPerSample", "16"),
            (directSoundKey, "MaxShadowSize", "0"),
            (dllOverridesKey, "dsound", "native,builtin"),
            (driversKey, "Audio", "coreaudio"),
        ]
        config.dllOverrides.removeAll { $0.lowercased().hasPrefix("dsound=") }
        config.dllOverrides.append("dsound=n,b")
        if let locale = game.wineLocale.unixLocale {
            config.environmentVariables.removeAll { ["LANG", "LC_ALL", "LC_CTYPE"].contains($0.0) }
            config.environmentVariables += [("LANG", locale), ("LC_ALL", locale)]
        }
        return config
    }

    private func launchArguments(
        for game: Game,
        fullscreen: Bool,
        width: Int,
        height: Int,
        additionalArgs: [String]
    ) -> [String] {
        var args = game.launchArgs.isEmpty
            ? game.engine.defaultLaunchArgs(width: width, height: height)
            : game.launchArgs

        if fullscreen {
            args = replaceOrAdd(args: args, key: "-screen-fullscreen", value: "1")
            args = replaceOrAdd(args: args, key: "-fullscreen", value: "")
            args = removeArgs(args: args, keys: ["-window"])
        } else if game.engine == .unity {
            args = replaceOrAdd(args: args, key: "-screen-fullscreen", value: "0")
        }

        if game.engine == .kirikiri && additionalArgs.contains(where: { $0.lowercased().hasPrefix("-wsrecreate=") }) {
            args.removeAll { $0.lowercased().hasPrefix("-wsrecreate=") }
        }
        args.append(contentsOf: additionalArgs)
        if game.engine == .kirikiri && !args.contains(where: { $0.lowercased().hasPrefix("-wsrecreate=") }) {
            args.append("-wsrecreate=no")
        }
        return args
    }

    /// 替换或添加参数
    private func replaceOrAdd(args: [String], key: String, value: String) -> [String] {
        var result = args
        if let index = result.firstIndex(of: key) {
            if !value.isEmpty {
                if index + 1 < result.count {
                    result[index + 1] = value
                } else {
                    result.append(value)
                }
            } else {
                result.remove(at: index)
            }
        } else {
            result.append(key)
            if !value.isEmpty {
                result.append(value)
            }
        }
        return result
    }

    /// 移除指定的参数
    private func removeArgs(args: [String], keys: [String]) -> [String] {
        var result = args
        for key in keys {
            while let index = result.firstIndex(of: key) {
                result.remove(at: index)
                if index < result.count {
                    result.remove(at: index)
                }
            }
        }
        return result
    }
}
