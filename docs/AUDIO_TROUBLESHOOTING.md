# 音频排障

Gal4Mac 在启动每款游戏时，默认为其 Wine 容器设置 CoreAudio、
`dsound=native,builtin`、DirectSound 软件仿真、44.1 kHz / 16 位和
`MaxShadowSize=0`。本机提供的原生 `dsound.dll` 会自动复制到相应架构的容器，
首次替换前的 DLL 会备份在
`~/Library/Application Support/Gal4Mac/Audio/DirectSound/Backups/`。
缺少原生 DLL 时，Wine 会使用内置实现。

吉里吉里游戏还会默认传入 `-wsrecreate=no`，让声道数和采样率相同的语音复用
DirectSound 缓冲区。游戏如果显式指定 `-wsrecreate=yes`，启动器尊重该设置。
这项行为见[吉里吉里命令行文档](https://krkren.github.io/documents/core/commandline.html)。

## 卡顿时先确认

- 只有声音断续：记录游戏、音频类型以及当时使用的输出设备。
- 声音和画面同时停顿：优先检查游戏读取或解码语音的耗时，以及其他进程的负载。
- 只有某款吉里吉里游戏在语音开头出现爆音：可单独尝试
  `-wsrecreate=yes`；这会让游戏每次重建缓冲区，可能增加语音切换开销。

本机 Mythic Engine 使用 `winecoreaudio`。CLI 中的 `--audio-latency`
目前只设置 `PULSE_LATENCY_MSEC`，不能当作 CoreAudio 缓冲区调节已生效。
已有反馈中，CLANNAD 的杂音在改用原生 DirectSound 后消失；
这不代表其他游戏的卡顿已经得到游戏内验证。
