import SwiftUI
import Gal4MacCore

struct StatisticsView: View {
    let games: [Game]
    let onSelectGame: (Game) -> Void

    private var totalPlaytime: TimeInterval {
        games.reduce(0) { $0 + $1.playtime }
    }

    private var playedGames: [Game] {
        games.filter { $0.playtime > 0 }
    }

    private var mostPlayed: [Game] {
        Array(playedGames.sorted { $0.playtime > $1.playtime }.prefix(5))
    }

    private var recentlyPlayed: [Game] {
        Array(games.filter { $0.lastPlayed != nil }.sorted {
            ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast)
        }.prefix(5))
    }

    private var engineCounts: [(name: String, count: Int)] {
        Dictionary(grouping: games, by: { $0.engine.displayName })
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
    }

    var body: some View {
        if games.isEmpty {
            ContentUnavailableView(
                "还没有统计数据",
                systemImage: "chart.bar.xaxis",
                description: Text("添加或导入游戏后，这里会显示游戏库和游玩记录。")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GalSheetHeader(
                        title: "游戏统计",
                        subtitle: "查看游戏收藏、游玩记录和引擎分布。",
                        symbol: "chart.bar.xaxis"
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                        OverviewTile(title: "收藏游戏", value: "\(games.count)", detail: "款游戏", symbol: "gamecontroller")
                        OverviewTile(title: "累计游玩", value: Game.formatDuration(totalPlaytime), detail: "本机记录", symbol: "clock")
                        OverviewTile(title: "玩过的游戏", value: "\(playedGames.count)", detail: "款有游玩记录", symbol: "checkmark.circle")
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], alignment: .leading, spacing: 14) {
                        mostPlayedSection
                        recentSection
                        engineSection
                    }

                    Text("游玩时长根据 Gal4Mac 记录的启动时间累计。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(28)
                .frame(maxWidth: 1000, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var mostPlayedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("游玩时长排行", systemImage: "trophy")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            if mostPlayed.isEmpty {
                Text("启动游戏后，这里会显示游玩时长排行。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            } else {
                ForEach(Array(mostPlayed.enumerated()), id: \.element.id) { index, game in
                    Button {
                        onSelectGame(game)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 9) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.name)
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                    Text(game.engine.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 6)
                                Text(game.playtimeDescription)
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.primary)
                            }
                            ProgressView(value: game.playtime, total: max(mostPlayed[0].playtime, 1))
                                .tint(GalUITheme.accent)
                                .padding(.leading, 29)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .galSheetCard()
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("最近游玩", systemImage: "clock.arrow.circlepath")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            if recentlyPlayed.isEmpty {
                Text("还没有最近游玩记录。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
            } else {
                ForEach(recentlyPlayed) { game in
                    Button {
                        onSelectGame(game)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "gamecontroller")
                                .foregroundStyle(GalUITheme.accent)
                                .frame(width: 30, height: 30)
                                .background(GalUITheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.name)
                                    .font(.callout.weight(.medium))
                                    .lineLimit(1)
                                Text(game.lastPlayed?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .galSheetCard()
    }

    private var engineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("引擎分布", systemImage: "cpu")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            ForEach(engineCounts, id: \.name) { item in
                HStack(spacing: 10) {
                    Text(item.name)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text("\(item.count)")
                        .font(.callout.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("款")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(item.count), total: Double(max(games.count, 1)))
                    .tint(GalUITheme.accent.opacity(0.8))
            }
        }
        .padding(16)
        .galSheetCard()
    }
}

private struct OverviewTile: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GalUITheme.accent)
                .frame(width: 34, height: 34)
                .background(GalUITheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .padding(15)
        .galSheetCard()
    }
}
