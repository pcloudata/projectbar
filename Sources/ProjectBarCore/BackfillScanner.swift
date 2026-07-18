import Foundation

public struct BackfillResult: Sendable {
    public var scannedFiles: Int
    public var insertedEvents: Int
    public var skippedDuplicates: Int
    public var errors: [String]

    public init(scannedFiles: Int = 0, insertedEvents: Int = 0, skippedDuplicates: Int = 0, errors: [String] = []) {
        self.scannedFiles = scannedFiles
        self.insertedEvents = insertedEvents
        self.skippedDuplicates = skippedDuplicates
        self.errors = errors
    }
}

public struct BackfillScanner {
    public var projectsRoot: URL

    public init(projectsRoot: URL = AppPaths.cursorProjectsRoot) {
        self.projectsRoot = projectsRoot
    }

    public func run(projects: [AllowlistedProject], store: UsageStore) throws -> BackfillResult {
        var result = BackfillResult()
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: projectsRoot.path) else {
            result.errors.append("Cursor projects root missing: \(projectsRoot.path)")
            return result
        }

        for project in projects {
            let cursorDir = PathMapping.cursorProjectDirectory(forPath: project.path, under: projectsRoot)
            let transcriptsDir = cursorDir.appendingPathComponent("agent-transcripts", isDirectory: true)
            guard fileManager.fileExists(atPath: transcriptsDir.path) else { continue }

            let files = jsonlFiles(under: transcriptsDir, fileManager: fileManager)
            for fileURL in files {
                result.scannedFiles += 1
                do {
                    let event = try parseTranscript(
                        at: fileURL,
                        project: project,
                        fileManager: fileManager
                    )
                    if let event {
                        let inserted = try store.upsert(event)
                        if inserted {
                            result.insertedEvents += 1
                        } else {
                            result.skippedDuplicates += 1
                        }
                    }
                } catch {
                    result.errors.append("\(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
        return result
    }

    private func jsonlFiles(under directory: URL, fileManager: FileManager) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator {
            if url.pathExtension == "jsonl" {
                files.append(url)
            }
        }
        return files
    }

    private func parseTranscript(at url: URL, project: AllowlistedProject, fileManager: FileManager) throws -> UsageEvent? {
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(whereSeparator: \.isNewline)

        var explicitInput: Int?
        var explicitOutput: Int?
        var explicitTotal: Int?
        var model: String?
        var earliest: Date?
        var latest: Date?
        var charCount = 0

        for line in lines {
            let raw = String(line)
            charCount += raw.utf8.count
            guard let lineData = raw.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }
            extractUsage(from: obj, input: &explicitInput, output: &explicitOutput, total: &explicitTotal, model: &model)
            if let ts = extractDate(from: obj) {
                if earliest == nil || ts < earliest! { earliest = ts }
                if latest == nil || ts > latest! { latest = ts }
            }
        }

        let attrs = try fileManager.attributesOfItem(atPath: url.path)
        let fileDate = (attrs[.modificationDate] as? Date) ?? Date()
        let started = earliest ?? fileDate
        let ended = latest ?? fileDate

        let sessionID = sessionID(from: url)
        let hasExplicit = explicitTotal != nil || explicitInput != nil || explicitOutput != nil
        let total: Int
        let estimated: Bool
        if hasExplicit {
            total = explicitTotal ?? ((explicitInput ?? 0) + (explicitOutput ?? 0))
            estimated = false
        } else {
            total = TokenEstimator.estimateTokens(fromCharacterCount: charCount)
            estimated = true
        }

        return UsageEvent(
            projectID: project.projectID,
            workspacePath: project.path,
            source: .backfill,
            startedAt: started,
            endedAt: ended,
            inputTokens: explicitInput,
            outputTokens: explicitOutput,
            totalTokens: total,
            estimated: estimated,
            model: model,
            sessionID: sessionID
        )
    }

    private func sessionID(from url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        // Prefer parent folder name when file is nested as <uuid>/<uuid>.jsonl
        let parent = url.deletingLastPathComponent().lastPathComponent
        if parent.count >= 8 && parent != "agent-transcripts" && parent != "subagents" {
            return "backfill:\(parent)"
        }
        return "backfill:\(name)"
    }

    private func extractUsage(
        from obj: [String: Any],
        input: inout Int?,
        output: inout Int?,
        total: inout Int?,
        model: inout String?
    ) {
        func dig(_ value: Any?) {
            guard let dict = value as? [String: Any] else { return }
            if let m = dict["model"] as? String, model == nil { model = m }
            if let usage = dict["usage"] as? [String: Any] {
                readTokenMap(usage, input: &input, output: &output, total: &total)
            }
            if let usage = dict["tokenUsage"] as? [String: Any] {
                readTokenMap(usage, input: &input, output: &output, total: &total)
            }
            for key in ["inputTokens", "input_tokens", "promptTokens", "prompt_tokens"] {
                if let v = intValue(dict[key]) { input = (input ?? 0) + v }
            }
            for key in ["outputTokens", "output_tokens", "completionTokens", "completion_tokens"] {
                if let v = intValue(dict[key]) { output = (output ?? 0) + v }
            }
            for key in ["totalTokens", "total_tokens", "tokens"] {
                if let v = intValue(dict[key]) { total = (total ?? 0) + v }
            }
            for nested in dict.values {
                if nested is [String: Any] { dig(nested) }
                if let arr = nested as? [Any] {
                    for item in arr { dig(item) }
                }
            }
        }
        dig(obj)
    }

    private func readTokenMap(
        _ map: [String: Any],
        input: inout Int?,
        output: inout Int?,
        total: inout Int?
    ) {
        if let v = intValue(map["inputTokens"] ?? map["input_tokens"] ?? map["prompt_tokens"]) {
            input = (input ?? 0) + v
        }
        if let v = intValue(map["outputTokens"] ?? map["output_tokens"] ?? map["completion_tokens"]) {
            output = (output ?? 0) + v
        }
        if let v = intValue(map["totalTokens"] ?? map["total_tokens"] ?? map["total"]) {
            total = (total ?? 0) + v
        }
    }

    private func intValue(_ any: Any?) -> Int? {
        switch any {
        case let i as Int: return i
        case let i as Int64: return Int(i)
        case let n as NSNumber: return n.intValue
        case let d as Double: return Int(d)
        case let s as String: return Int(s)
        default: return nil
        }
    }

    private func extractDate(from obj: [String: Any]) -> Date? {
        for key in ["timestamp", "createdAt", "created_at", "time", "ts"] {
            if let v = obj[key] {
                if let d = v as? Double { return Date(timeIntervalSince1970: d > 1_000_000_000_000 ? d / 1000 : d) }
                if let i = v as? Int {
                    let d = Double(i)
                    return Date(timeIntervalSince1970: d > 1_000_000_000_000 ? d / 1000 : d)
                }
                if let s = v as? String {
                    if let d = ISO8601DateFormatter().date(from: s) { return d }
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let d = f.date(from: s) { return d }
                }
            }
        }
        return nil
    }
}
