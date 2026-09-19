#!/bin/bash
# Aokana 启动脚本 - 基于Mythic Engine (Wine 7.7 + GPTK)

ENGINE_DIR="$HOME/Library/Application Support/Mythic/Engine"
export WINEPREFIX="$HOME/Library/Application Support/Mythic/Containers/Aokana"
export WINESERVER="$ENGINE_DIR/wine/bin/wineserver"
export DYLD_FALLBACK_LIBRARY_PATH="$ENGINE_DIR/wine/lib:$DYLD_FALLBACK_LIBRARY_PATH"
export DXVK_ASYNC=1

cd /Users/chenmou2012/gal4mac/Aokana

# 使用窗口模式启动
"$ENGINE_DIR/wine/bin/wine64" Aokana.exe \
    -screen-fullscreen 0 \
    -screen-width 1280 \
    -screen-height 720 \
    -screen-quality beautiful \
    "$@"
