import SwiftUI
import Gal4MacCore

struct SidebarLink: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? .white : MythicTheme.accentLight)
                if !compact {
                    Text(title)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .transition(.opacity)
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.88))
            .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
            .padding(.horizontal, compact ? 0 : 11)
            .frame(height: 37)
            .background(isSelected ? MythicTheme.accent : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, compact ? 8 : 12)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct GameArtworkCard: View {
    let game: Game
    let artworkURL: URL?
    let canLaunch: Bool
    let isLaunching: Bool
    let canStop: Bool
    let isStopping: Bool
    let openAction: () -> Void
    let launchAction: () -> Void
    let stopAction: () -> Void
    @EnvironmentObject var library: GameLibraryViewModel
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: openAction) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [MythicTheme.heroTop, MythicTheme.heroBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let artworkURL {
                        CachedArtworkImage(url: artworkURL) { fallbackArtwork }
                    } else {
                        fallbackArtwork
                    }
                    LinearGradient(colors: [.clear, .black.opacity(0.16), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(game.name)
                            .font(.system(size: 20, weight: .bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(game.engine.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(16)
                }
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(game.name)，打开详情")

            HStack(spacing: 8) {
                Label(game.playtime > 0 ? game.playtimeDescription : library.gameSizeDescription(for: game), systemImage: game.playtime > 0 ? "clock" : "internaldrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: canStop ? stopAction : launchAction) {
                    Label(isStopping ? "停止中" : canStop ? "停止游戏" : isLaunching ? "启动中" : "启动", systemImage: canStop ? "stop.fill" : isLaunching ? "hourglass" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(minWidth: 88, minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(canStop ? .red : MythicTheme.accent)
                .disabled(canStop ? isStopping : !canLaunch)
            }
            .padding(.horizontal, 13)
            .frame(height: 58)
        }
        .background(MythicTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(isHovering ? MythicTheme.accentLight.opacity(0.7) : MythicTheme.border, lineWidth: 1))
        .onHover { isHovering = $0 }
    }

    private var fallbackArtwork: some View {
        ZStack {
            LinearGradient(colors: [MythicTheme.heroTop, MythicTheme.heroBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            EngineLogoView(engine: game.engine, size: 80, color: .white.opacity(0.3))
        }
    }
}
