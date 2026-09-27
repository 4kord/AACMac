import XCTest
@testable import AACCore

final class FileHashTests: XCTestCase {
    func testKnownHash() throws {
        let f = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("abc".utf8).write(to: f)
        XCTAssertEqual(try FileHash.sha256(of: f),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
