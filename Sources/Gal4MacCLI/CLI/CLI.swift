import Foundation
import Gal4MacCore

/// Gal4Mac CLI 主程序
public struct CLI {

    public static func main(_ args: [String]) {
        guard args.count > 1 else {
            printUsage()
            exit(0)
        }

        let command = args[1]

        do {
            switch command {
            case "version":
                printVersion()
            case "doctor":
                try runDoctor()
            case "scan":
                try runScan(args: Array(args.dropFirst(2)))
            case "list":
                try runList()
            case "info":
                try runInfo(args: Array(args.dropFirst(2)))
            case "launch":
                try runLaunch(args: Array(args.dropFirst(2)))
            case "remove":
                try runRemove(args: Array(args.dropFirst(2)))
            case "libraries":
                try runLibraries()
            case "add-library":
                try runAddLibrary(args: Array(args.dropFirst(2)))
            case "remove-library":
                try runRemoveLibrary(args: Array(args.dropFirst(2)))
            case "help", "-h", "--help":
                printUsage()
            default:
                print("❌ 未知命令: \(command)")
                printUsage()
                exit(1)
            }
        } catch {
            print("❌ 错误: \(error.localizedDescription)")
            exit(1)
        }
    }

    // MARK: - 命令实现

    static func printVersion() {
        print("""
        Gal4Mac v0.1.0 (Phase 2 - Core)
        macOS Galgame 启动器
        License: GPL-3.0
        """)
    }

    static func printUsage() {
        print("""
        Gal4Mac - macOS Galgame 启动器

        用法:
          gal4mac <command> [options]

        命令:
          version              显示版本
          doctor               检查环境（Engine 等）
          scan                 扫描所有已配置的库
          scan <dir>           扫描指定目录并添加到库
          list                 列出已识别的游戏
          info <name>          显示游戏详细信息
          launch <name>        启动游戏（按名称匹配）
          remove <name>        从库中移除游戏
          libraries            显示配置的库路径
          add-library <dir>    添加库路径
          remove-library <dir> 移除库路径
          help                 显示此帮助

        启动选项:
          --fullscreen, -f     全屏模式
          --width, -w <n>      窗口宽度（默认 1280）
          --height, -h <n>     窗口高度（默认 720）
          --audio-lowlatency   低延迟音频（减少杂音，推荐）
          --audio-highquality  高质量音频（更稳定，可能有轻微延迟）
          --audio-latency <ms> 自定义音频延迟（毫秒）

        示例:
          gal4mac scan
          gal4mac scan ~/Games
          gal4mac list
          gal4mac launch CLANNAD
          gal4mac info Aokana
          gal4mac launch CLANNAD --fullscreen --width 1920 --height 1080
          gal4mac add-library /Volumes/ExternalHDD/GalGames

        """)
    }

    static func runDoctor() throws {
        print("🩺 环境检查\n")

        // macOS 版本
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        print("✓ macOS: \(osVersion)")

        // 架构
        #if arch(arm64)
        print("✓ 架构: Apple Silicon (arm64)")
        #else
        print("✓ 架构: Intel (x86_64)")
        #endif

        // Mythic 安装检查
        print("\n📦 Mythic Engine:")
        if EngineManager.isInstalled() {
            if let version = EngineManager.currentVersion() {
                print("✓ Mythic Engine 已安装")
                print("  版本: \(version.string)")
                print("  路径: \(EngineManager.engineDirectory.path)")
            } else {
                print("⚠️  Engine 已安装但版本信息无法读取")
            }
        } else {
            print("❌ Mythic Engine 未安装")
            print("   可使用内置 Engine 的 Gal4Mac.app")
            print("   CLI 需要本机已安装 Mythic Engine")
            exit(1)
        }

        // wine 二进制
        print("\n🍷 Wine 二进制:")
        let fm = FileManager.default
        if fm.fileExists(atPath: EngineManager.wineExecutable.path) {
            print("✓ wine64: \(EngineManager.wineExecutable.path)")
        } else {
            print("❌ wine64 未找到")
        }

        // DXVK
        print("\n🎨 DXVK (DirectX 转 Vulkan):")
        if fm.fileExists(atPath: EngineManager.dxvkDirectory.path) {
            let x64 = EngineManager.dxvkDirectory.appendingPathComponent("x64/d3d11.dll")
            let x32 = EngineManager.dxvkDirectory.appendingPathComponent("x32/d3d11.dll")
            print("  - x64 d3d11.dll: \(fm.fileExists(atPath: x64.path) ? "✓" : "❌")")
            print("  - x32 d3d11.dll: \(fm.fileExists(atPath: x32.path) ? "✓" : "❌")")
        } else {
            print("❌ DXVK 未找到")
        }

        print("\n✅ 检查完成")
    }

    static func runScan(args: [String]) throws {
        guard let path = args.first else {
            print("❌ 用法: gal4mac scan <directory>")
            exit(1)
        }

        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        print("📂 扫描目录: \(url.path)")

        let manager = LibraryManager()
        let found = try manager.scan(directory: url)

        if found.isEmpty {
            print("⚠️  未发现新的 galgame")
        } else {
            print("\n✅ 共发现 \(found.count) 个游戏")
        }
    }

    static func runList() throws {
        let manager = LibraryManager()
        let games = manager.loadLibrary()

        if games.isEmpty {
            print("📭 游戏库为空")
            print("   使用 'gal4mac scan <dir>' 添加游戏")
            return
        }

        print("📚 游戏库 (\(games.count) 个游戏):\n")
        for (index, game) in games.enumerated() {
            print("\(index + 1). \(game.name)")
            print("   引擎: \(game.engine.compatibility.emoji) \(game.engine.displayName) [\(game.engine.compatibility.rawValue)]")
            print("   大小: \(game.sizeDescription)")
            print("   路径: \(game.path.path)")
            print("")
        }
    }

    static func runInfo(args: [String]) throws {
        guard let name = args.first else {
            print("❌ 用法: gal4mac info <name>")
            exit(1)
        }

        let manager = LibraryManager()
        guard let game = manager.findGame(named: name) else {
            print("❌ 未找到游戏: \(name)")
            exit(1)
        }

        print("""
        🎮 \(game.name)

        引擎:       \(game.engine.compatibility.emoji) \(game.engine.displayName) [\(game.engine.compatibility.rawValue)]
        路径:       \(game.path.path)
        可执行文件: \(game.executable)
        大小:       \(game.sizeDescription)
        检测时间:   \(game.detectedAt.formatted())
        最后游玩:   \(game.lastPlayed?.formatted() ?? "从未")

        启动命令: gal4mac launch "\(game.name)"
        """)
    }

    static func runLaunch(args: [String]) throws {
        guard let name = args.first else {
            print("❌ 用法: gal4mac launch <name> [options]")
            exit(1)
        }

        var fullscreen = false
        var width = 1280
        var height = 720
        var additionalArgs: [String] = []
        var pathOverride: String? = nil
        var audio = EngineManager.AudioConfig()

        var i = 1
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "--fullscreen", "-f":
                fullscreen = true
            case "--width", "-w":
                if i + 1 < args.count, let w = Int(args[i + 1]) {
                    width = w
                    i += 1
                }
            case "--height", "-h":
                if i + 1 < args.count, let h = Int(args[i + 1]) {
                    height = h
                    i += 1
                }
            case "--path", "-p":
                if i + 1 < args.count {
                    pathOverride = args[i + 1]
                    i += 1
                }
            case "--audio-lowlatency":
                audio.latencyMs = 60
            case "--audio-highquality":
                audio = .highQuality
            case "--audio-latency":
                if i + 1 < args.count, let ms = Int(args[i + 1]) {
                    audio.latencyMs = ms
                    i += 1
                }
            case "--no-audio-hw":
                // 现在默认就是禁用硬件加速（通过注册表），不再需要此选项
                // 保留向后兼容
                audio.disableHardwareAcceleration = true
            case "--":
                additionalArgs.append(contentsOf: args[(i + 1)...])
                i = args.count
            default:
                additionalArgs.append(arg)
            }
            i += 1
        }

        let launcher = GameLauncher()

        // 如果指定了 --path，跳过库查找，直接构造 Game
        let game: Game
        if let pathStr = pathOverride {
            let path = URL(fileURLWithPath: (pathStr as NSString).expandingTildeInPath)
            let detector = EngineDetector()
            let engine = detector.detect(at: path)
            guard let executable = detector.findExecutable(at: path, engine: engine) else {
                print("❌ 未找到可执行文件: \(path.path)")
                exit(1)
            }
            game = Game(
                name: path.lastPathComponent,
                path: path,
                executable: executable,
                engine: engine
            )
        } else {
            let manager = LibraryManager()
            guard let found = manager.findGame(named: name) else {
                print("❌ 库中未找到游戏: \(name)")
                print("   使用 'gal4mac list' 查看所有游戏")
                print("   或使用 'gal4mac launch <name> --path <directory>' 直接指定路径")
                exit(1)
            }
            game = found
        }

        try launcher.launch(
            game: game,
            fullscreen: fullscreen,
            width: width,
            height: height,
            additionalArgs: additionalArgs,
            audio: audio
        )
    }

    static func runRemove(args: [String]) throws {
        guard let name = args.first else {
            print("❌ 用法: gal4mac remove <name>")
            exit(1)
        }

        let manager = LibraryManager()
        var library = manager.loadLibrary()
        let initial = library.count
        library.removeAll { $0.name.localizedCaseInsensitiveContains(name) }

        if library.count < initial {
            try manager.saveLibrary(library)
            print("✓ 已从库中移除 \(initial - library.count) 个游戏")
        } else {
            print("⚠️  未找到匹配 '\(name)' 的游戏")
        }
    }

    static func runLibraries() throws {
        let manager = LibraryManager()
        let config = manager.loadConfig()

        print("📚 已配置的库路径 (\(config.libraryPaths.count)):")
        if config.libraryPaths.isEmpty {
            print("   (无)")
        }
        for (i, path) in config.libraryPaths.enumerated() {
            let accessible = manager.isPathAccessible(path) ? "✓" : "⚠️ 不可访问"
            print("  \(i + 1). \(path.path)  \(accessible)")
        }
        if let last = config.lastScanAt {
            print("\n🕐 上次扫描: \(last.formatted())")
        }
    }

    static func runAddLibrary(args: [String]) throws {
        guard let pathStr = args.first else {
            print("❌ 用法: gal4mac add-library <directory>")
            exit(1)
        }

        let url = URL(fileURLWithPath: (pathStr as NSString).expandingTildeInPath)
        let manager = LibraryManager()
        let config = try manager.addLibraryPath(url)
        print("✓ 已添加库路径: \(url.path)")
        print("  当前共有 \(config.libraryPaths.count) 个库")
    }

    static func runRemoveLibrary(args: [String]) throws {
        guard let pathStr = args.first else {
            print("❌ 用法: gal4mac remove-library <directory>")
            exit(1)
        }

        let url = URL(fileURLWithPath: (pathStr as NSString).expandingTildeInPath)
        let manager = LibraryManager()
        let config = try manager.removeLibraryPath(url)
        print("✓ 已移除库路径: \(url.path)")
        print("  当前共有 \(config.libraryPaths.count) 个库")
    }
}
