import Foundation
import SQLite3

public final class UsageStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()
    private let path: String

    public init(databaseURL: URL = AppPaths.databaseURL) throws {
        self.path = databaseURL.path
        let dir = databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try open()
        try migrate()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    private func open() throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw UsageStoreError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
    }

    private func migrate() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS usage_events (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            workspace_path TEXT NOT NULL,
            source TEXT NOT NULL,
            started_at REAL NOT NULL,
            ended_at REAL,
            input_tokens INTEGER,
            output_tokens INTEGER,
            total_tokens INTEGER,
            estimated INTEGER NOT NULL DEFAULT 0,
            model TEXT,
            session_id TEXT
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_usage_session_source
            ON usage_events(session_id, source)
            WHERE session_id IS NOT NULL;
        CREATE INDEX IF NOT EXISTS idx_usage_project_started
            ON usage_events(project_id, started_at);
        """
        try exec(sql)
    }

    @discardableResult
    public func upsert(_ event: UsageEvent) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let sessionID = event.sessionID {
            if try eventExists(sessionID: sessionID, source: event.source) {
                return false
            }
        }

        let sql = """
        INSERT INTO usage_events (
            id, project_id, workspace_path, source, started_at, ended_at,
            input_tokens, output_tokens, total_tokens, estimated, model, session_id
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            ended_at=excluded.ended_at,
            input_tokens=excluded.input_tokens,
            output_tokens=excluded.output_tokens,
            total_tokens=excluded.total_tokens,
            estimated=excluded.estimated,
            model=excluded.model;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw UsageStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, event.id)
        bindText(stmt, 2, event.projectID)
        bindText(stmt, 3, event.workspacePath)
        bindText(stmt, 4, event.source.rawValue)
        sqlite3_bind_double(stmt, 5, event.startedAt.timeIntervalSince1970)
        if let ended = event.endedAt {
            sqlite3_bind_double(stmt, 6, ended.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(stmt, 6)
        }
        bindOptionalInt(stmt, 7, event.inputTokens)
        bindOptionalInt(stmt, 8, event.outputTokens)
        bindOptionalInt(stmt, 9, event.totalTokens)
        sqlite3_bind_int(stmt, 10, event.estimated ? 1 : 0)
        bindOptionalText(stmt, 11, event.model)
        bindOptionalText(stmt, 12, event.sessionID)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw UsageStoreError.stepFailed(errmsg())
        }
        return true
    }

    public func events(
        projectID: String? = nil,
        since: Date? = nil,
        until: Date? = nil
    ) throws -> [UsageEvent] {
        lock.lock()
        defer { lock.unlock() }

        var clauses: [String] = []
        var args: [BindValue] = []
        if let projectID {
            clauses.append("project_id = ?")
            args.append(.text(projectID))
        }
        if let since {
            clauses.append("started_at >= ?")
            args.append(.double(since.timeIntervalSince1970))
        }
        if let until {
            clauses.append("started_at < ?")
            args.append(.double(until.timeIntervalSince1970))
        }
        let whereSQL = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        let sql = "SELECT * FROM usage_events \(whereSQL) ORDER BY started_at ASC;"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw UsageStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }

        for (idx, arg) in args.enumerated() {
            switch arg {
            case .text(let v): bindText(stmt, Int32(idx + 1), v)
            case .double(let v): sqlite3_bind_double(stmt, Int32(idx + 1), v)
            }
        }

        var results: [UsageEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(rowToEvent(stmt))
        }
        return results
    }

    public func summarize(projects: [AllowlistedProject], now: Date = Date()) throws -> [ProjectUsageSummary] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        let start7d = cal.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let start30d = cal.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday

        return try projects.map { project in
            let events = try events(projectID: project.projectID, since: start30d)
            let today = events.filter { $0.startedAt >= startOfToday }
            let week = events.filter { $0.startedAt >= start7d }
            let estimatedCount = events.filter(\.estimated).count
            let series = Self.dailySeries(events: week, days: 7, now: now, calendar: cal)
            return ProjectUsageSummary(
                project: project,
                tokensToday: today.reduce(0) { $0 + $1.resolvedTokens },
                tokens7d: week.reduce(0) { $0 + $1.resolvedTokens },
                tokens30d: events.reduce(0) { $0 + $1.resolvedTokens },
                sessionsToday: today.count,
                sessions30d: events.count,
                lastActivity: events.map(\.startedAt).max(),
                mostlyEstimated: !events.isEmpty && Double(estimatedCount) / Double(events.count) >= 0.5,
                weeklySeries: series
            )
        }
    }

    /// Oldest → newest daily totals for `days` calendar days ending today.
    public static func dailySeries(
        events: [UsageEvent],
        days: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Int] {
        let startOfToday = calendar.startOfDay(for: now)
        var buckets = Array(repeating: 0, count: max(days, 1))
        for event in events {
            let day = calendar.startOfDay(for: event.startedAt)
            guard let offset = calendar.dateComponents([.day], from: day, to: startOfToday).day,
                  offset >= 0, offset < days else { continue }
            let index = days - 1 - offset
            buckets[index] += event.resolvedTokens
        }
        return buckets
    }

    /// Sum of per-project weekly series (element-wise).
    public static func combinedWeeklySeries(from summaries: [ProjectUsageSummary], days: Int = 7) -> [Int] {
        var combined = Array(repeating: 0, count: days)
        for summary in summaries {
            let series = summary.weeklySeries
            for i in 0..<days {
                let value = i < series.count ? series[i] : 0
                combined[i] += value
            }
        }
        return combined
    }

    private enum BindValue {
        case text(String)
        case double(Double)
    }

    private func eventExists(sessionID: String, source: UsageSource) throws -> Bool {
        let sql = "SELECT 1 FROM usage_events WHERE session_id = ? AND source = ? LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw UsageStoreError.prepareFailed(errmsg())
        }
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, sessionID)
        bindText(stmt, 2, source.rawValue)
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private func rowToEvent(_ stmt: OpaquePointer?) -> UsageEvent {
        func text(_ i: Int32) -> String? {
            guard let c = sqlite3_column_text(stmt, i) else { return nil }
            return String(cString: c)
        }
        func intOpt(_ i: Int32) -> Int? {
            if sqlite3_column_type(stmt, i) == SQLITE_NULL { return nil }
            return Int(sqlite3_column_int64(stmt, i))
        }
        let started = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
        let ended: Date? = sqlite3_column_type(stmt, 5) == SQLITE_NULL
            ? nil
            : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
        return UsageEvent(
            id: text(0) ?? UUID().uuidString,
            projectID: text(1) ?? "",
            workspacePath: text(2) ?? "",
            source: UsageSource(rawValue: text(3) ?? "backfill") ?? .backfill,
            startedAt: started,
            endedAt: ended,
            inputTokens: intOpt(6),
            outputTokens: intOpt(7),
            totalTokens: intOpt(8),
            estimated: sqlite3_column_int(stmt, 9) == 1,
            model: text(10),
            sessionID: text(11)
        )
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let message = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw UsageStoreError.execFailed(message)
        }
    }

    private func errmsg() -> String {
        String(cString: sqlite3_errmsg(db))
    }

    private func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String) {
        sqlite3_bind_text(stmt, idx, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func bindOptionalText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String?) {
        if let value {
            bindText(stmt, idx, value)
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    private func bindOptionalInt(_ stmt: OpaquePointer?, _ idx: Int32, _ value: Int?) {
        if let value {
            sqlite3_bind_int64(stmt, idx, Int64(value))
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }
}

public enum UsageStoreError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case execFailed(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let m): return "SQLite open failed: \(m)"
        case .prepareFailed(let m): return "SQLite prepare failed: \(m)"
        case .stepFailed(let m): return "SQLite step failed: \(m)"
        case .execFailed(let m): return "SQLite exec failed: \(m)"
        }
    }
}
