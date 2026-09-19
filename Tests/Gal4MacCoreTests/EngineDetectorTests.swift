import XCTest
@testable import Gal4MacCore

final class EngineDetectorTests: XCTestCase {

    let detector = EngineDetector()

    func testUnityDetection() {
        let url = URL(fileURLWithPath: "/Users/chenmou2012/gal4mac/Aokana")
        let engine = detector.detect(at: url)
        XCTAssertEqual(engine, .unity, "Aokana 应该是 Unity 引擎")
    }

    func testSiglusDetection() {
        let url = URL(fileURLWithPath: "/Users/chenmou2012/gal4mac/CLANNAD")
        let engine = detector.detect(at: url)
        XCTAssertEqual(engine, .siglus, "CLANNAD 应该是 SiglusEngine")
    }

    func testUnityExecutable() {
        let url = URL(fileURLWithPath: "/Users/chenmou2012/gal4mac/Aokana")
        let exe = detector.findExecutable(at: url, engine: .unity)
        XCTAssertNotNil(exe, "应该找到 Unity 可执行文件")
        XCTAssertTrue(exe?.contains("Aokana") ?? false)
    }

    func testSiglusExecutable() {
        let url = URL(fileURLWithPath: "/Users/chenmou2012/gal4mac/CLANNAD")
        let exe = detector.findExecutable(at: url, engine: .siglus)
        XCTAssertNotNil(exe)
        XCTAssertTrue(exe?.lowercased().contains("siglus") ?? false)
    }

    func testUnknownEngine() {
        let url = URL(fileURLWithPath: "/tmp")
        let engine = detector.detect(at: url)
        XCTAssertEqual(engine, .unknown)
    }

    func testEngineCompatibility() {
        XCTAssertEqual(EngineType.unity.compatibility, .excellent)
        XCTAssertEqual(EngineType.siglus.compatibility, .excellent)
        XCTAssertEqual(EngineType.kirikiri.compatibility, .good)
    }

    func testUnityLaunchArgs() {
        let args = EngineType.unity.defaultLaunchArgs(width: 1920, height: 1080)
        XCTAssertTrue(args.contains("-screen-fullscreen"))
        XCTAssertTrue(args.contains("1920"))
        XCTAssertTrue(args.contains("1080"))
    }

    func testSiglusLaunchArgs() {
        let args = EngineType.siglus.defaultLaunchArgs(width: 1280, height: 720)
        XCTAssertTrue(args.contains("-window"))
        XCTAssertTrue(args.contains("1280"))
    }
}
