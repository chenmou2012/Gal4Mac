# Gal4Mac

> 一个面向 macOS 的开源 Galgame 转译启动器

## 项目状态

🚧 **Phase 2 开发中** - 已验证 MVP

| 引擎 | 状态 |
|------|------|
| Unity (32-bit) | ✅ 已验证 (Aokana) |
| SiglusEngine | ✅ 已验证 (CLANNAD) |
| KiriKiri/KAG | 🔜 待测 |
| TyranoScript | 🔜 待测 |
| Ren'Py | 🔜 待测 |

## 特性

- 🎮 **多引擎支持**：KiriKiri、SiglusEngine、Unity、TyranoScript 等
- 🍎 **Apple Silicon 原生优化**：基于 Apple Game Porting Toolkit
- 📚 **游戏库管理**：自动检测引擎，一键启动
- 🌏 **CJK 优化**：内置中日文字体注入
- 🆓 **完全开源**：GPL-3.0

## 系统要求

- macOS 14.0+ (Sonoma)
- Apple Silicon (M1/M2/M3/M4) 或 Intel
- 8GB+ RAM（推荐 16GB 用于大型游戏）

## 引擎

项目提供 SwiftUI 图形界面和命令行界面（CLI）。两者共用本机安装的 Mythic Engine 与游戏库数据；Wine 容器和存档保存在用户目录。

## 音频默认配置

启动器会为每个游戏的 Wine 容器设置 CoreAudio、DirectSound 原生优先（内置回退）、
44.1 kHz / 16 位及软件仿真，并为吉里吉里游戏默认复用语音缓冲区。
这些设置会在每次启动游戏时应用，已有游戏和之后导入的游戏使用同一套默认值。

本机已验证的原生 `dsound.dll` 放在
`~/Library/Application Support/Gal4Mac/Audio/DirectSound/x86/dsound.dll`。
启动器会把它复制到每个 32 位游戏容器，替换前的文件保存在同目录的 `Backups` 下。
若没有提供对应架构的原生 DLL，Wine 会回退到内置实现；64 位 DLL 可放在同级的
`x64/dsound.dll`。仓库和应用包不包含 Windows DLL。

首次使用前需要安装 Mythic 并下载 Engine。引擎包含 [Wine](https://www.winehq.org/) 及
[Apple Game Porting Toolkit](https://developer.apple.com/gamesportingtoolkit/) 组件；仓库不存放引擎二进制。

## 安装

### 快速开始

```bash
# 1. 安装 Mythic（提供 GPTK 引擎）
brew install --cask mythic

# 2. 首次启动 Mythic 让其下载 Engine (~850MB)
open /Applications/Mythic.app

# 3. 在仓库目录编译
swift build -c release

# 4. 启动图形界面
swift run Gal4MacApp

# 5. 或运行 CLI
./.build/release/gal4mac list
./.build/release/gal4mac launch Aokana

```

## 使用示例

图形界面右上角的 `+` 打开四步导入：选择本地文件夹或压缩包（也可填 HTTP/HTTPS 直链）、解压、确认游戏身份与运行配置、完成导入。在线下载需要 `aria2`；加密压缩包需要 `unar`。第三步会搜索 Steam 游戏，可以接受自动匹配、手动搜索选择，或设为自定义游戏。旧游戏也可在详情页匹配 Steam。已关联的游戏显示 Steam 介绍和背景，并提供存档同步入口：点击后先检查登录状态，未登录则在设置页的 Steam 网页登录；登录信息由 WebKit 的持久化网站数据保存。同步弹窗会先展示导入位置，用户确认“下载并导入”后才开始下载；同名本地文件会先备份。

```bash
# 扫描游戏库
gal4mac scan ~/Games/

# 列出已识别的游戏
gal4mac list

# 启动游戏（自动检测引擎）
gal4mac launch CLANNAD

# 显示游戏信息
gal4mac info Aokana

# 手动指定引擎
gal4mac launch /path/to/game --engine kirikiri
```

## 开发路线图

- [x] **Phase 1 (MVP)**：环境验证（Unity + SiglusEngine 通过）
- [x] **Phase 2 (核心)**：CLI 启动器
  - [x] 引擎检测
  - [x] 一键启动
  - [ ] CJK 字体注入
- [x] SwiftUI 图形界面：游戏库、详情、导入、统计与基础设置

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
