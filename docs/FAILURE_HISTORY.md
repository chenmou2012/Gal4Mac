# 故障复盘记录

更新时间：2026-09-26

本文记录 Gal4Mac 开发与本机运行过程中出现过的故障。将“日志确认”“用户确认”和“推测”分开，避免把相关现象当成已证实根因。

## Aokana：Unity 启动崩溃

### 现象与原因

- Aokana 使用 Unity 2018.2.19f1，主程序和 `UnityPlayer.dll` 都是 32 位。
- 初次启动进入 Direct3D 11 后，在 WineD3D swapchain 创建路径崩溃；日志包含 `wined3d_swapchain_state_create` 等调用。
- Engine 目录虽然带有 DXVK，但启动前没有把 32 位 `d3d11.dll`、`dxgi.dll` 安装到该游戏的 Wine 容器。只设置 `DXVK_ASYNC=1` 不会启用 DXVK。

### 修复与结果

- 对使用 D3D11 的游戏，把 Engine 自带的 x32 DXVK DLL 安装到 Wine 容器，并设置 `d3d11`、`dxgi` 原生优先覆盖。
- Unity 配置和启动流程已接入该处理。Aokana 日志确认加载 DXVK，并通过此前的图形初始化崩溃点；用户随后确认游戏运行没有问题。

### 非阻断日志

- Unity 仍记录过 `WindowsVideoMedia error 0xc00d36c4`（不支持的字节流类型），有一次退出日志随后还出现 `NullReferenceException`。
- 已给 Wine 进程加入 Engine 自带 GStreamer 插件目录，但没有证据证明这消除了该媒体错误。用户确认启动正常，因此目前将它记录为非阻断警告，不能认定它是已修复的根因。

## CLANNAD：引擎识别不符合项目要求

### 现象与原因

- 扫描器优先相信 `SiglusEngine_Steam.exe` 文件名和 Siglus 资源结构，因此把游戏库中的 `CLANNAD` 记为 SiglusEngine。
- 用户明确要求 CLANNAD 归为 RealLive。此处游戏名对应的已知兼容配置应优先于可执行文件命名启发式。

### 修复

- `EngineDetector` 对 `CLANNAD` 名称优先返回 RealLive。
- 扫描 `GalLib` 后，库条目显示为 RealLive，可执行文件仍是 `SiglusEngine_Steam.exe`。

## CLANNAD：音频断续、有杂音

### 排查过程

- 首次观察到游戏能启动，但音频断续并带杂音。
- 项目定义了引擎专属注册表优化，但 `GameLauncher` 没有调用 `EngineConfigurator.applyOptimizations`；启动时实际只执行通用 DirectSound 设置。现已把引擎配置接入同步和异步启动流程。
- CLANNAD 的 `.nwa` 音轨头部显示 44.1 kHz。将 RealLive 配置改为 44.1 kHz 后，用户仍报告有杂音，因此采样率不匹配不是充分解释，也不是有效修复。
- 本机 Wine 7.7 使用 `winecoreaudio`。代码中的 `PULSE_LATENCY_MSEC` 是 PulseAudio 参数，不能作为这条 CoreAudio 路径已生效的缓冲调节手段。CLI 延迟选项仍需整理；音频排障文档已修正。

### 最终修复与结果

- 为 CLANNAD 容器安装 DirectX 2010 的 32 位原生 `dsound.dll`，并设置 `dsound=native,builtin`，保留 Wine 内置 DLL 作为回退。
- 用户确认更换后杂音消失。可确认的结论是“原生 DirectSound 配置下问题消失”；“Wine 内置 DirectSound/CoreAudio 交互是底层根因”仍属于推断。
- 最初此配置只写入 CLANNAD 容器；随后按用户要求设为所有游戏的默认音频配置。
- 修改前备份位于 `~/Library/Application Support/Gal4Mac/AudioBackups/CLANNAD-before-dsound`。Winetricks 因系统缺少 `cabextract` 未能完成安装；之后使用系统 `bsdtar` 从已下载的 DirectX 运行库中提取 DLL 并完成配置。

## NEKOPARA 与全局音频默认值

- 用户报告 NEKOPARA vol.1 也有卡顿，并要求套用 CLANNAD 的音频配置；之后又要求默认应用到所有游戏。
- 启动器现在给所有游戏设置原生 DirectSound 优先、CoreAudio、44.1 kHz / 16 位和软件仿真，并从本机的共享来源向 32 位容器复制原生 `dsound.dll`，保留原 DLL 备份。
- 吉里吉里游戏默认使用 `-wsrecreate=no`，避免每段语音都重建 DirectSound 缓冲区；显式指定此选项的游戏可覆盖默认值。
- 已核对当前四个游戏容器的 DLL 和注册表设置。NEKOPARA 与其他游戏的音频卡顿是否消失，仍待游戏内复测。

## CLANNAD：弹窗文字显示方框

### 现象与当前判断

- CLANNAD 弹窗中的文字显示为方框，说明当前字体链路没有提供所需字形；此前 RealLive 配置没有设置中文区域，Wine 菜单字体准备逻辑也因此没有运行。
- 这是根据现象和配置作出的判断；目前还没有用户确认修复结果。

### 已做配置

- RealLive 默认区域设置为 `zh_CN.UTF-8`，尊重游戏条目中显式选择的 Wine 语言设置。
- 启动时将 Wine 菜单字体设为系统 Arial Unicode MS，并把 `MS Gothic`、`MS PGothic`、`MS Sans Serif`、`MS Shell Dlg`、`MS Shell Dlg 2`、`Tahoma` 映射到 macOS 的 Hiragino Sans GB。
- 已重新编译并启动 CLANNAD；注册表查询确认字体映射和菜单字体值写入。弹窗是否已恢复正常仍待用户确认。

## UI 截图中的布局异常

- 用户提供的 Gal4Mac 截图显示详情区留白和元素定位异常，且有细小的垂直渲染痕迹；之后用户要求重构为液态玻璃风格。
- 当时没有完成这张截图对应的布局根因分析。不能据此断言是某个 SwiftUI 约束或窗口尺寸造成；后续 UI 改动需要以实际窗口尺寸做视觉回归。

## 后续注意事项

- 将日志中的观测、用户复测结果和推测原因分开记录。
- 每个引擎配置必须确认启动流程确实调用，并核对 Wine 容器中的注册表最终值。
- macOS CoreAudio、PulseAudio、DirectSound 的配置不能混为一谈；延迟参数需确认对当前实际音频驱动有效。
- 对 DLL 替换保留每游戏容器级别的回退方式，避免改动共用 Engine 或其他游戏容器。
