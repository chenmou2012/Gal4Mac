import Foundation

/// 查找 Steam 客户端已经同步到本机的 Cloud 文件。
public struct SteamClientSaves {
    public struct File: Identifiable {
        public let url: URL
        public let account: String
        public let relativePath: String

        public var id: String { url.path }
    }

    private let steamRoots: [URL]

    public init(steamRoots: [URL]? = nil) {
        if let steamRoots {
            self.steamRoots = steamRoots
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let support = home.appendingPathComponent("Library/Application Support", isDirectory: true)
            var roots = [support.appendingPathComponent("Steam", isDirectory: true)]
            let bottles = support.appendingPathComponent("CrossOver/Bottles", isDirectory: true)
            if let contents = try? FileManager.default.contentsOfDirectory(at: bottles, includingPropertiesForKeys: [.isDirectoryKey]) {
                roots += contents.map {
                    $0.appendingPathComponent("drive_c/Program Files (x86)/Steam", isDirectory: true)
                }
            }
            self.steamRoots = roots
        }
    }

    public func files(appID: String) -> [File] {
        guard !appID.isEmpty, appID.allSatisfy({ $0.isASCII && $0.isNumber }) else { return [] }
        let fm = FileManager.default
        var results: [File] = []

        for root in steamRoots {
            let userdata = root.appendingPathComponent("userdata", isDirectory: true)
            guard let accounts = try? fm.contentsOfDirectory(at: userdata, includingPropertiesForKeys: [.isDirectoryKey]) else { continue }
            for account in accounts where account.lastPathComponent.allSatisfy({ $0.isASCII && $0.isNumber }) {
                let remote = account.appendingPathComponent(appID, isDirectory: true)
                    .appendingPathComponent("remote", isDirectory: true)
                guard let enumerator = fm.enumerator(at: remote, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsPackageDescendants]) else { continue }
                while let url = enumerator.nextObject() as? URL {
                    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                          values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                    let relative = String(url.path.dropFirst(remote.path.count + 1))
                    results.append(File(url: url, account: account.lastPathComponent, relativePath: relative))
                }
            }
        }

        return results.sorted { $0.url.path < $1.url.path }
    }
}
