import Foundation

public struct HookPayload: Codable, Sendable {
    public var conversation_id: String?
    public var generation_id: String?
    public var model: String?
    public var workspace_roots: [String]?
    public var cwd: String?
    public var hook_event_name: String?
    public var status: String?
    public var input_tokens: Int?
    public var output_tokens: Int?
    public var total_tokens: Int?
    public var token_usage: TokenUsage?
    public var usage: TokenUsage?

    public struct TokenUsage: Codable, Sendable {
        public var input_tokens: Int?
        public var output_tokens: Int?
        public var total_tokens: Int?
        public var inputTokens: Int?
        public var outputTokens: Int?
        public var totalTokens: Int?
    }
}

public struct HookIngestor: Sendable {
    public init() {}

    public func ingest(payloadJSON: Data, config: AppConfig, store: UsageStore) throws -> Bool {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(HookPayload.self, from: payloadJSON)
        let workspace = resolveWorkspace(payload: payload)
        guard let workspace else { return false }
        guard let project = PathMapping.match(workspacePath: workspace, projects: config.projects) else {
            return false
        }

        let sessionKey = payload.generation_id
            ?? payload.conversation_id
            ?? UUID().uuidString
        let sessionID = "hook:\(sessionKey)"

        let (input, output, total, estimated) = resolveTokens(payload: payload)
        let now = Date()

        let event = UsageEvent(
            projectID: project.projectID,
            workspacePath: project.path,
            source: .hook,
            startedAt: now,
            endedAt: now,
            inputTokens: input,
            outputTokens: output,
            totalTokens: total,
            estimated: estimated,
            model: payload.model,
            sessionID: sessionID
        )
        return try store.upsert(event)
    }

    public func ingestJSONLLine(_ line: String, config: AppConfig, store: UsageStore) throws -> Bool {
        guard let data = line.data(using: .utf8) else { return false }
        return try ingest(payloadJSON: data, config: config, store: store)
    }

    private func resolveWorkspace(payload: HookPayload) -> String? {
        if let roots = payload.workspace_roots, let first = roots.first, !first.isEmpty {
            return first
        }
        if let cwd = payload.cwd, !cwd.isEmpty {
            return cwd
        }
        return FileManager.default.currentDirectoryPath
    }

    private func resolveTokens(payload: HookPayload) -> (Int?, Int?, Int, Bool) {
        let usage = payload.token_usage ?? payload.usage
        let input = payload.input_tokens ?? usage?.input_tokens ?? usage?.inputTokens
        let output = payload.output_tokens ?? usage?.output_tokens ?? usage?.outputTokens
        let total = payload.total_tokens ?? usage?.total_tokens ?? usage?.totalTokens

        if let total {
            return (input, output, total, false)
        }
        if input != nil || output != nil {
            return (input, output, (input ?? 0) + (output ?? 0), false)
        }
        // No token fields — record a minimal activity pulse (1k estimated tokens)
        // so sessions still show up until Cursor exposes usage in hooks.
        return (nil, nil, 1000, true)
    }
}
