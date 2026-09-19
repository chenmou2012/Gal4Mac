#!/bin/bash
# CLANNAD 官方中文版启动脚本
# 引擎: SiglusEngine (Steam破解版 by 3DM)
# 主程序: SiglusEngine_Steam.exe
# 中文资源: GameexeZH.dat + SceneZH.pck

ENGINE_DIR="$HOME/Library/Application Support/Mythic/Engine"
export WINEPREFIX="$HOME/Library/Application Support/Mythic/Containers/CLANNAD"
export WINESERVER="$ENGINE_DIR/wine/bin/wineserver"
export DYLD_FALLBACK_LIBRARY_PATH="$ENGINE_DIR/wine/lib:$DYLD_FALLBACK_LIBRARY_PATH"
export DXVK_ASYNC=1

cd /Users/chenmou2012/gal4mac/CLANNAD

# SiglusEngine 支持命令行参数
"$ENGINE_DIR/wine/bin/wine64" SiglusEngine_Steam.exe \
    -window \
    -width 1280 \
    -height 720 \
    "$@"
