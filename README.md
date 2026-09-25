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

图形版 `Gal4Mac.app` 可内置 Mythic Engine，运行时优先使用应用包中的
`Contents/Resources/Engine`。Wine 容器和存档仍保存在用户目录，更新应用不会覆盖。
开发时直接运行 SwiftPM 可执行文件、或使用 CLI 时，则沿用本机的 Mythic Engine。

打包机需要先安装 Mythic Engine（默认位于
`~/Library/Application Support/Mythic/Engine`）。如在其他目录，可设置
`MYTHIC_ENGINE_SOURCE`。引擎包含 [Wine](https://www.winehq.org/) 及
[Apple Game Porting Toolkit](https://developer.apple.com/gamesportingtoolkit/) 组件；
打包脚本从本机复制引擎，仓库不存放引擎二进制。

## 安装

### 快速开始

```bash
# 1. 安装 Mythic（提供 GPTK 引擎）
brew install --cask mythic

# 2. 首次启动 Mythic 让其下载 Engine (~850MB)
open /Applications/Mythic.app

# 3. 在仓库目录编译 CLI
swift build -c release

# 4. 运行 CLI
./.build/release/gal4mac list
./.build/release/gal4mac launch Aokana

# 5. 打包内置 Engine 的图形应用
./Scripts/package_app.sh
open ./dist/Gal4Mac.app
```

打包结果位于 `dist/Gal4Mac.app`，使用本机临时签名，可直接在本机测试。
对外发布需使用发布者的 Developer ID 签名并完成 Apple 公证。

## 使用示例

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
- [ ] **Phase 3 (UI)**：SwiftUI 图形界面
- [ ] **Phase 4 (产品)**：游戏库、自动补丁

## 架构

详细架构见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

```
Gal4Mac/
├── Sources/Gal4Mac/      # CLI 入口
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
