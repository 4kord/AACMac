import Foundation

public protocol HTTPFetching {
    func download(_ url: URL, to dest: URL) async throws
}

public struct URLSessionFetcher: HTTPFetching {
    public init() {}
    public func download(_ url: URL, to dest: URL) async throws {
        let (tmp, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
    }
}

public enum DownloadError: Error, Equatable {
    case hashMismatch(file: String)
    case notAnExecutable(file: String)
    case failed(url: URL, attempts: Int)
}

public struct Downloader {
    let fetcher: HTTPFetching
    let attempts: Int

    public init(fetcher: HTTPFetching = URLSessionFetcher(), attempts: Int = 3) {
        self.fetcher = fetcher
        self.attempts = attempts
    }

    public func fetch(_ c: Component, into dir: URL) async throws -> URL {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(c.fileName)
        if let sha = c.sha256, FileManager.default.fileExists(atPath: dest.path),
           (try? FileHash.sha256(of: dest)) == sha {
            return dest
        }
        try? FileManager.default.removeItem(at: dest)

        var lastError: Error?
        for _ in 0..<attempts {
            do {
                try await fetcher.download(c.url, to: dest)
                try verify(c, dest)
                return dest
            } catch let e as DownloadError {
                try? FileManager.default.removeItem(at: dest)
                lastError = e
            } catch {
                try? FileManager.default.removeItem(at: dest)
                lastError = error
            }
        }
        if let e = lastError as? DownloadError { throw e }
        throw DownloadError.failed(url: c.url, attempts: attempts)
    }

    private func verify(_ c: Component, _ file: URL) throws {
        if let sha = c.sha256 {
            guard try FileHash.sha256(of: file) == sha else { throw DownloadError.hashMismatch(file: c.fileName) }
        } else {
            let head = try FileHandle(forReadingFrom: file).read(upToCount: 2) ?? Data()
            guard head == Data("MZ".utf8) else { throw DownloadError.notAnExecutable(file: c.fileName) }
        }
    }
}
