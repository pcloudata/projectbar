import Foundation

public final class ConfigStore: @unchecked Sendable {
    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    public init(url: URL = AppPaths.configURL) {
        self.url = url
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() -> AppConfig {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: url.path) else {
            let config = AppConfig()
            try? persistLocked(config)
            return config
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            let config = AppConfig()
            try? persistLocked(config)
            return config
        }
    }

    public func save(_ config: AppConfig) throws {
        lock.lock()
        defer { lock.unlock() }
        try persistLocked(config)
    }

    private func persistLocked(_ config: AppConfig) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }
}
