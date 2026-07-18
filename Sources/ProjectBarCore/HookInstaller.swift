import Foundation

public struct HookInstallResult: Sendable {
    public var hooksJSONPath: String
    public var scriptPath: String
    public var ingestBinaryPath: String?
    public var mergedExisting: Bool

    public init(hooksJSONPath: String, scriptPath: String, ingestBinaryPath: String?, mergedExisting: Bool) {
        self.hooksJSONPath = hooksJSONPath
        self.scriptPath = scriptPath
        self.ingestBinaryPath = ingestBinaryPath
        self.mergedExisting = mergedExisting
    }
}

public enum HookInstaller {
    public static let marker = "projectbar-log"

    public static func install(ingestBinaryURL: URL?) throws -> HookInstallResult {
        let fm = FileManager.default
        try fm.createDirectory(at: AppPaths.cursorHooksDir, withIntermediateDirectories: true)

        let scriptURL = AppPaths.hookScriptURL
        let binaryPath = ingestBinaryURL?.path
            ?? defaultIngestPath()
        let script = makeScript(ingestPath: binaryPath)
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let hooksURL = AppPaths.cursorHooksJSON
        var merged = false
        var root: [String: Any] = ["version": 1, "hooks": [String: Any]()]

        if fm.fileExists(atPath: hooksURL.path),
           let data = try? Data(contentsOf: hooksURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = obj
            merged = true
        }

        var hooks = (root["hooks"] as? [String: Any]) ?? [:]
        let commandEntry: [String: Any] = [
            "command": "./hooks/projectbar-log.sh"
        ]

        for event in ["sessionStart", "sessionEnd", "stop", "subagentStop"] {
            var list = (hooks[event] as? [[String: Any]]) ?? []
            list.removeAll { entry in
                (entry["command"] as? String)?.contains(marker) == true
            }
            list.append(commandEntry)
            hooks[event] = list
        }
        root["version"] = root["version"] ?? 1
        root["hooks"] = hooks

        let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: hooksURL, options: .atomic)

        return HookInstallResult(
            hooksJSONPath: hooksURL.path,
            scriptPath: scriptURL.path,
            ingestBinaryPath: binaryPath,
            mergedExisting: merged
        )
    }

    public static func uninstall() throws {
        let fm = FileManager.default
        let hooksURL = AppPaths.cursorHooksJSON
        if fm.fileExists(atPath: hooksURL.path),
           let data = try? Data(contentsOf: hooksURL),
           var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var hooks = root["hooks"] as? [String: Any] {
            for event in ["sessionStart", "sessionEnd", "stop", "subagentStop"] {
                if var list = hooks[event] as? [[String: Any]] {
                    list.removeAll { ($0["command"] as? String)?.contains(marker) == true }
                    if list.isEmpty {
                        hooks.removeValue(forKey: event)
                    } else {
                        hooks[event] = list
                    }
                }
            }
            root["hooks"] = hooks
            let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try out.write(to: hooksURL, options: .atomic)
        }
        if fm.fileExists(atPath: AppPaths.hookScriptURL.path) {
            try fm.removeItem(at: AppPaths.hookScriptURL)
        }
    }

    public static func isInstalled() -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: AppPaths.hookScriptURL.path),
              fm.fileExists(atPath: AppPaths.cursorHooksJSON.path),
              let data = try? Data(contentsOf: AppPaths.cursorHooksJSON),
              let text = String(data: data, encoding: .utf8) else {
            return false
        }
        return text.contains(marker)
    }

    private static func defaultIngestPath() -> String {
        let candidates = [
            "/usr/local/bin/projectbar-ingest",
            NSHomeDirectory() + "/.local/bin/projectbar-ingest",
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("projectbar-ingest")
                .path,
            FileManager.default.currentDirectoryPath + "/.build/release/projectbar-ingest",
            FileManager.default.currentDirectoryPath + "/.build/debug/projectbar-ingest"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return NSHomeDirectory() + "/.local/bin/projectbar-ingest"
    }

    private static func makeScript(ingestPath: String) -> String {
        """
        #!/bin/bash
        # projectbar-log — forward Cursor hook JSON to ProjectBar
        set -euo pipefail
        INGEST="\(ingestPath)"
        if [[ ! -x "$INGEST" ]]; then
          for candidate in \\
            "$HOME/.local/bin/projectbar-ingest" \\
            /usr/local/bin/projectbar-ingest \\
            "$(pwd)/.build/release/projectbar-ingest" \\
            "$(pwd)/.build/debug/projectbar-ingest"
          do
            if [[ -x "$candidate" ]]; then
              INGEST="$candidate"
              break
            fi
          done
        fi
        if [[ ! -x "$INGEST" ]]; then
          # Fail open: never block the agent
          exit 0
        fi
        "$INGEST" hook-event || true
        exit 0
        """
    }
}
