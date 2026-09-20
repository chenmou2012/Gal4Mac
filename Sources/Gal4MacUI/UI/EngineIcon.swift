import SwiftUI
import Gal4MacCore

/// 引擎 logo 加载器
/// 优先使用官方logo（Resources/EngineLogos/<engine>.svg 或 .png）
/// 否则回退到自定义简约SVG
struct EngineLogoView: View {
    let engine: EngineType
    var size: CGFloat = 14
    var color: Color = Color.secondary

    var body: some View {
        Group {
            if let nsImage = loadOfficialLogo() {
                Image(nsImage: nsImage)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(color)
            } else {
                EngineIcon(engine: engine, size: size, color: color)
            }
        }
        .frame(width: size, height: size)
    }

    /// 加载官方logo
    private func loadOfficialLogo() -> NSImage? {
        // 尝试多种文件名格式
        let candidates = logoFileCandidates(for: engine)

        // 搜索路径列表（按优先级）
        var searchPaths: [String] = []

        // 1. Bundle 中的 Resources/EngineLogos/
        if let bundleResourcePath = Bundle.main.resourcePath {
            for filename in candidates {
                searchPaths.append("\(bundleResourcePath)/EngineLogos/\(filename)")
            }
        }

        // 2. .app bundle 的 Contents/Resources/EngineLogos/
        if let bundlePath = Bundle.main.bundlePath as String? {
            for filename in candidates {
                searchPaths.append("\(bundlePath)/Contents/Resources/EngineLogos/\(filename)")
            }
        }

        // 3. 开发时的工作目录
        let cwd = FileManager.default.currentDirectoryPath
        for filename in candidates {
            searchPaths.append("\(cwd)/Resources/EngineLogos/\(filename)")
        }

        // 4. 固定的开发路径
        for filename in candidates {
            searchPaths.append("/Users/chenmou2012/gal4mac/Resources/EngineLogos/\(filename)")
        }

        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                if let image = NSImage(contentsOfFile: path) {
                    return image
                }
            }
        }

        return nil
    }

    private func logoFileCandidates(for engine: EngineType) -> [String] {
        switch engine {
        case .unity:
            return ["unity.svg", "unity.png"]
        case .renpy:
            return ["renpy.png", "renpy.svg"]
        case .siglus:
            return ["siglus.svg", "siglus.png"]
        case .kirikiri:
            return ["kirikiri.svg", "kirikiri.png"]
        case .tyranoScript:
            return ["tyrano.svg", "tyrano.png"]
        case .realLive:
            return ["reallive.svg", "reallive.png"]
        case .nscripter:
            return ["nscripter.svg", "nscripter.png"]
        case .yuris:
            return ["yuris.svg", "yuris.png"]
        case .artemis:
            return ["artemis.svg", "artemis.png"]
        case .unknown:
            return []
        }
    }
}

/// 简约的引擎图标（用 SwiftUI Shape 绘制，作为后备方案）
struct EngineIcon: View {
    let engine: EngineType
    var size: CGFloat = 14
    var color: Color = Color.secondary

    var body: some View {
        ZStack {
            switch engine {
            case .unity:
                unityIcon
            case .siglus:
                siglusIcon
            case .kirikiri:
                kirikiriIcon
            case .tyranoScript:
                tyranoIcon
            case .renpy:
                renpyIcon
            case .realLive:
                realLiveIcon
            case .nscripter:
                nscripterIcon
            case .yuris:
                yurisIcon
            case .artemis:
                artemisIcon
            case .unknown:
                unknownIcon
            }
        }
        .frame(width: size, height: size)
        .foregroundStyle(color)
    }

    // MARK: - Unity (立方体)
    private var unityIcon: some View {
        ZStack {
            // 顶面
            Path { p in
                p.move(to: CGPoint(x: 0.5, y: 0.15))
                p.addLine(to: CGPoint(x: 0.95, y: 0.35))
                p.addLine(to: CGPoint(x: 0.5, y: 0.55))
                p.addLine(to: CGPoint(x: 0.05, y: 0.35))
                p.closeSubpath()
            }
            // 左面
            Path { p in
                p.move(to: CGPoint(x: 0.05, y: 0.35))
                p.addLine(to: CGPoint(x: 0.5, y: 0.55))
                p.addLine(to: CGPoint(x: 0.5, y: 0.95))
                p.addLine(to: CGPoint(x: 0.05, y: 0.75))
                p.closeSubpath()
            }
            .opacity(0.7)
            // 右面
            Path { p in
                p.move(to: CGPoint(x: 0.95, y: 0.35))
                p.addLine(to: CGPoint(x: 0.95, y: 0.75))
                p.addLine(to: CGPoint(x: 0.5, y: 0.95))
                p.addLine(to: CGPoint(x: 0.5, y: 0.55))
                p.closeSubpath()
            }
            .opacity(0.5)
        }
    }

    // MARK: - SiglusEngine (菱形)
    private var siglusIcon: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0.5, y: 0.05))
                p.addLine(to: CGPoint(x: 0.95, y: 0.5))
                p.addLine(to: CGPoint(x: 0.5, y: 0.95))
                p.addLine(to: CGPoint(x: 0.05, y: 0.5))
                p.closeSubpath()
            }
            .opacity(0.7)
            Path { p in
                p.move(to: CGPoint(x: 0.5, y: 0.25))
                p.addLine(to: CGPoint(x: 0.75, y: 0.5))
                p.addLine(to: CGPoint(x: 0.5, y: 0.75))
                p.addLine(to: CGPoint(x: 0.25, y: 0.5))
                p.closeSubpath()
            }
            .opacity(0.4)
            .scaleEffect(0.5)
            .blendMode(.overlay)
        }
    }

    // MARK: - KiriKiri (书本)
    private var kirikiriIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0.05)
                .frame(width: 0.42, height: 0.85)
                .offset(x: -0.13, y: 0)
                .opacity(0.8)
            RoundedRectangle(cornerRadius: 0.05)
                .frame(width: 0.42, height: 0.85)
                .offset(x: 0.13, y: 0)
                .opacity(0.6)
            Rectangle()
                .frame(width: 0.02, height: 0.85)
                .opacity(0.9)
        }
    }

    // MARK: - TyranoScript (恐龙/地球)
    private var tyranoIcon: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 1.2)
                .opacity(0.8)
            Ellipse()
                .stroke(lineWidth: 0.8)
                .frame(width: size * 0.8, height: size * 0.8)
                .opacity(0.6)
            Rectangle()
                .frame(width: size, height: 1)
                .opacity(0.5)
        }
    }

    // MARK: - Ren'Py (R字母)
    private var renpyIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .opacity(0.8)
            Text("R")
                .font(.system(size: size * 0.7, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - RealLive
    private var realLiveIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.5)
                .opacity(0.85)
            HStack(spacing: 1) {
                Capsule().frame(width: 1.5, height: 5)
                Capsule().frame(width: 1.5, height: 8)
                Capsule().frame(width: 1.5, height: 4)
                Capsule().frame(width: 1.5, height: 6)
            }
            Rectangle()
                .frame(width: 6, height: 1)
                .offset(y: 6)
        }
    }

    // MARK: - NScripter
    private var nscripterIcon: some View {
        ZStack {
            Capsule()
                .frame(width: size * 0.95, height: 2)
                .offset(y: -size * 0.4)
            Rectangle()
                .frame(width: size * 0.7, height: size * 0.7)
                .opacity(0.7)
            Capsule()
                .frame(width: size * 0.95, height: 2)
                .offset(y: size * 0.4)
        }
    }

    // MARK: - YU-RIS (月亮)
    private var yurisIcon: some View {
        ZStack {
            Circle()
                .opacity(0.9)
            Circle()
                .offset(x: 3, y: -2)
                .foregroundStyle(.background)
        }
        .compositingGroup()
    }

    // MARK: - Artemis
    private var artemisIcon: some View {
        Path { p in
            p.move(to: CGPoint(x: 0.5, y: 0.05))
            p.addLine(to: CGPoint(x: 0.62, y: 0.38))
            p.addLine(to: CGPoint(x: 0.95, y: 0.38))
            p.addLine(to: CGPoint(x: 0.68, y: 0.58))
            p.addLine(to: CGPoint(x: 0.78, y: 0.92))
            p.addLine(to: CGPoint(x: 0.5, y: 0.72))
            p.addLine(to: CGPoint(x: 0.22, y: 0.92))
            p.addLine(to: CGPoint(x: 0.32, y: 0.58))
            p.addLine(to: CGPoint(x: 0.05, y: 0.38))
            p.addLine(to: CGPoint(x: 0.38, y: 0.38))
            p.closeSubpath()
        }
        .opacity(0.85)
    }

    // MARK: - Unknown
    private var unknownIcon: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 1.2)
                .opacity(0.5)
            Text("?")
                .font(.system(size: size * 0.6, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(EngineType.allCases, id: \.self) { engine in
            HStack {
                EngineLogoView(engine: engine, size: 18)
                Text(engine.displayName)
                    .font(.system(size: 13))
            }
        }
    }
    .padding()
}
