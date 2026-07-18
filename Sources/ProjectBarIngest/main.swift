import Foundation
import ProjectBarCore

@main
struct ProjectBarIngest {
    static func main() async {
        let args = Array(CommandLine.arguments.dropFirst())
        do {
            try await run(args: args)
        } catch {
            fputs("error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    static func run(args: [String]) async throws {
        guard let command = args.first else {
            printUsage()
            exit(2)
        }

        switch command {
        case "backfill":
            let config = ConfigStore().load()
            let store = try UsageStore()
            let result = try BackfillScanner().run(projects: config.projects, store: store)
            print("scanned=\(result.scannedFiles) inserted=\(result.insertedEvents) skipped=\(result.skippedDuplicates)")
            if !result.errors.isEmpty {
                for err in result.errors.prefix(20) {
                    fputs("warn: \(err)\n", stderr)
                }
            }

        case "hook-event":
            let data = FileHandle.standardInput.readDataToEndOfFile()
            guard !data.isEmpty else { exit(0) }
            // Also append raw line for debugging
            appendJSONL(data)
            let config = ConfigStore().load()
            let store = try UsageStore()
            _ = try HookIngestor().ingest(payloadJSON: data, config: config, store: store)
            // Always succeed (fail open)
            exit(0)

        case "status":
            let config = ConfigStore().load()
            let store = try UsageStore()
            let summaries = try store.summarize(projects: config.projects)
            for s in summaries.sorted(by: { $0.tokens30d > $1.tokens30d }) {
                let flag = s.mostlyEstimated ? " (estimated)" : ""
                print("\(s.project.name)\ttoday=\(CostCalculator.formatTokens(s.tokensToday))\t30d=\(CostCalculator.formatTokens(s.tokens30d))\(flag)")
            }

        case "install-hooks":
            let result = try HookInstaller.install(ingestBinaryURL: resolveSelfURL())
            print("installed hooks -> \(result.hooksJSONPath)")
            print("script -> \(result.scriptPath)")
            if let bin = result.ingestBinaryPath {
                print("ingest -> \(bin)")
            }

        case "uninstall-hooks":
            try HookInstaller.uninstall()
            print("uninstalled ProjectBar hooks")

        case "help", "-h", "--help":
            printUsage()

        default:
            fputs("unknown command: \(command)\n", stderr)
            printUsage()
            exit(2)
        }
    }

    static func printUsage() {
        print(
            """
            projectbar-ingest — ProjectBar usage ingest CLI

            Usage:
              projectbar-ingest backfill
              projectbar-ingest hook-event   # reads Cursor hook JSON from stdin
              projectbar-ingest status
              projectbar-ingest install-hooks
              projectbar-ingest uninstall-hooks
            """
        )
    }

    static func appendJSONL(_ data: Data) {
        let url = AppPaths.eventsJSONLURL
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
        if !data.hasSuffix(contentsOf: Data([0x0A])) {
            try? handle.write(contentsOf: Data([0x0A]))
        }
    }

    static func resolveSelfURL() -> URL? {
        URL(fileURLWithPath: CommandLine.arguments[0]).absoluteURL
    }
}

private extension Data {
    func hasSuffix(contentsOf other: Data) -> Bool {
        guard count >= other.count else { return false }
        return suffix(other.count) == other
    }
}
