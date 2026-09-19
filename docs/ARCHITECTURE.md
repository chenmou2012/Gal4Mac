# Gal4Mac - 架构设计文档

> 一个面向 macOS 的开源 Galgame 转译启动器

## 项目目标

让用户在 macOS（特别是 Apple Silicon）上以**原生体验**运行 Windows Galgame，
封装复杂的 Wine / GPTK 转译配置，提供一键启动、游戏库管理、兼容性优化。

## 核心定位

- **范围**：Galgame 通用启动器（不限于特定引擎）
- **平台**：macOS 14+ (Apple Silicon 优先，Intel 次之)
- **开源协议**：GPL-3.0（与 Mythic 一致）
- **底层**：Apple Game Porting Toolkit (基于开源 Wine)

## 技术选型

| 层次 | 技术 | 理由 |
|------|------|------|
| 前端 UI | SwiftUI | macOS 原生最佳体验 |
| 应用层 | Swift | 与系统深度集成 (Metal, Game Mode) |
| 转译层 | Apple GPTK | Apple 官方 + 底层开源 Wine |
| 资源管理 | SwiftData | 现代持久化方案 |
| 自动更新 | Sparkle | macOS 标配 |

## 为什么 fork Mythic

**Mythic 是当前最佳基础**：
- ✅ GPL-3.0 开源
- ✅ Swift/SwiftUI 原生
- ✅ 基于 GPTK 自定义实现
- ✅ 活跃维护（1.4k stars）
- ✅ 已分离 Engine 子仓库
- ❌ 主要面向 Epic Games，不针对 galgame

**我们的差异化**：
- 专门针对 galgame 引擎适配（KiriKiri, TyranoScript, RealLive, Unity VN）
- 自动应用社区补丁（宽屏、汉化、去马赛克）
- 中文/日文字体优化
- 游戏库管理（封面、存档、CJK 元数据）
- 一键配置 Wine prefix

## MVP 路线图

### Phase 1：环境验证（当前）
- [x] 选定 Mythic + GPTK 方案
- [x] 安装 Mythic.app
- [ ] 用 Aokana (32-bit Unity) 验证 GPTK 转译能力
- [ ] 记录兼容性问题

### Phase 2：MVP 启动器（4-6 周）
- [ ] Fork Mythic 仓库
- [ ] 重命名为 Gal4Mac
- [ ] 添加 galgame 引擎自动检测
  - KiriKiri (.xp3 文件识别)
  - TyranoScript (浏览器引擎)
  - Unity VN (.dat 资源识别)
  - RealLive / NScripter
- [ ] 配置文件 schema 化（每个引擎独立配置）
- [ ] 字体注入机制（中易宋体等）

### Phase 3：产品化（2-3 月）
- [ ] 游戏库 UI（SwiftUI Grid + Cover Flow）
- [ ] 自动获取封面、简介（CJK 元数据）
- [ ] 存档管理（云存档可选）
- [ ] 性能监控 + 日志收集
- [ ] 社区补丁中心（汉化、宽屏补丁）

## galgame 引擎支持矩阵

| 引擎 | 占比 | 难度 | 状态 |
|------|------|------|------|
| KiriKiri/KAG | 60% | 中 | 计划中 |
| Unity VN | 15% | 低 | MVP 验证 (Aokana) |
| TyranoScript | 10% | 低 | 计划中 |
| RealLive | 5% | 高 | 调研中 |
| NScripter/ONScripter | 5% | 中 | 调研中 |
| YU-RIS / Siglus | 5% | 高 | 调研中 |

## 关键技术挑战

1. **32 位 Windows 应用**：Wine 需要 i386 支持
   - GPTK 默认配置可能需要调整
   - 解决：配置 WINEARCH=win32

2. **CJK 字体渲染**：
   - Windows 默认字体（MS Gothic、SimSun）在 Mac 上不存在
   - 解决：自动注入 Noto Sans CJK / 思源黑体

3. **DirectX 版本兼容**：
   - galgame 主要用 DX9 / DX11
   - GPTK 通过 D3DMetal 转译，DX11 支持较好

4. **视频播放**：
   - 大量使用 MPEG-2 / WMV9
   - 需要 wine-staging + wmf decoder

5. **.dat 加密资源**：
   - Unity AssetBundle 加密
   - Sprite 私有打包
   - 解决：交给 Unity Player 自己处理

## 仓库结构规划

```
gal4mac/
├── ARCHITECTURE.md          # 本文档
├── README.md                # 用户文档
├── Mythic/                  # fork 自 Mythic
│   ├── Mythic/              # 主应用源码
│   ├── Engine/              # 转译引擎层
│   └── ...
├── docs/                    # 补充文档
│   ├── engines/             # 各引擎适配指南
│   └── troubleshooting.md   # 问题排查
└── tests/                   # 测试游戏列表
    └── Aokana/              # 首个验证游戏
```

## 参考资源

- Mythic: https://github.com/MythicApp/Mythic
- GPTK 官方：https://developer.apple.com/gamesportingtoolkit/
- Wine: https://www.winehq.org/
- Apple Silicon Wine 状态：https://github.com/Gcenx/wine
