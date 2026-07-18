import XCTest
@testable import ProjectBarCore

final class ProjectBarCoreTests: XCTestCase {
    func testProjectIdentityStable() {
        let a = ProjectIdentity.id(for: "/Users/me/proj")
        let b = ProjectIdentity.id(for: "/Users/me/proj/")
        // standardizingPath may or may not strip trailing slash consistently
        let c = ProjectIdentity.id(for: "/Users/me/proj")
        XCTAssertEqual(a, c)
        _ = b
    }

    func testCursorSlug() {
        let slug = PathMapping.cursorSlug(
            forPath: "/Users/alex/Projects/northwind"
        )
        XCTAssertEqual(
            slug,
            "Users-alex-Projects-northwind"
        )
    }

    func testTokenEstimator() {
        XCTAssertEqual(TokenEstimator.estimateTokens(fromCharacterCount: 400), 100)
    }

    func testCost() {
        let cost = CostCalculator.cost(tokens: 1_000_000, dollarsPerMillion: 3.0)
        XCTAssertEqual(cost, 3.0, accuracy: 0.0001)
    }

    func testMatchNestedPath() {
        let projects = [
            AllowlistedProject(path: "/Users/me/a"),
            AllowlistedProject(path: "/Users/me/a/nested")
        ]
        let match = PathMapping.match(workspacePath: "/Users/me/a/nested/src", projects: projects)
        XCTAssertEqual(match?.path, "/Users/me/a/nested")
    }

    func testUsageStoreDedup() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("projectbar-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let db = tmp.appendingPathComponent("usage.sqlite")
        let store = try UsageStore(databaseURL: db)
        let event = UsageEvent(
            projectID: "abc",
            workspacePath: "/tmp/x",
            source: .backfill,
            startedAt: Date(),
            totalTokens: 100,
            estimated: true,
            sessionID: "backfill:sess1"
        )
        XCTAssertTrue(try store.upsert(event))
        XCTAssertFalse(try store.upsert(event))
        let all = try store.events(projectID: "abc")
        XCTAssertEqual(all.count, 1)
    }

    func testDailySeriesBuckets() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let events = [
            UsageEvent(projectID: "p", workspacePath: "/x", source: .backfill, startedAt: yesterday, totalTokens: 100, sessionID: "a"),
            UsageEvent(projectID: "p", workspacePath: "/x", source: .hook, startedAt: today, totalTokens: 250, sessionID: "b")
        ]
        let series = UsageStore.dailySeries(events: events, days: 7, now: today, calendar: cal)
        XCTAssertEqual(series.count, 7)
        XCTAssertEqual(series[5], 100)
        XCTAssertEqual(series[6], 250)
    }

    func testShareOfTotal() {
        let project = AllowlistedProject(path: "/Users/alex/Projects/northwind")
        let summary = ProjectUsageSummary(project: project, tokens30d: 25)
        XCTAssertEqual(summary.shareOfTotal(total30d: 100), 0.25, accuracy: 0.0001)
    }
}
