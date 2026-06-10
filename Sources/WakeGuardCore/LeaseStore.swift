import Foundation

public struct LeaseStore {
    public let url: URL

    public init(url: URL = URL(fileURLWithPath: Lease.defaultPath)) {
        self.url = url
    }

    public func write(_ lease: Lease) throws {
        let encoder = JSONEncoder()
        // .iso8601 truncates to whole seconds — fine for a 30s TTL, and always rounds toward expiry.
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(lease)
        try data.write(to: url, options: .atomic)
    }

    /// Any read problem (missing, unreadable, malformed) is nil — and nil
    /// always means "do not keep the Mac awake".
    public func read() -> Lease? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Lease.self, from: data)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
