import Foundation

public enum PathMapping {
    /// Encode an absolute path the way Cursor names `~/.cursor/projects/<slug>`.
    public static func cursorSlug(forPath path: String) -> String {
        let normalized = (path as NSString).standardizingPath
        var slug = normalized
        if slug.hasPrefix("/") {
            slug.removeFirst()
        }
        return slug
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }

    public static func cursorProjectDirectory(forPath path: String, under root: URL = AppPaths.cursorProjectsRoot) -> URL {
        root.appendingPathComponent(cursorSlug(forPath: path), isDirectory: true)
    }

    /// Find allowlisted project that owns `workspacePath` (exact or nested).
    public static func match(workspacePath: String, projects: [AllowlistedProject]) -> AllowlistedProject? {
        let normalized = (workspacePath as NSString).standardizingPath
        let sorted = projects.sorted { $0.path.count > $1.path.count }
        for project in sorted {
            if normalized == project.path || normalized.hasPrefix(project.path + "/") {
                return project
            }
        }
        // Also accept Cursor slug-style workspace ids passed as paths
        for project in sorted {
            let slug = cursorSlug(forPath: project.path)
            if normalized.hasSuffix(slug) || normalized.contains(slug) {
                return project
            }
        }
        return nil
    }

    public static func resolveWorkspaceFromCursorDirName(_ dirName: String, projects: [AllowlistedProject]) -> AllowlistedProject? {
        for project in projects {
            if cursorSlug(forPath: project.path) == dirName {
                return project
            }
        }
        return nil
    }
}
