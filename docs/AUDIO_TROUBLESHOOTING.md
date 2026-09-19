# 音频杂音调优指南

> 适用于 Gal4Mac / Mythic Engine (Wine 7.7 + Apple GPTK) 在 macOS 上的音频问题

## 问题诊断

| 症状 | 可能原因 |
|------|---------|
| **持续噼啪声** | 音频缓冲区过小 |
| **周期性卡顿** | 采样率不匹配 |
| **BGM/语音断续** | DirectSound 兼容性 |
| **复杂场景杂音明显** | CPU 过载 |
| **完全无声** | 音频驱动问题 |

## 快速解决（按优先级）

### 方案1：低延迟模式（推荐首选）

```bash
gal4mac launch CLANNAD --audio-lowlatency
```

设置 `PULSE_LATENCY_MSEC=60`，适合大多数galgame。

### 方案2：自定义延迟

```bash
# 增大延迟（更稳定，但声音稍微滞后）
gal4mac launch CLANNAD --audio-latency 120

# 严重杂音用更大值
gal4mac launch CLANNAD --audio-latency 200
```

### 方案3：禁用硬件加速

```bash
gal4mac launch CLANNAD --no-audio-hw
```

强制使用软件音频仿真（`dsound=n,b`），解决 DirectSound 硬件加速冲突。

### 方案4：组合使用（最稳定）

```bash
gal4mac launch CLANNAD --audio-highquality
```

等价于：latency=120ms + 禁用硬件加速。

## 高级调优

### 修改 Wine 注册表

```bash
# 用 wine regedit 修改
gal4mac launch CLANNAD --env WINEDEBUG=warn+dsound
# 然后游戏中按 Alt+F4 退出
# 再用以下命令编辑注册表
WINEPREFIX="$HOME/Library/Application Support/Mythic/Containers/CLANNAD" \
  /Applications/Mythic.app/Contents/Resources/wine64 regedit
```

注册表项：
```
HKEY_CURRENT_USER\Software\Wine\DirectSound
  HardwareAcceleration = "Emulation"   # 完整仿真
  DefaultSampleRate = 48000            # 匹配 macOS
  DefaultBitsPerSample = 16
```

### 环境变量全集

```bash
# 音频延迟（毫秒）
export PULSE_LATENCY_MSEC=120

# SDL 音频驱动
export SDL_AUDIODRIVER=coreaudio

# Wine DLL 覆盖
export WINEDLLOVERRIDES="dsound=n,b"

# Wine 调试
export WINEDEBUG=warn+dsound,err+dsound

# DXVK 异步（可能影响音频）
export DXVK_ASYNC=0  # 试试看

# STAGING 性能优化
export STAGING_WRITECOPY=1
```

## 引擎特定建议

### KiriKiri / KAG
- 默认参数通常 OK
- 严重杂音时加 `--audio-latency 120`

### SiglusEngine (CLANNAD 等)
- 默认 OK
- 中文版用 `--no-audio-hw` 通常能解决

### Unity (Aokana 等)
- 大型 Unity 游戏更耗 CPU
- 强烈推荐 `--audio-latency 120`

### TyranoScript
- 基于浏览器，音频问题少
- 优先尝试默认

## 配置到项目

在 `~/.config/gal4mac/config.json`（未来版本支持）：

```json
{
  "audio": {
    "latency_ms": 120,
    "disable_hw": false,
    "driver": "coreaudio"
  }
}
```

## 已知问题

1. **Wine 7.7 音频子系统比新版 Wine 略差** - 但稳定性更高
2. **Apple Silicon 32位音频线程** - 偶有杂音
3. **某些 OGG/WMA 编码** - Wine 解码器可能有问题

## 反馈

仍有杂音？请记录：
1. 哪个游戏
2. 杂音类型（持续/间歇/仅BGM/仅语音）
3. macOS 版本
4. 已尝试的方案

提交到 GitHub Issues。
