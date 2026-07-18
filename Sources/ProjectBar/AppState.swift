import Foundation
import ServiceManagement
import SwiftUI
import ProjectBarCore

@MainActor
final class AppState: ObservableObject {
    @Published var config: AppConfig
    @Published var summaries: [ProjectUsageSummary] = []
    @Published var selectedTab: String = "overview"
    @Published var lastRefresh: Date?
    @Published var lastError: String?
    @Published var isRefreshing = false
    @Published var backfillMessage: String?
    @Published var hooksInstalled: Bool = false
    @Published var showSettings = false

    private let configStore = ConfigStore()
    private var store: UsageStore?
    private var refreshTask: Task<Void, Never>?

    init() {
        self.config = configStore.load()
        self.hooksInstalled = HookInstaller.isInstalled()
        do {
            self.store = try UsageStore()
        } catch {
            self.lastError = error.localizedDescription
        }
        Task { await refresh(runBackfill: true) }
        startTimer()
    }

    var rate: Double { config.dollarsPerMillionTokens }

    var menuBarTitle: String {
        let ranked = summaries.sorted { $0.tokensToday > $1.tokensToday }
        if let top = ranked.first, top.tokensToday > 0 {
            return "\(top.project.name) \(CostCalculator.formatTokens(top.tokensToday))"
        }
        let todayTotal = summaries.reduce(0) { $0 + $1.tokensToday }
        if todayTotal > 0 {
            return "PB \(CostCalculator.formatTokens(todayTotal))"
        }
        return "PB"
    }

    /// Shorter menu-bar caption: first 8 chars of project + tokens.
    var menuBarCompactTitle: String {
        let ranked = summaries.sorted { $0.tokensToday > $1.tokensToday }
        if let top = ranked.first, top.tokensToday > 0 {
            let name = top.project.name
            let short = name.count > 10 ? String(name.prefix(8)) + "…" : name
            return "\(short) \(CostCalculator.formatTokens(top.tokensToday))"
        }
        return CostCalculator.formatTokens(overviewTotalToday)
    }

    var overviewTotalToday: Int {
        summaries.reduce(0) { $0 + $1.tokensToday }
    }

    var overviewTotal30d: Int {
        summaries.reduce(0) { $0 + $1.tokens30d }
    }

    var overviewTotal7d: Int {
        summaries.reduce(0) { $0 + $1.tokens7d }
    }

    var overviewWeeklySeries: [Int] {
        UsageStore.combinedWeeklySeries(from: summaries)
    }

    /// 0...1 fill for the menu-bar mark (today vs daily budget slice, else relative to week peak).
    var menuBarIconFill: Double {
        if let budget = config.monthlyTokenBudget, budget > 0 {
            let daily = Double(budget) / 30.0
            return min(1, Double(overviewTotalToday) / max(daily, 1))
        }
        let peak = max(overviewWeeklySeries.max() ?? 0, overviewTotalToday, 1)
        return min(1, Double(overviewTotalToday) / Double(peak))
    }

    func shareOfTotal30d(for summary: ProjectUsageSummary) -> Double {
        summary.shareOfTotal(total30d: overviewTotal30d)
    }

    func startTimer() {
        refreshTask?.cancel()
        let interval = max(15, config.refreshIntervalSeconds)
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                await self?.refresh(runBackfill: false)
            }
        }
    }

    func refresh(runBackfill: Bool) async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            if store == nil {
                store = try UsageStore()
            }
            guard let store else { return }
            config = configStore.load()
            hooksInstalled = HookInstaller.isInstalled()
            if runBackfill {
                let result = try BackfillScanner().run(projects: config.projects, store: store)
                backfillMessage = "Backfill: +\(result.insertedEvents) sessions (\(result.scannedFiles) files)"
            }
            summaries = try store.summarize(projects: config.projects)
                .sorted { $0.tokens30d > $1.tokens30d }
            lastRefresh = Date()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func saveConfig() {
        do {
            try configStore.save(config)
            LoginItemManager.setEnabled(config.launchAtLogin)
            startTimer()
            Task { await refresh(runBackfill: false) }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addProject(path: String) {
        let project = AllowlistedProject(path: path)
        guard !config.projects.contains(where: { $0.projectID == project.projectID }) else { return }
        config.projects.append(project)
        saveConfig()
    }

    func removeProject(_ project: AllowlistedProject) {
        config.projects.removeAll { $0.projectID == project.projectID }
        if selectedTab == project.projectID {
            selectedTab = "overview"
        }
        saveConfig()
    }

    func installHooks() {
        do {
            let binary = locateIngestBinary()
            _ = try HookInstaller.install(ingestBinaryURL: binary)
            hooksInstalled = true
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func uninstallHooks() {
        do {
            try HookInstaller.uninstall()
            hooksInstalled = false
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func locateIngestBinary() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("projectbar-ingest"),
            URL(fileURLWithPath: home + "/.local/bin/projectbar-ingest"),
            URL(fileURLWithPath: "/usr/local/bin/projectbar-ingest"),
            URL(fileURLWithPath: cwd + "/.build/release/projectbar-ingest"),
            URL(fileURLWithPath: cwd + "/.build/debug/projectbar-ingest")
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}

enum LoginItemManager {
    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Best-effort; Settings still stores the preference.
            }
        }
    }
}
