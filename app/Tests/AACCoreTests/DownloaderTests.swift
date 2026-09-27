import XCTest
@testable import AACCore

private final class FakeFetcher: HTTPFetching {
    var payloads: [Data]          // one per call; last one repeats
    var failuresBeforeSuccess = 0
    private(set) var calls = 0
    init(_ payloads: [Data]) { self.payloads = payloads }
    func download(_ url: URL, to dest: URL) async throws {
        calls += 1
        if calls <= failuresBeforeSuccess { throw URLError(.networkConnectionLost) }
        try payloads[min(calls - failuresBeforeSuccess - 1, payloads.count - 1)].write(to: dest)
    }
}

private func sha(_ s: String) -> String {
    let f = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try! Data(s.utf8).write(to: f)
    return try! FileHash.sha256(of: f)
}

final class DownloaderTests: XCTestCase {
    var dir: URL!
    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func testVerifiedDownload() async throws {
        let c = Component(id: "x", url: URL(string: "https://e/x")!, sha256: sha("good"), fileName: "x.bin")
        let f = FakeFetcher([Data("good".utf8)])
        let out = try await Downloader(fetcher: f).fetch(c, into: dir)
        XCTAssertEqual(try String(contentsOf: out), "good")
    }

    func testCachedFileIsReused() async throws {
        let c = Component(id: "x", url: URL(string: "https://e/x")!, sha256: sha("good"), fileName: "x.bin")
        try Data("good".utf8).write(to: dir.appendingPathComponent("x.bin"))
        let f = FakeFetcher([Data("unused".utf8)])
        _ = try await Downloader(fetcher: f).fetch(c, into: dir)
        XCTAssertEqual(f.calls, 0)
    }

    func testCorruptCacheIsReplaced() async throws {
        let c = Component(id: "x", url: URL(string: "https://e/x")!, sha256: sha("good"), fileName: "x.bin")
        try Data("partial".utf8).write(to: dir.appendingPathComponent("x.bin"))
        let f = FakeFetcher([Data("good".utf8)])
        let out = try await Downloader(fetcher: f).fetch(c, into: dir)
        XCTAssertEqual(try String(contentsOf: out), "good")
        XCTAssertEqual(f.calls, 1)
    }

    func testHashMismatchIsAnErrorAndNothingIsKept() async {
        let c = Component(id: "x", url: URL(string: "https://e/x")!, sha256: sha("good"), fileName: "x.bin")
        let f = FakeFetcher([Data("evil".utf8)])
        do { _ = try await Downloader(fetcher: f, attempts: 2).fetch(c, into: dir); XCTFail("expected error") }
        catch { XCTAssertEqual(error as? DownloadError, .hashMismatch(file: "x.bin")) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("x.bin").path))
    }

    func testRetriesNetworkFailures() async throws {
        let c = Component(id: "x", url: URL(string: "https://e/x")!, sha256: sha("good"), fileName: "x.bin")
        let f = FakeFetcher([Data("good".utf8)]); f.failuresBeforeSuccess = 2
        _ = try await Downloader(fetcher: f, attempts: 3).fetch(c, into: dir)
        XCTAssertEqual(f.calls, 3)
    }

    func testUnpinnedInstallerMustBeAnExecutable() async {
        let c = Component(id: "i", url: URL(string: "https://e/i")!, sha256: nil, fileName: "i.exe")
        let f = FakeFetcher([Data("<html>".utf8)])
        do { _ = try await Downloader(fetcher: f).fetch(c, into: dir); XCTFail("expected error") }
        catch { XCTAssertEqual(error as? DownloadError, .notAnExecutable(file: "i.exe")) }
    }

    func testPinnedComponents() {
        XCTAssertEqual(Components.webView2.sha256, "eac95c8095ec5f9971eade9827d8fb67fd251f5c16e702b5312d31067e39119b")
        XCTAssertEqual(Components.directX.sha256, "053f76dcbb28802e23341b6a787e3b0791c0fa5c8d4d011b1044172dbf89c73b")
        XCTAssertNil(Components.installer.sha256)
        XCTAssertEqual(Components.installer.url.host, "patch.aa-classic.com")
    }
}
