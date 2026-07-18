import Foundation

public enum AppPaths {
    public static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("ProjectBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public static var configURL: URL {
        applicationSupport.appendingPathComponent("config.json")
    }

    public static var databaseURL: URL {
        applicationSupport.appendingPathComponent("usage.sqlite")
    }

    public static var eventsJSONLURL: URL {
        applicationSupport.appendingPathComponent("hook-events.jsonl")
    }

    public static var cursorProjectsRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor/projects", isDirectory: true)
    }

    public static var cursorHooksJSON: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor/hooks.json")
    }

    public static var cursorHooksDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cursor/hooks", isDirectory: true)
    }

    public static var hookScriptURL: URL {
        cursorHooksDir.appendingPathComponent("projectbar-log.sh")
    }
}
