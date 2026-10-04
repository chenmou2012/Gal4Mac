# Gal4Mac

> 一个面向 macOS 的开源 Galgame 转译启动器

## 项目状态

🚧 **持续开发中**。SwiftUI 应用、CLI 和核心库均已接入；兼容性仍按具体游戏验证。

| 引擎 | 状态 |
|------|------|
| Unity (32-bit) | ✅ 已验证 (Aokana) |
| SiglusEngine | ✅ 已验证 (CLANNAD) |
| KiriKiri/KAG | 🔜 待测 |
| TyranoScript | 🔜 待测 |
| Ren'Py | 🔜 待测 |

## 特性

- 🎮 **多引擎识别**：识别 Unity、SiglusEngine、KiriKiri、TyranoScript 等；识别不代表已验证兼容
- 🍎 **Wine/GPTK 启动**：通过 Mythic Engine 运行 Windows 游戏
- 📚 **游戏库管理**：扫描、搜索、筛选、导入和一键启动
- 🌏 **CJK 与音频配置**：按游戏设置 Wine 语言环境，启动时应用字体映射与音频默认值
- 💾 **存档与 Steam 信息**：本地存档工具、Steam 游戏匹配及云存档导入入口
- 🆓 **完全开源**：GPL-3.0

## 系统要求

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4) 或 Intel
- 8GB+ RAM（推荐 16GB 用于大型游戏）

## 引擎

项目提供 SwiftUI 图形界面和命令行界面（CLI）。两者共用游戏库数据。通过 `swift run` 启动的开发版本和 CLI 使用本机安装的 Mythic Engine；带内置 Engine 的应用包会优先使用包内 Engine。Wine 容器位于 `~/Library/Application Support/Mythic/Containers/`，游戏库配置位于 `~/Library/Application Support/Gal4Mac/`。存档位置取决于具体游戏和引擎。

## 音频默认配置

启动器会为每个游戏的 Wine 容器设置 CoreAudio、DirectSound 原生优先（内置回退）、
44.1 kHz / 16 位及软件仿真，并为吉里吉里游戏默认复用语音缓冲区。
这些设置会在每次启动游戏时应用，已有游戏和之后导入的游戏使用同一套默认值。

本机已验证的原生 `dsound.dll` 放在
`~/Library/Application Support/Gal4Mac/Audio/DirectSound/x86/dsound.dll`。
启动器会把它复制到每个 32 位游戏容器，替换前的文件保存在同目录的 `Backups` 下。
若没有提供对应架构的原生 DLL，Wine 会回退到内置实现；64 位 DLL 可放在同级的
`x64/dsound.dll`。仓库和应用包不包含 Windows DLL。

从源码运行前需要安装 Mythic 并下载 Engine。引擎包含 [Wine](https://www.winehq.org/) 及
[Apple Game Porting Toolkit](https://developer.apple.com/gamesportingtoolkit/) 组件；SwiftPM 构建不会自动打包 Engine，仓库不存放引擎二进制。

## 安装

### 下载安装包

在 [Releases](https://github.com/chenmou2012/Gal4Mac/releases) 下载 `Gal4Mac-<版本>-macos-<架构>.dmg`，打开后把 `Gal4Mac.app` 拖进“应用程序”。安装包不含 Mythic Engine，需要先按下面的步骤安装 Mythic 并下载 Engine。

安装包没有 Apple Developer ID 签名，也未经公证，首次打开会被 Gatekeeper 拦截。任选一种方式放行，每次安装只需做一次：

- macOS 14：在“应用程序”中右键点击 Gal4Mac，选择“打开”，再确认“打开”。
- macOS 15 及更新：先双击打开一次并关闭提示，然后进入“系统设置 → 隐私与安全性”，在底部点击“仍要打开”。
- 或在终端运行：`xattr -dr com.apple.quarantine /Applications/Gal4Mac.app`

可用发布页中的 `.sha256` 文件校验下载：`shasum -a 256 -c Gal4Mac-*.dmg.sha256`。

### 从源码运行

### 快速开始

```bash
# 1. 安装 Mythic（提供 GPTK 引擎）
brew install --cask mythic

# 2. 首次启动 Mythic，让它下载 Engine
open /Applications/Mythic.app

# 3. 在仓库目录编译
swift build -c release

# 4. 启动图形界面
swift run Gal4MacApp

# 5. 或运行 CLI
./.build/release/gal4mac doctor
./.build/release/gal4mac list
./.build/release/gal4mac scan ~/Games/Gal
./.build/release/gal4mac launch "游戏名称"
```

## 使用示例

图形界面可从“导入游戏…”进入四步导入：选择本地文件夹、ZIP/RAR/7z 压缩包或 HTTP/HTTPS 压缩包直链；解压；确认显示名称、Steam 关联、引擎、可执行文件和语言环境；完成导入。在线下载需要 `aria2`；加密压缩包需要 `unar`。分卷压缩包会检查缺失分卷。也可以在设置中添加游戏库目录后重新扫描。

游戏详情支持启动、停止、在 Finder 中显示、设置语言环境和从游戏库移除。移除只删除库记录，不删除游戏文件。关联 Steam AppID 后可查看 Steam 介绍，并打开云存档导入入口：先在设置中的 Steam 网页登录，再确认目标存档目录和下载导入；同名文件会先备份。云存档功能仍需按具体游戏做端到端验证。

```bash
# 扫描游戏库
gal4mac scan ~/Games/

# 列出已识别的游戏
gal4mac list

# 启动游戏（自动检测引擎）
gal4mac launch CLANNAD

# 显示游戏信息
gal4mac info Aokana

# 查看环境与管理库目录
gal4mac doctor
gal4mac libraries
gal4mac add-library ~/Games/Gal

# 不经游戏库，直接指定游戏目录
gal4mac launch "游戏名称" --path /path/to/game
```

## 开发路线图

- [x] **Phase 1 (MVP)**：环境验证（Unity + SiglusEngine 通过）
- [x] **Phase 2 (核心)**：CLI 启动器
  - [x] 引擎检测
  - [x] 一键启动
  - [x] 基础 CJK 字体映射与 Wine 语言环境
- [x] SwiftUI 图形界面：游戏库、详情、导入、统计与基础设置
- [ ] 扩大逐游戏兼容性验证与 Steam 云存档端到端验证

## 架构

详细架构见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

```
Gal4Mac/
├── Sources/Gal4MacCLI/   # CLI 入口
├── Sources/Gal4MacUI/    # SwiftUI 图形界面
├── Sources/Gal4MacCore/  # 核心逻辑
│   ├── Engine/           # Mythic Engine 封装
│   ├── Game/             # 游戏模型 + 检测 + 启动
│   └── Library/          # 游戏库管理
├── Tests/                # 测试
├── docs/                 # 文档
└── Scripts/              # 启动脚本
```

## 许可证

GPL-3.0 - 详见 [LICENSE](LICENSE)

## 致谢

- [Mythic](https://github.com/MythicApp/Mythic) - 基础启动器架构
- [Apple](https://developer.apple.com/gamesportingtoolkit/) - Game Porting Toolkit
- [Wine](https://www.winehq.org/) - Windows 兼容层
- 所有 galgame 创作者

---

**免责声明**：本工具仅用于运行用户已合法拥有的游戏副本。请支持正版。
