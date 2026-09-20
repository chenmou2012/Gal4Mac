import SwiftUI
import Gal4MacCore

/// 游戏卡片
struct GameCardView: View {
    let game: Game
    @EnvironmentObject var library: GameLibraryViewModel
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 封面区域
            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack {
                    Image(systemName: iconName)
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(game.name.prefix(2).uppercased())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 信息区域
            VStack(alignment: .leading, spacing: 6) {
                Text(game.name)
                    .font(.system(.headline))
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 4) {
                    Text(game.engine.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    StarRatingDisplay(rating: game.rating)
                }

                HStack {
                    Text(game.sizeDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if game.playtime > 0 {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(game.playtimeDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .help("累计游戏时长")
                    }
                    Spacer()
                    if !library.isAccessible(game.path) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help("游戏路径不可访问")
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            // 启动按钮
            Button {
                library.launch(game)
            } label: {
                HStack {
                    if library.launchingGameId == game.id {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(library.launchingGameId == game.id ? "启动中…" : "启动")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(library.launchingGameId != nil || !library.isAccessible(game.path))
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHovering ? Color.accentColor : Color.gray.opacity(0.2),
                              lineWidth: isHovering ? 2 : 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button {
                library.launch(game)
            } label: {
                Label("启动", systemImage: "play.fill")
            }
            Button {
                library.showingSavesFor = game
            } label: {
                Label("存档管理", systemImage: "tray.full")
            }
            Divider()
            Button {
                library.updateRating(for: game, rating: 5)
            } label: {
                Label("标记为完美运行", systemImage: "star.fill")
            }
            Button {
                library.updateRating(for: game, rating: 0)
            } label: {
                Label("清除评分", systemImage: "star.slash")
            }
            Divider()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([game.path])
            } label: {
                Label("在 Finder 中显示", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) {
                library.removeGame(game)
            } label: {
                Label("从库中移除", systemImage: "trash")
            }
        }
    }

    // 根据引擎类型返回不同的颜色主题
    private var gradientColors: [Color] {
        switch game.engine {
        case .unity:
            return [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.1, green: 0.3, blue: 0.6)]
        case .siglus:
            return [Color(red: 0.9, green: 0.3, blue: 0.5), Color(red: 0.6, green: 0.1, blue: 0.3)]
        case .kirikiri:
            return [Color(red: 0.4, green: 0.7, blue: 0.4), Color(red: 0.2, green: 0.5, blue: 0.2)]
        case .tyranoScript:
            return [Color(red: 0.9, green: 0.6, blue: 0.2), Color(red: 0.7, green: 0.4, blue: 0.1)]
        case .renpy:
            return [Color(red: 0.5, green: 0.4, blue: 0.8), Color(red: 0.3, green: 0.2, blue: 0.6)]
        case .realLive, .nscripter:
            return [Color(red: 0.6, green: 0.5, blue: 0.3), Color(red: 0.4, green: 0.3, blue: 0.1)]
        case .yuris, .artemis:
            return [Color(red: 0.7, green: 0.3, blue: 0.7), Color(red: 0.4, green: 0.1, blue: 0.4)]
        default:
            return [Color.gray.opacity(0.6), Color.gray.opacity(0.3)]
        }
    }

    private var iconName: String {
        switch game.engine {
        case .unity: return "cube.fill"
        case .siglus: return "sparkles"
        case .kirikiri: return "scroll.fill"
        case .tyranoScript: return "globe"
        case .renpy: return "text.book.closed.fill"
        case .realLive, .nscripter: return "doc.text.fill"
        case .yuris, .artemis: return "moon.stars.fill"
        default: return "gamecontroller.fill"
        }
    }
}
