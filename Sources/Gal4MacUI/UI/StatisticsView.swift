import Charts
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

    private var averagePlaytime: TimeInterval {
        guard !playedGames.isEmpty else { return 0 }
        return totalPlaytime / Double(playedGames.count)
    }

    private var maximumPlaytimeInMinutes: Double {
        max(mostPlayed.first?.playtime ?? 0, 60) / 60
    }

    private let dashboardColumns = [
        GridItem(.adaptive(minimum: 330, maximum: 520), spacing: 16, alignment: .top)
    ]

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
                VStack(alignment: .leading, spacing: 22) {
                    dashboardHeader

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 132, maximum: 260), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        DashboardMetric(
                            title: "收藏游戏",
                            value: "\(games.count)",
                            unit: "款",
                            detail: "游戏库总数",
                            symbol: "gamecontroller.fill",
                            color: GalUITheme.accent
                        )
                        DashboardMetric(
                            title: "累计游玩",
                            value: Game.formatDuration(totalPlaytime),
                            unit: "",
                            detail: "所有游戏时长",
                            symbol: "clock.fill",
                            color: Color(red: 0.30, green: 0.70, blue: 0.98)
                        )
                        DashboardMetric(
                            title: "已体验",
                            value: "\(playedGames.count)",
                            unit: "款",
                            detail: "有游玩记录",
                            symbol: "checkmark.seal.fill",
                            color: Color(red: 0.30, green: 0.78, blue: 0.62)
                        )
                        DashboardMetric(
                            title: "平均时长",
                            value: Game.formatDuration(averagePlaytime),
                            unit: "",
                            detail: "每款已玩游戏",
                            symbol: "timer",
                            color: Color(red: 0.98, green: 0.66, blue: 0.32)
                        )
                    }

                    LazyVGrid(columns: dashboardColumns, alignment: .leading, spacing: 16) {
                        playtimeChart
                        recentActivity
                        engineDistribution
                    }

                    Label("统计依据 Gal4Mac 在本机记录的启动时间与游戏库信息。", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 1)
                }
                .padding(26)
                .frame(maxWidth: 1120, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var dashboardHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(GalUITheme.accent)
                .frame(width: 52, height: 52)
                .background(GalUITheme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("LIBRARY OVERVIEW")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(GalUITheme.accent.opacity(0.9))
                Text("统计看板")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("收藏、游玩与引擎概况")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Label("本机数据", systemImage: "externaldrive.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
        }
        .accessibilityElement(children: .combine)
    }

    private var playtimeChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardSectionHeader(
                title: "游玩时长排行",
                subtitle: "累计时长 · 前五名",
                symbol: "trophy.fill",
                color: Color(red: 0.98, green: 0.72, blue: 0.30)
            )

            if mostPlayed.isEmpty {
                DashboardEmptyNote(symbol: "chart.bar", text: "启动游戏后，这里会显示游玩时长排行。")
            } else {
                Chart(mostPlayed) { game in
                    BarMark(
                        x: .value("游玩分钟", game.playtime / 60),
                        y: .value("游戏", game.displayName)
                    )
                    .foregroundStyle(GalUITheme.accent.gradient)
                    .cornerRadius(5)
                    .annotation(position: .trailing, alignment: .center, spacing: 7) {
                        Text(game.playtimeDescription)
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
                .chartXScale(domain: 0...(maximumPlaytimeInMinutes * 1.6))
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                            .foregroundStyle(Color.primary.opacity(0.10))
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text(minutes.formatted(.number.precision(.fractionLength(0))))
                                    .foregroundStyle(Color.primary.opacity(0.48))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let name = value.as(String.self) {
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(Color.primary.opacity(0.72))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .chartXAxisLabel("分钟", alignment: .trailing)
                .chartLegend(.hidden)
                .frame(height: CGFloat(max(mostPlayed.count, 1)) * 42)
                .accessibilityLabel("游玩时长排行图表，共 \(mostPlayed.count) 款游戏")
            }
        }
        .dashboardCard()
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 15) {
            DashboardSectionHeader(
                title: "最近游玩",
                subtitle: "最近记录的游戏",
                symbol: "clock.arrow.circlepath",
                color: Color(red: 0.30, green: 0.70, blue: 0.98)
            )

            if recentlyPlayed.isEmpty {
                DashboardEmptyNote(symbol: "calendar.badge.clock", text: "还没有最近游玩记录。")
            } else {
                VStack(spacing: 2) {
                    ForEach(recentlyPlayed) { game in
                        Button {
                            onSelectGame(game)
                        } label: {
                            HStack(spacing: 11) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(GalUITheme.accent)
                                    .frame(width: 34, height: 34)
                                    .background(GalUITheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(game.displayName)
                                        .font(.callout.weight(.medium))
                                        .lineLimit(1)
                                    Label(
                                        game.lastPlayed?.formatted(date: .abbreviated, time: .shortened) ?? "",
                                        systemImage: "calendar"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                }

                                Spacer(minLength: 4)

                                Text(game.playtimeDescription)
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("打开 \(game.displayName) 详情")
                    }
                }
            }
        }
        .dashboardCard()
    }

    private var engineDistribution: some View {
        VStack(alignment: .leading, spacing: 16) {
            DashboardSectionHeader(
                title: "引擎分布",
                subtitle: "游戏库检测到的引擎",
                symbol: "cpu.fill",
                color: Color(red: 0.68, green: 0.51, blue: 0.96)
            )

            HStack(spacing: 18) {
                Chart(Array(engineCounts.enumerated()), id: \.element.name) { index, item in
                    SectorMark(
                        angle: .value("游戏数量", item.count),
                        innerRadius: .ratio(0.68),
                        outerRadius: .ratio(0.96),
                        angularInset: 2
                    )
                    .foregroundStyle(GalUITheme.chartPalette[index % GalUITheme.chartPalette.count])
                }
                .chartLegend(.hidden)
                .frame(width: 142, height: 142)
                .overlay {
                    VStack(spacing: 1) {
                        Text("\(games.count)")
                            .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                        Text("款游戏")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("游戏引擎分布")

                VStack(alignment: .leading, spacing: 11) {
                    ForEach(Array(engineCounts.enumerated()), id: \.element.name) { index, item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(GalUITheme.chartPalette[index % GalUITheme.chartPalette.count])
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 5)
                            Text("\(item.count)")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .dashboardCard()
    }
}

private struct DashboardMetric: View {
    let title: String
    let value: String
    let unit: String
    let detail: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 34, height: 34)
                    .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 25, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Label(detail, systemImage: "arrow.up.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
        .padding(13)
        .galSheetCard(cornerRadius: 15)
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardSectionHeader: View {
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 31, height: 31)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct DashboardEmptyNote: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
    }
}

private extension View {
    func dashboardCard(cornerRadius: CGFloat = 16) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .galSheetCard(cornerRadius: cornerRadius)
    }
}
