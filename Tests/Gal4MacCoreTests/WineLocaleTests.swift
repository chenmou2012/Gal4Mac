import XCTest
@testable import Gal4MacCore

final class WineLocaleTests: XCTestCase {
    func testChineseOverrideReplacesEngineLocaleBeforeWineStarts() throws {
        let game = Game(name: "Chinese KiriKiri", path: URL(fileURLWithPath: "/tmp/game"),
                        executable: "game.exe", engine: .kirikiri, wineLocale: .simplifiedChinese)
        let config = GameLauncher.launchConfig(for: game)
        let environment = EngineManager.launchEnvironment(prefix: URL(fileURLWithPath: "/tmp/prefix"), engineConfig: config)
        XCTAssertEqual(environment["LANG"], "zh_CN.UTF-8")
        XCTAssertEqual(environment["LC_ALL"], "zh_CN.UTF-8")
    }

    func testOldLibraryEntryKeepsAutomaticLocale() throws {
        let game = Game(name: "Japanese KiriKiri", path: URL(fileURLWithPath: "/tmp/game"),
                        executable: "game.exe", engine: .kirikiri)
        let encoded = try JSONEncoder().encode(game)
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        dictionary.removeValue(forKey: "wineLocale")
        let oldData = try JSONSerialization.data(withJSONObject: dictionary)
        let restored = try JSONDecoder().decode(Game.self, from: oldData)
        XCTAssertEqual(restored.wineLocale, .automatic)
        let environment = EngineManager.launchEnvironment(
            prefix: URL(fileURLWithPath: "/tmp/prefix"),
            engineConfig: GameLauncher.launchConfig(for: restored)
        )
        XCTAssertEqual(environment["LANG"], "ja_JP.UTF-8")
    }
}
