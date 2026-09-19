#!/bin/bash
# CLANNAD 启动脚本 - 音频优化版本

ENGINE_DIR="$HOME/Library/Application Support/Mythic/Engine"
export WINEPREFIX="$HOME/Library/Application Support/Mythic/Containers/CLANNAD"
export WINESERVER="$ENGINE_DIR/wine/bin/wineserver"
export DYLD_FALLBACK_LIBRARY_PATH="$ENGINE_DIR/wine/lib:$DYLD_FALLBACK_LIBRARY_PATH"

# ===== 音频优化 =====
# 增大音频缓冲区延迟，减少杂音
export PULSE_LATENCY_MSEC=120

# macOS 上 Wine 用 coreaudio
export SDL_AUDIODRIVER=coreaudio

# Wine 注册表设置（DirectSound 模拟）
export WINEDLLOVERRIDES="dsound=n,b"

# DXVK 性能
export DXVK_ASYNC=1
export DXVK_STATE_CACHE_PATH=~/.cache/dxvk-clannad

cd /Users/chenmou2012/gal4mac/CLANNAD
"$ENGINE_DIR/wine/bin/wine64" SiglusEngine_Steam.exe \
    -window \
    -width 1280 \
    -height 720 \
    -language schinese \
    "$@"
