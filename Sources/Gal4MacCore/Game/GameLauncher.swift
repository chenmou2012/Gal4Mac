import Foundation

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

        // 先用游戏的语言环境启动 Wine，再配置其余注册表项。
        try engine.prepareMenuFont(prefix: prefix, engineConfig: engineConfig)

        // 3. 自动应用音频优化到 Wine prefix
        do {
            try engine.applyAudioOptimizations(prefix: prefix, engineConfig: engineConfig)
        } catch {
            // 忽略错误
        }

        // 4. 检查可执行文件
        let exePath = game.executablePath
        guard FileManager.default.fileExists(atPath: exePath.path) else {
            throw LaunchError.executableMissing(game.executable)
        }

        // 5. 准备启动参数
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

        args.append(contentsOf: additionalArgs)

        // 6. 启动
        print("🚀 启动 \(game.name) (\(game.engine.displayName))")
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
        onExit: @escaping (TimeInterval) -> Void
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

        try engine.prepareMenuFont(prefix: prefix, engineConfig: engineConfig)

        // 3. 自动应用音频优化
        do {
            try engine.applyAudioOptimizations(prefix: prefix, engineConfig: engineConfig)
        } catch {}

        // 4. 检查可执行文件
        let exePath = game.executablePath
        guard FileManager.default.fileExists(atPath: exePath.path) else {
            throw LaunchError.executableMissing(game.executable)
        }

        // 5. 准备启动参数
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

        args.append(contentsOf: additionalArgs)

        // 6. 异步启动
        let (process, startTime) = try engine.runWineAsync(
            prefix: prefix,
            executable: game.executable,
            arguments: args,
            workingDirectory: game.path,
            audio: audio,
            engineConfig: engineConfig
        )

        // 7. 后台监控进程退出
        DispatchQueue.global(qos: .background).async {
            process.waitUntilExit()
            let elapsed = Date().timeIntervalSince(startTime)
            DispatchQueue.main.async {
                onExit(elapsed)
            }
        }
    }

    /// 替换或添加参数
    public static func launchConfig(for game: Game) -> EngineOptimizer.WineConfig {
        var config = EngineOptimizer.config(for: game.engine)
        if let locale = game.wineLocale.unixLocale {
            config.environmentVariables.removeAll { ["LANG", "LC_ALL", "LC_CTYPE"].contains($0.0) }
            config.environmentVariables += [("LANG", locale), ("LC_ALL", locale)]
        }
        return config
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
