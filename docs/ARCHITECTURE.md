# Gal4Mac 架构说明

> 本文描述当前仓库中的实现。兼容性实测记录见 [MVP_REPORT.md](MVP_REPORT.md)、[TESTING_MATRIX.md](TESTING_MATRIX.md) 和 [FAILURE_HISTORY.md](FAILURE_HISTORY.md)。

## 目标与边界

Gal4Mac 在 macOS 14+ 上管理并启动用户已有的 Windows Galgame。SwiftUI 应用和 CLI 共用 `Gal4MacCore`，通过 Mythic Engine 中的 Wine/GPTK 运行游戏。仓库不包含游戏、Engine 二进制或 Windows DLL。引擎识别结果和代码中的兼容度标签不能替代逐游戏测试。

## 代码结构

| 路径 | 职责 |
|------|------|
| `Sources/Gal4MacCore/Game/` | 游戏模型、引擎检测、启动流程 |
| `Sources/Gal4MacCore/Engine/` | Engine 定位、Wine prefix、DXVK、字体和音频配置 |
| `Sources/Gal4MacCore/Library/` | 游戏库扫描与持久化、归档解压、存档和 Steam 云文件导入 |
| `Sources/Gal4MacCLI/` | `gal4mac` 命令入口 |
| `Sources/Gal4MacUI/` | SwiftUI 游戏库、导入向导、Steam 元数据与网页会话 |
| `Tests/Gal4MacCoreTests/` | 不依赖游戏文件和已安装 Engine 的核心库测试 |
| `Scripts/` | 早期逐游戏验证脚本；不是应用启动入口 |

`Package.swift` 定义 `Gal4MacCore` 库、`gal4mac` 和 `Gal4MacApp` 两个可执行产品，以及核心库测试目标。当前持久化使用 JSON 文件，没有使用 SwiftData；仓库也没有接入 Sparkle 自动更新。

## 启动路径

1. `LibraryManager` 从游戏目录扫描或导入向导保存游戏记录，包含路径、可执行文件、引擎、显示名称和可选 Steam AppID。
2. `GameLauncher` 从记录获取运行配置，`EngineManager` 为每个游戏准备独立 Wine prefix。
3. 启动前按需配置 DXVK、引擎优化、音频、用户提供的 DirectSound DLL 与字体映射，再启动游戏进程。
4. SwiftUI 记录启动状态和本次运行时间，并写回游戏库；CLI 提供环境检查、扫描、列表、启动和库目录管理等命令。

`EngineManager` 优先查找应用资源目录中的 `Engine`（必须有 `wine/bin/wine64` 和 `Properties.plist`）；找不到时使用 `~/Library/Application Support/Mythic/Engine/`。普通 `swift build` / `swift run` 不会自动生成带内置 Engine 的应用包，因此开发运行和 CLI 需要本机安装 Mythic Engine。

## 本地数据与外部依赖

| 位置或依赖 | 用途 |
|------------|------|
| `~/Library/Application Support/Gal4Mac/config.json` | 游戏库目录配置 |
| `~/Library/Application Support/Gal4Mac/library.json` | 游戏记录和本地游玩统计 |
| `~/Library/Application Support/Mythic/Containers/` | 各游戏的 Wine prefix |
| `~/Library/Application Support/Gal4Mac/SaveBackups/` | 本地存档导入产生的备份 |
| `~/Library/Application Support/Gal4Mac/Audio/DirectSound/` | 用户自行提供的 x86/x64 `dsound.dll` |
| `aria2`、`unar` | 分别用于在线导入和加密压缩包解压；按功能需要安装 |

存档原文件可能在游戏目录或引擎指定的位置，不统一存入 Gal4Mac 数据目录。Steam 登录由 WebKit 持久化网站数据保存；Steam 云存档流程依赖用户登录及 Steam 页面，真实游戏读取结果仍需逐游戏验证。

## 兼容性状态

当前有 Aokana（32 位 Unity）和 CLANNAD（SiglusEngine）的手动验证记录。其他引擎虽有检测分支或启动配置，仍应视为待测。测试新游戏时，记录具体游戏版本、macOS/Engine 版本、启动结果，以及字体、音频、视频和存档表现，并更新 [TESTING_MATRIX.md](TESTING_MATRIX.md)。

## 开发与验证

在仓库根目录运行：

```bash
swift build
swift test
swift run gal4mac doctor
swift run Gal4MacApp
```

构建和单元测试不应依赖本机游戏或 Engine；`doctor` 和实际启动会检查运行环境。新增可复用逻辑放在 `Gal4MacCore`，让 UI 与 CLI 共用。
