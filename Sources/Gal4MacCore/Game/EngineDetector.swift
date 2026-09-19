import Foundation

/// 引擎检测器
///
/// 通过文件特征自动识别galgame使用的引擎类型
public struct EngineDetector {

    public init() {}

    /// 检测目录对应的引擎类型
    public func detect(at directory: URL) -> EngineType {
        let fm = FileManager.default

        // 1. SiglusEngine 检测
        if let siglus = detectSiglus(at: directory, fm: fm) {
            return siglus
        }

        // 2. KiriKiri 检测
        if let kirikiri = detectKiriKiri(at: directory, fm: fm) {
            return kirikiri
        }

        // 3. Unity 检测
        if let unity = detectUnity(at: directory, fm: fm) {
            return unity
        }

        // 4. TyranoScript 检测
        if let tyrano = detectTyranoScript(at: directory, fm: fm) {
            return tyrano
        }

        // 5. Ren'Py 检测
        if let renpy = detectRenPy(at: directory, fm: fm) {
            return renpy
        }

        // 6. RealLive / NScripter / YU-RIS / Artemis
        if let other = detectOther(at: directory, fm: fm) {
            return other
        }

        return .unknown
    }

    /// 找到可执行文件
    public func findExecutable(at directory: URL, engine: EngineType) -> String? {
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return nil }

        let executables = contents.filter { url in
            url.pathExtension.lowercased() == "exe"
        }

        // 排除明显不是主程序的辅助exe
        let nonPrimaryKeywords = ["crash", "handler", "setup", "unins", "update", "patch", "install"]

        let isPrimaryExe: (URL) -> Bool = { url in
            let name = url.lastPathComponent.lowercased()
            return !nonPrimaryKeywords.contains(where: { name.contains($0) })
        }

        let primaryExes = executables.filter(isPrimaryExe)

        // 引擎特定的可执行文件优先级
        switch engine {
        case .unity:
            // 1. 与目录同名的exe（Aokana.exe, GameName.exe）
            let dirName = directory.lastPathComponent
            if let match = primaryExes.first(where: {
                $0.lastPathComponent.lowercased() == "\(dirName.lowercased()).exe"
            }) {
                return match.lastPathComponent
            }
            // 2. 不含 Unity/Crash 字样的最大exe
            return primaryExes.max { lhs, rhs in
                let lhsSize = (try? lhs.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let rhsSize = (try? rhs.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return lhsSize < rhsSize
            }?.lastPathComponent ?? executables.first?.lastPathComponent
        case .siglus:
            return primaryExes.first {
                $0.lastPathComponent.lowercased().contains("siglus")
            }?.lastPathComponent ?? primaryExes.first?.lastPathComponent
        case .kirikiri:
            return primaryExes.first { $0.lastPathComponent.lowercased() == "krkr.exe" }?.lastPathComponent
                ?? primaryExes.first?.lastPathComponent
        default:
            return primaryExes.first?.lastPathComponent ?? executables.first?.lastPathComponent
        }
    }

    // MARK: - 具体引擎检测

    private func detectSiglus(at dir: URL, fm: FileManager) -> EngineType? {
        let hasGameExe = fileExists(named: "Gameexe.dat", at: dir, fm: fm) ||
                         fileExists(named: "GameexeZH.dat", at: dir, fm: fm)
        let hasScenePck = fileExists(named: "Scene.pck", at: dir, fm: fm) ||
                          fileExists(named: "SceneZH.pck", at: dir, fm: fm)
        let hasSiglusExe = containsFile(matching: "SiglusEngine", at: dir, fm: fm)
        let hasGan = (try? fm.contentsOfDirectory(at: dir.appendingPathComponent("gan"), includingPropertiesForKeys: nil)) != nil

        if hasSiglusExe || (hasGameExe && hasScenePck && hasGan) {
            return .siglus
        }
        return nil
    }

    private func detectKiriKiri(at dir: URL, fm: FileManager) -> EngineType? {
        // KiriKiri 特征：krkr.exe 或 tvpglfr.dat + xp3 文件
        let hasKrkrExe = fileExists(named: "krkr.exe", at: dir, fm: fm) ||
                         fileExists(named: "TVP.exe", at: dir, fm: fm)
        let hasXp3 = containsFile(matching: ".xp3", at: dir, fm: fm)
        let hasTvpgl = fileExists(named: "tvpglfr.dat", at: dir, fm: fm)

        // KiriKiri 通常有 video, image, system 等子目录
        let hasSystemDir = (try? fm.contentsOfDirectory(
            at: dir.appendingPathComponent("system"),
            includingPropertiesForKeys: nil
        )) != nil

        if hasKrkrExe || hasTvpgl || hasXp3 || hasSystemDir {
            // 区分 KiriKiri (2) 和 KiriKiri Z
            // 简化处理，统一返回 .kirikiri
            return .kirikiri
        }
        return nil
    }

    private func detectUnity(at dir: URL, fm: FileManager) -> EngineType? {
        // Unity 特征：
        // - <Game>_Data/ 目录
        // - UnityPlayer.dll
        // - UnityCrashHandler*.exe
        let hasUnityPlayer = fileExists(named: "UnityPlayer.dll", at: dir, fm: fm)
        let hasCrashHandler = containsFile(matching: "UnityCrashHandler", at: dir, fm: fm)
        let hasDataDir = containsDirectory(suffix: "_Data", at: dir, fm: fm)

        if hasUnityPlayer || hasCrashHandler || hasDataDir {
            return .unity
        }
        return nil
    }

    private func detectTyranoScript(at dir: URL, fm: FileManager) -> EngineType? {
        // TyranoScript 特征：
        // - tyrano.exe 或 NW.js (nw.exe, nw.dll)
        // - data/ 目录包含 .ks 文件
        // - first.ks
        let hasTyranoExe = fileExists(named: "tyrano.exe", at: dir, fm: fm)
        let hasNwExe = fileExists(named: "nw.exe", at: dir, fm: fm)
        let hasFirstKs = fileExists(named: "first.ks", at: dir, fm: fm) ||
                         fileExists(named: "first.ks", at: dir.appendingPathComponent("data"), fm: fm)

        if hasTyranoExe || hasNwExe || hasFirstKs {
            return .tyranoScript
        }
        return nil
    }

    private func detectRenPy(at dir: URL, fm: FileManager) -> EngineType? {
        // Ren'Py 特征：
        // - <game>.sh / <game>.exe
        // - renpy/ 或 game/ 目录
        let hasRenPyDir = fileExists(named: "renpy", at: dir, fm: fm, isDirectory: true)
        let hasGameDir = fileExists(named: "game", at: dir, fm: fm, isDirectory: true)
        let hasRenPySh = containsFile(suffix: ".sh", prefix: "", at: dir, fm: fm) &&
                        containsContent(matching: "renpy", at: dir, fm: fm)

        if hasRenPyDir || (hasGameDir && hasRenPySh) {
            return .renpy
        }
        return nil
    }

    private func detectOther(at dir: URL, fm: FileManager) -> EngineType? {
        // RealLive: AvgR.exe, RealLiveStdEn.exe
        if containsFile(matching: "AvgR", at: dir, fm: fm) ||
           containsFile(matching: "RealLive", at: dir, fm: fm) {
            return .realLive
        }

        // NScripter / ONScripter: nscripter.exe, 0.txt, nscript.dat
        if fileExists(named: "nscripter.exe", at: dir, fm: fm) ||
           fileExists(named: "nscript.dat", at: dir, fm: fm) {
            return .nscripter
        }

        // YU-RIS: yuris.exe
        if fileExists(named: "yuris.exe", at: dir, fm: fm) {
            return .yuris
        }

        // Artemis (月姬重制版)
        if fileExists(named: "Artemis.exe", at: dir, fm: fm) ||
           fileExists(named: "月姫.exe", at: dir, fm: fm) {
            return .artemis
        }

        return nil
    }

    // MARK: - 辅助方法

    private func fileExists(named name: String, at dir: URL, fm: FileManager, isDirectory: Bool? = nil) -> Bool {
        let url = dir.appendingPathComponent(name)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return false }
        if let expectedDir = isDirectory {
            return isDir.boolValue == expectedDir
        }
        return true
    }

    private func containsFile(matching pattern: String, at dir: URL, fm: FileManager) -> Bool {
        guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return false
        }
        return contents.contains { $0.lastPathComponent.lowercased().contains(pattern.lowercased()) }
    }

    private func containsFile(suffix: String, prefix: String, at dir: URL, fm: FileManager) -> Bool {
        guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return false
        }
        return contents.contains {
            $0.lastPathComponent.hasSuffix(suffix) &&
            (prefix.isEmpty || $0.lastPathComponent.hasPrefix(prefix))
        }
    }

    private func containsDirectory(suffix: String, at dir: URL, fm: FileManager) -> Bool {
        guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return false
        }
        return contents.contains {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: $0.path, isDirectory: &isDir)
            return isDir.boolValue && $0.lastPathComponent.hasSuffix(suffix)
        }
    }

    private func containsContent(matching text: String, at dir: URL, fm: FileManager) -> Bool {
        // 简化：检查常见shell脚本
        let candidates = dir.appendingPathComponent("run.sh")
        if let data = try? Data(contentsOf: candidates),
           let content = String(data: data, encoding: .utf8) {
            return content.lowercased().contains(text.lowercased())
        }
        return false
    }
}
