import AppKit
import CryptoKit
import SwiftUI

struct CachedArtworkImage<Placeholder: View>: View {
    let url: URL
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: NSImage?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .task(id: url) {
            image = nil
            guard let data = try? await ArtworkDiskCache.shared.data(for: url) else { return }
            guard !Task.isCancelled else { return }
            image = NSImage(data: data)
        }
    }
}

private actor ArtworkDiskCache {
    static let shared = ArtworkDiskCache()

    private let directory: URL

    private init() {
        directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "Gal4Mac/Artwork", directoryHint: .isDirectory)
    }

    func data(for url: URL) async throws -> Data {
        let fileURL = directory.appending(path: Self.filename(for: url))
        if let cachedData = try? Data(contentsOf: fileURL), !cachedData.isEmpty {
            return cachedData
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let response = response as? HTTPURLResponse,
           !(200..<300).contains(response.statusCode) {
            throw URLError(.badServerResponse)
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        return data
    }

    private static func filename(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".image"
    }
}
