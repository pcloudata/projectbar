import XCTest
@testable import ProjectBarCore

final class BackfillScannerTests: XCTestCase {
    func testBackfillEstimatesFromTranscript() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pb-backfill-\(UUID().uuidString)", isDirectory: true)
        let projectPath = tmp.appendingPathComponent("myproj", isDirectory: true)
        let slug = PathMapping.cursorSlug(forPath: projectPath.path)
        let cursorRoot = tmp.appendingPathComponent("cursor-projects", isDirectory: true)
        let sessionDir = cursorRoot
            .appendingPathComponent(slug, isDirectory: true)
            .appendingPathComponent("agent-transcripts", isDirectory: true)
            .appendingPathComponent("sess-abc", isDirectory: true)

        try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
        let jsonl = sessionDir.appendingPathComponent("sess-abc.jsonl")
        let payload = #"{"role":"user","message":{"content":"\#(String(repeating: "hello world ", count: 50))"}}"# + "\n"
        try payload.write(to: jsonl, atomically: true, encoding: .utf8)

        let dbURL = tmp.appendingPathComponent("usage.sqlite")
        let store = try UsageStore(databaseURL: dbURL)
        let project = AllowlistedProject(path: projectPath.path)
        let scanner = BackfillScanner(projectsRoot: cursorRoot)
        let result = try scanner.run(projects: [project], store: store)

        XCTAssertEqual(result.scannedFiles, 1)
        XCTAssertEqual(result.insertedEvents, 1)

        let summaries = try store.summarize(projects: [project])
        XCTAssertEqual(summaries.count, 1)
        XCTAssertGreaterThan(summaries[0].tokens30d, 0)
        XCTAssertTrue(summaries[0].mostlyEstimated)

        // Dedup on second run
        let result2 = try scanner.run(projects: [project], store: store)
        XCTAssertEqual(result2.insertedEvents, 0)
        XCTAssertEqual(result2.skippedDuplicates, 1)

        try? FileManager.default.removeItem(at: tmp)
    }

    func testHookIngestMatchesAllowlist() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("pb-hook-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let project = AllowlistedProject(path: "/Users/alex/Projects/northwind")
        let config = AppConfig(projects: [project])
        let store = try UsageStore(databaseURL: tmp.appendingPathComponent("usage.sqlite"))

        let json = """
        {"conversation_id":"c1","generation_id":"g1","workspace_roots":["\(project.path)"],"hook_event_name":"stop","total_tokens":4200,"model":"test"}
        """
        let inserted = try HookIngestor().ingest(
            payloadJSON: Data(json.utf8),
            config: config,
            store: store
        )
        XCTAssertTrue(inserted)
        let summaries = try store.summarize(projects: [project])
        XCTAssertEqual(summaries[0].tokens30d, 4200)
        XCTAssertFalse(summaries[0].mostlyEstimated)
    }
}
