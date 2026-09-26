import Foundation

struct SteamGameMetadata {
    let appID: Int
    let name: String
    let description: String?
    let developers: [String]
    let publishers: [String]
    let releaseDate: String?

}

enum SteamMetadataService {
    private static let knownAliases = [
        "sanoba witch": "Sabbat of the Witch",
        "サノバウィッチ": "Sabbat of the Witch"
    ]

    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            let id: Int
            let name: String
        }
        let items: [Item]
    }

    private struct DetailsResponse: Decodable {
        struct Entry: Decodable {
            let success: Bool
            let data: AppDetails?
        }
        struct AppDetails: Decodable {
            let steamAppID: Int?
            let type: String?
            let name: String
            let short_description: String?
            let developers: [String]?
            let publishers: [String]?
            let release_date: ReleaseDate?

            enum CodingKeys: String, CodingKey {
                case steamAppID = "steam_appid"
                case name, type, short_description, developers, publishers, release_date
            }
        }
        struct ReleaseDate: Decodable {
            let date: String?
        }
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

    static func lookup(names: [String]) async throws -> SteamGameMetadata? {
        var names = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, name in
                if !result.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) { result.append(name) }
            }
        let aliasNames = names.flatMap { name in
            knownAliases.compactMap { alias, steamTitle in
                name.localizedCaseInsensitiveContains(alias) ? steamTitle : nil
            }
        }
        names.append(contentsOf: aliasNames)

        var resolved: (item: SearchResponse.Item, data: DetailsResponse.AppDetails, description: String?)?
        for name in names {
            // Prefer the Chinese Steam catalog, then fall back to the English catalog.
            for (language, country) in [("schinese", "CN"), ("english", "US")] {
                guard let results = try? await search(name: name, language: language, country: country) else { continue }
                let candidates = results.enumerated()
                    .map { (index: $0.offset, item: $0.element, score: similarity(name, $0.element.name)) }
                    .filter { $0.score >= 0.55 }
                    .sorted {
                        if $0.score != $1.score { return $0.score > $1.score }
                        return $0.index < $1.index
                    }

                for candidate in candidates {
                    let chineseDetails = await appDetails(id: candidate.item.id, language: "schinese", country: "CN")
                    let chineseDescription = chineseDetails?.short_description
                        .map(plainText)
                        .flatMap { $0.isEmpty ? nil : $0 }
                    let englishDetails: DetailsResponse.AppDetails?
                    if chineseDetails == nil || chineseDescription == nil {
                        englishDetails = await appDetails(id: candidate.item.id, language: "english", country: "US")
                    } else {
                        englishDetails = nil
                    }
                    guard let data = chineseDetails ?? englishDetails, data.type == "game" else { continue }
                    let description = chineseDescription ?? englishDetails?.short_description.map(plainText)
                    resolved = (candidate.item, data, description)
                    break
                }
                if resolved != nil { break }
            }
            if resolved != nil { break }
        }
        guard let resolved else { return nil }
        return SteamGameMetadata(
            appID: resolved.item.id,
            name: resolved.data.name,
            description: resolved.description,
            developers: resolved.data.developers ?? [],
            publishers: resolved.data.publishers ?? [],
            releaseDate: resolved.data.release_date?.date
        )
    }

    private static func appDetails(id: Int, language: String, country: String) async -> DetailsResponse.AppDetails? {
        var components = URLComponents(string: "https://store.steampowered.com/api/appdetails/")!
        components.queryItems = [
            URLQueryItem(name: "appids", value: String(id)),
            URLQueryItem(name: "l", value: language),
            URLQueryItem(name: "cc", value: country)
        ]
        guard let (responseData, _) = try? await fetch(components.url!),
              let details = try? JSONDecoder().decode(DetailsResponse.self, from: responseData) else { return nil }
        return details.entries.first(where: { $0.success && $0.data?.steamAppID == id })?.data
    }

    private static func search(name: String, language: String, country: String) async throws -> [SearchResponse.Item] {
        var components = URLComponents(string: "https://store.steampowered.com/api/storesearch/")!
        components.queryItems = [
            URLQueryItem(name: "term", value: name),
            URLQueryItem(name: "l", value: language),
            URLQueryItem(name: "cc", value: country)
        ]
        let (data, _) = try await fetch(components.url!)
        return try JSONDecoder().decode(SearchResponse.self, from: data).items
    }

    private static func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        return try await URLSession.shared.data(for: request)
    }

    private static func similarity(_ lhs: String, _ rhs: String) -> Double {
        func normalized(_ value: String) -> String {
            value.lowercased().filter { $0.isLetter || $0.isNumber }
        }
        let a = normalized(lhs)
        let b = normalized(rhs)
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        if a == b { return 1 }
        if b.hasPrefix(a) || a.hasPrefix(b) { return 0.9 }
        if a.contains(b) || b.contains(a) { return 0.75 }
        let aWords = Set(lhs.lowercased().split { !$0.isLetter && !$0.isNumber })
        let bWords = Set(rhs.lowercased().split { !$0.isLetter && !$0.isNumber })
        let union = aWords.union(bWords)
        return union.isEmpty ? 0 : Double(aWords.intersection(bWords).count) / Double(union.count)
    }

    private static func plainText(_ html: String) -> String {
        let withoutTags = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        return withoutTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
