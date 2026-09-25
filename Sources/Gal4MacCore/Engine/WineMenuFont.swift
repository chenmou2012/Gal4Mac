import Foundation

public extension EngineManager {
    /// Wine 的默认 Tahoma 菜单字体在部分前缀中缺少中日文字形。
    /// 保留菜单字号等设置，只将字体名称换为 macOS 自带的 Arial Unicode MS。
    static func prepareMenuFont(prefix: URL, engineConfig: EngineOptimizer.WineConfig) throws {
        let locale = engineConfig.environmentVariables.first { $0.0 == "LC_ALL" || $0.0 == "LANG" }?.1 ?? ""
        guard locale.hasPrefix("zh_") || locale.hasPrefix("ja_") else { return }

        let font = URL(fileURLWithPath: "/System/Library/Fonts/Supplemental/Arial Unicode.ttf")
        guard FileManager.default.fileExists(atPath: font.path) else { return }

        let key = "HKCU\\Control Panel\\Desktop\\WindowMetrics"
        let environment = launchEnvironment(prefix: prefix, engineConfig: engineConfig)
        let query = try runFontRegistry(["query", key, "/v", "MenuFont"], environment: environment)
        var bytes = query.status == 0 ? menuFontBytes(from: query.output) : nil
        if bytes == nil {
            bytes = Array(repeating: 0, count: 92)
            bytes![0...3] = [0xf5, 0xff, 0xff, 0xff] // 高度 -11
            bytes![16...19] = [0x90, 0x01, 0, 0] // 字重 400
            bytes![27] = 0x22
        }

        var updated = bytes!
        let name = Array("Arial Unicode MS".utf16)
        var face = Array(repeating: UInt8(0), count: 64)
        for (index, unit) in name.enumerated() {
            face[index * 2] = UInt8(truncatingIfNeeded: unit)
            face[index * 2 + 1] = UInt8(truncatingIfNeeded: unit >> 8)
        }
        guard Array(updated[28..<92]) != face else { return }
        updated.replaceSubrange(28..<92, with: face)
        let hex = updated.map { String(format: "%02x", $0) }.joined()
        let result = try runFontRegistry(
            ["add", key, "/v", "MenuFont", "/t", "REG_BINARY", "/d", hex, "/f"],
            environment: environment
        )
        guard result.status == 0 else {
            throw MenuFontError.registryFailed(result.output)
        }
    }

    private static func menuFontBytes(from output: String) -> [UInt8]? {
        guard let range = output.range(of: "REG_BINARY") else { return nil }
        let remainder = output[range.upperBound...]
        let line = remainder.split(whereSeparator: \.isNewline).first ?? ""
        let hex = line.filter { $0.isHexDigit }
        guard hex.count == 184 else { return nil }
        var bytes: [UInt8] = []
        var cursor = hex.startIndex
        while cursor < hex.endIndex {
            let next = hex.index(cursor, offsetBy: 2)
            guard let value = UInt8(hex[cursor..<next], radix: 16) else { return nil }
            bytes.append(value)
            cursor = next
        }
        return bytes
    }

    private static func runFontRegistry(_ args: [String], environment: [String: String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = wineExecutable
        process.arguments = ["reg"] + args
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return (process.terminationStatus, text)
    }

    private enum MenuFontError: LocalizedError {
        case registryFailed(String)

        var errorDescription: String? {
            switch self {
            case .registryFailed(let detail): return "设置 Wine 中文菜单字体失败：\(detail)"
            }
        }
    }
}
