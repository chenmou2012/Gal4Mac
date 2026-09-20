import SwiftUI
import Gal4MacCore

/// 简约的引擎图标（用 SwiftUI Shape 绘制，类 SVG）
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
            // 主菱形
            Path { p in
                p.move(to: CGPoint(x: 0.5, y: 0.05))
                p.addLine(to: CGPoint(x: 0.95, y: 0.5))
                p.addLine(to: CGPoint(x: 0.5, y: 0.95))
                p.addLine(to: CGPoint(x: 0.05, y: 0.5))
                p.closeSubpath()
            }
            .opacity(0.7)
            // 内嵌小菱形
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

    // MARK: - KiriKiri (书本/卷轴)
    private var kirikiriIcon: some View {
        ZStack {
            // 书左页
            RoundedRectangle(cornerRadius: 0.05)
                .frame(width: 0.42, height: 0.85)
                .offset(x: -0.13, y: 0)
                .opacity(0.8)
            // 书右页
            RoundedRectangle(cornerRadius: 0.05)
                .frame(width: 0.42, height: 0.85)
                .offset(x: 0.13, y: 0)
                .opacity(0.6)
            // 书脊中线
            Rectangle()
                .frame(width: 0.02, height: 0.85)
                .opacity(0.9)
        }
    }

    // MARK: - TyranoScript (地球)
    private var tyranoIcon: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 1.2)
                .opacity(0.8)
            // 经线
            Ellipse()
                .stroke(lineWidth: 0.8)
                .frame(width: size * 0.8, height: size * 0.8)
                .opacity(0.6)
            // 中线
            Rectangle()
                .frame(width: size, height: 1)
                .opacity(0.5)
        }
    }

    // MARK: - Ren'Py (文字气泡)
    private var renpyIcon: some View {
        ZStack {
            // 主气泡
            RoundedRectangle(cornerRadius: 3)
                .frame(width: size * 0.9, height: size * 0.65)
                .opacity(0.8)
            // 小尾巴
            Path { p in
                p.move(to: CGPoint(x: 0.3, y: 0.65))
                p.addLine(to: CGPoint(x: 0.25, y: 0.85))
                p.addLine(to: CGPoint(x: 0.4, y: 0.65))
                p.closeSubpath()
            }
            .opacity(0.8)
            // 文字点
            HStack(spacing: 2) {
                Circle().frame(width: 2, height: 2)
                Circle().frame(width: 2, height: 2)
                Circle().frame(width: 2, height: 2)
            }
            .offset(y: -1)
        }
    }

    // MARK: - RealLive (复古显示器)
    private var realLiveIcon: some View {
        ZStack {
            // 屏幕
            RoundedRectangle(cornerRadius: 1.5)
                .opacity(0.85)
            // 屏幕内容（波形）
            HStack(spacing: 1) {
                Capsule().frame(width: 1.5, height: 5)
                Capsule().frame(width: 1.5, height: 8)
                Capsule().frame(width: 1.5, height: 4)
                Capsule().frame(width: 1.5, height: 6)
            }
            .offset(y: 0)
            // 底座
            Rectangle()
                .frame(width: 6, height: 1)
                .offset(y: 6)
        }
    }

    // MARK: - NScripter (卷轴)
    private var nscripterIcon: some View {
        ZStack {
            // 顶杆
            Capsule()
                .frame(width: size * 0.95, height: 2)
                .offset(y: -size * 0.4)
            // 纸
            Rectangle()
                .frame(width: size * 0.7, height: size * 0.7)
                .opacity(0.7)
            // 底杆
            Capsule()
                .frame(width: size * 0.95, height: 2)
                .offset(y: size * 0.4)
            // 文字线
            VStack(spacing: 1.5) {
                Rectangle().frame(width: size * 0.4, height: 1)
                Rectangle().frame(width: size * 0.5, height: 1)
                Rectangle().frame(width: size * 0.35, height: 1)
            }
            .offset(y: -1)
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

    // MARK: - Artemis (星星)
    private var artemisIcon: some View {
        ZStack {
            // 4角星
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
    }

    // MARK: - Unknown (问号)
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
                EngineIcon(engine: engine, size: 18)
                Text(engine.displayName)
                    .font(.system(size: 13))
            }
        }
    }
    .padding()
}
