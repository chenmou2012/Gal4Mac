# 构建 macOS 安装镜像

从仓库根目录运行：

```bash
ENGINE_DIR="$HOME/Library/Application Support/Mythic/Engine" \
    bash Scripts/build_release.sh
```

脚本构建 Release 版 SwiftUI 应用，复制本机 Engine，生成 `dist-release/Gal4Mac-1.0.0-macos-<架构>.dmg` 和 SHA-256 校验文件。镜像包含 `Gal4Mac.app` 与指向“应用程序”目录的快捷方式。默认版本为 `1.0.0`、构建号为 `1`；可设置 `VERSION`、`BUILD_NUMBER`、`OUTPUT_DIR`。不设置 `ENGINE_DIR` 时得到依赖本机 Mythic Engine 的轻量版。

默认使用临时签名，仅供本机安装验证。公开发布需要先在钥匙串安装带私钥的 `Developer ID Application` 身份，并检查：

```bash
security find-identity -v -p codesigning
```

用返回的完整身份名称重新构建并签名应用和 DMG：

```bash
SIGN_IDENTITY="Developer ID Application: 团队名称 (TEAMID)" \
ENGINE_DIR="$HOME/Library/Application Support/Mythic/Engine" \
    bash Scripts/build_release.sh
```

公证凭据先存入钥匙串；以下命令会安全地提示输入 App 专用密码：

```bash
xcrun notarytool store-credentials gal4mac-notary \
    --apple-id "你的 Apple ID" --team-id "TEAMID"
xcrun notarytool submit dist-release/Gal4Mac-1.0.0-macos-arm64.dmg \
    --keychain-profile gal4mac-notary --wait
xcrun stapler staple dist-release/Gal4Mac-1.0.0-macos-arm64.dmg
xcrun stapler validate dist-release/Gal4Mac-1.0.0-macos-arm64.dmg
spctl --assess --type execute --verbose=2 dist-release/Gal4Mac-1.0.0-macos-arm64.app
shasum -a 256 dist-release/Gal4Mac-1.0.0-macos-arm64.dmg \
    > dist-release/Gal4Mac-1.0.0-macos-arm64.dmg.sha256
```

若公证失败，用 `xcrun notarytool log <提交 ID> --keychain-profile gal4mac-notary` 查看具体问题。内置 Engine 含有多层可执行文件；可能需要逐层签名或为 Wine 相关进程调整 Hardened Runtime 权限，不能仅以脚本退出成功作为公证通过的证明。

发布前在干净的 macOS 14 或更新系统上检查安装、首次启动、Engine 检测、已验证游戏的启动和退出。内置 Engine 的第三方组件分发条款也需在对外发布前核实。`dist-release/` 为本地构建产物，不提交到 Git。
