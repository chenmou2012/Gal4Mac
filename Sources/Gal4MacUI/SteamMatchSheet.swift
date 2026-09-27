import Gal4MacCore
import SwiftUI

struct SteamMatchSheet: View {
    let game: Game
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var results: [SteamSearchResult] = []
    @State private var selectedID: Int?
    @State private var isSearching = false
    @State private var message: String?
    @State private var searchID = UUID()

    init(game: Game, onSelect: @escaping (Int) -> Void) {
        self.game = game
        self.onSelect = onSelect
        _query = State(initialValue: game.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("匹配 Steam 游戏").font(.title2.weight(.semibold))
            Text("为 \(game.name) 选择正确的 Steam 游戏。确认后即可显示介绍、背景并同步云存档。")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                TextField("搜索游戏名称", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { search() }
                Button("搜索") { search() }.disabled(isSearching)
            }

            if isSearching {
                ProgressView("正在搜索 Steam…").controlSize(.small)
            } else if let message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }

            Picker("游戏", selection: $selectedID) {
                Text("选择游戏…").tag(Int?.none)
                ForEach(results) { result in
                    Text("\(result.name) · AppID \(result.id)").tag(Optional(result.id))
                }
            }
            .frame(maxWidth: .infinity)

            if let selected = results.first(where: { $0.id == selectedID }) {
                Link("在 Steam 查看 \(selected.name)", destination: URL(string: "https://store.steampowered.com/app/\(selected.id)/")!)
                    .font(.caption)
            }

            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("确认匹配") {
                    guard let selectedID else { return }
                    onSelect(selectedID)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedID == nil)
            }
        }
        .padding(24)
        .frame(width: 540, height: 300)
        .background(GlassPalette.background)
        .tint(GlassPalette.blue)
        .task { search(autoSelect: true) }
    }

    private func search(autoSelect: Bool = false) {
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            message = "请输入游戏名称。"
            return
        }
        let token = UUID()
        searchID = token
        selectedID = nil
        isSearching = true
        message = nil
        Task { @MainActor in
            do {
                let matches = try await SteamMetadataService.search(input)
                guard searchID == token else { return }
                results = matches
                if autoSelect, let first = matches.first, first.score >= 0.9 {
                    selectedID = first.id
                }
                if matches.isEmpty { message = "未找到匹配的 Steam 游戏，请换个名称搜索。" }
            } catch {
                guard searchID == token else { return }
                message = "无法连接 Steam：\(error.localizedDescription)"
            }
            if searchID == token { isSearching = false }
        }
    }
}
