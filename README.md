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

## 依赖

- [Mythic Engine](https://github.com/MythicApp/Engine) (GPL-3.0)
- [Apple Game Porting Toolkit](https://developer.apple.com/gamesportingtoolkit/) (底层 LGPL Wine)

## 安装

### 快速开始

```bash
# 1. 安装 Mythic（提供 GPTK 引擎）
brew install --cask mythic

# 2. 首次启动 Mythic 让其下载 Engine (~850MB)
open /Applications/Mythic.app

# 3. 编译 Gal4Mac
cd /Users/chenmou2012/gal4mac
swift build -c release

# 4. 运行
./.build/release/gal4mac list
./.build/release/gal4mac launch Aokana
```

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
