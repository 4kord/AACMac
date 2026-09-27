import XCTest
@testable import AACCore

final class RuntimeInstallerTests: XCTestCase {
    func makeTarball(revision: String) throws -> (URL, RuntimeLock) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let rt = tmp.appendingPathComponent("src/runtime")
        try FileManager.default.createDirectory(at: rt.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try Data("#!/bin/sh\n".utf8).write(to: rt.appendingPathComponent("bin/wine"))
        try Data("\(revision)\n".utf8).write(to: rt.appendingPathComponent("REVISION"))
        let tar = tmp.appendingPathComponent("rt.tar.xz")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        p.arguments = ["-C", tmp.appendingPathComponent("src").path, "-cJf", tar.path, "runtime"]
        try p.run(); p.waitUntilExit()
        let sha = try FileHash.sha256(of: tar)
        return (tar, RuntimeLock(revision: revision, releaseTag: "runtime-\(revision)", asset: "x", sha256: sha, sizeBytes: 0))
    }

    func testInstallsAndReportsRevision() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let paths = AppPaths(root: root, logs: root)
        let (tar, lock) = try makeTarball(revision: "r1")
        let inst = RuntimeInstaller(paths: paths, runner: ProcessRunner())
        XCTAssertNil(inst.installedRevision())
        try await inst.install(tarball: tar, lock: lock)
        XCTAssertEqual(inst.installedRevision(), "r1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.wine.path))
    }

    func testReplacesOlderRuntimeCompletely() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let paths = AppPaths(root: root, logs: root)
        let inst = RuntimeInstaller(paths: paths, runner: ProcessRunner())
        let (t1, l1) = try makeTarball(revision: "r1")
        try await inst.install(tarball: t1, lock: l1)
        try Data("stale".utf8).write(to: paths.runtime.appendingPathComponent("stale.txt"))
        let (t2, l2) = try makeTarball(revision: "r2")
        try await inst.install(tarball: t2, lock: l2)
        XCTAssertEqual(inst.installedRevision(), "r2")
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.runtime.appendingPathComponent("stale.txt").path))
    }

    func testRejectsWrongHash() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let paths = AppPaths(root: root, logs: root)
        let (tar, lock) = try makeTarball(revision: "r1")
        let bad = RuntimeLock(revision: "r1", releaseTag: lock.releaseTag, asset: lock.asset, sha256: String(repeating: "0", count: 64), sizeBytes: 0)
        do { try await RuntimeInstaller(paths: paths, runner: ProcessRunner()).install(tarball: tar, lock: bad); XCTFail() }
        catch { XCTAssertEqual(error as? InstallError, .runtimeHashMismatch) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.runtime.path))
    }
}
