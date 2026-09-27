import Foundation

struct SteamSearchResult: Identifiable, Hashable {
    let id: Int
    let name: String
    let score: Double
}

struct SteamGameMetadata {
    let appID: Int
    let name: String
    let description: String?
    let libraryHeroURL: URL?
    let backgroundURL: URL?
    let headerURL: URL?
    let developers: [String]
    let releaseDate: String?
}

enum SteamMetadataService {
    private struct SearchResponse: Decodable {
        struct Item: Decodable { let id: Int; let name: String; let type: String? }
        let items: [Item]
    }

    private struct DetailResponse: Decodable {
        struct Entry: Decodable {
            let success: Bool
            let data: Detail?
        }
        struct Detail: Decodable {
            let type: String?
            let name: String
            let steam_appid: Int?
            let short_description: String?
            let background_raw: String?
            let background: String?
            let header_image: String?
            let developers: [String]?
            let release_date: ReleaseDate?
        }
        struct ReleaseDate: Decodable { let date: String? }
        let entries: [Entry]

        private struct DynamicKey: CodingKey {
            let stringValue: String
            let intValue: Int? = nil
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { return nil }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicKey.self)
            entries = container.allKeys.compactMap { try? container.decode(Entry.self, forKey: $0) }
        }
    }

    static func search(_ query: String) async throws -> [SteamSearchResult] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        var collected: [Int: SteamSearchResult] = [:]
        for (language, country) in [("schinese", "CN"), ("english", "US")] {
            var components = URLComponents(string: "https://store.steampowered.com/api/storesearch/")!
            components.queryItems = [
                URLQueryItem(name: "term", value: term),
                URLQueryItem(name: "l", value: language),
                URLQueryItem(name: "cc", value: country)
            ]
            let data = try await fetch(components.url!)
            let items = try JSONDecoder().decode(SearchResponse.self, from: data).items
            for item in items where item.type == nil || item.type == "app" {
                let match = SteamSearchResult(id: item.id, name: item.name, score: similarity(term, item.name))
                if match.score > (collected[item.id]?.score ?? -1) { collected[item.id] = match }
            }
            if collected.values.contains(where: { $0.score == 1 }) { break }
        }
        let candidates = collected.values.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }.prefix(8).map { $0 }
        let games = await withTaskGroup(of: SteamSearchResult?.self) { group in
            for candidate in candidates {
                group.addTask {
                    guard (try? await details(appID: candidate.id)) != nil else { return nil }
                    return candidate
                }
            }
            var results: [SteamSearchResult] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results
        }
        return games.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func details(appID: Int) async throws -> SteamGameMetadata? {
        guard appID > 0 else { return nil }
        for (language, country) in [("schinese", "CN"), ("english", "US")] {
            var components = URLComponents(string: "https://store.steampowered.com/api/appdetails/")!
            components.queryItems = [
                URLQueryItem(name: "appids", value: String(appID)),
                URLQueryItem(name: "l", value: language),
                URLQueryItem(name: "cc", value: country)
            ]
            let data = try await fetch(components.url!)
            let response = try JSONDecoder().decode(DetailResponse.self, from: data)
            guard let detail = response.entries.compactMap({ $0.success ? $0.data : nil }).first,
                  detail.type == "game", detail.steam_appid == appID else { continue }
            let description = detail.short_description.map(plainText)
            return SteamGameMetadata(
                appID: appID,
                name: detail.name,
                description: description?.isEmpty == false ? description : nil,
                libraryHeroURL: URL(string: "https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/\(appID)/library_hero.jpg"),
                backgroundURL: URL(string: detail.background_raw ?? detail.background ?? ""),
                headerURL: URL(string: detail.header_image ?? ""),
                developers: detail.developers ?? [],
                releaseDate: detail.release_date?.date
            )
        }
        return nil
    }

    private static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let a = lhs.lowercased().filter { $0.isLetter || $0.isNumber }
        let b = rhs.lowercased().filter { $0.isLetter || $0.isNumber }
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        if a == b { return 1 }
        if b.hasPrefix(a) || a.hasPrefix(b) { return 0.9 }
        if a.contains(b) || b.contains(a) { return 0.75 }
        let wordsA = Set(lhs.lowercased().split { !$0.isLetter && !$0.isNumber })
        let wordsB = Set(rhs.lowercased().split { !$0.isLetter && !$0.isNumber })
        let union = wordsA.union(wordsB)
        return union.isEmpty ? 0 : Double(wordsA.intersection(wordsB).count) / Double(union.count)
    }

    private static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
