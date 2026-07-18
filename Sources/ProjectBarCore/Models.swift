import Foundation
import CryptoKit

public enum UsageSource: String, Codable, Sendable {
    case backfill
    case hook
}

public struct UsageEvent: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var projectID: String
    public var workspacePath: String
    public var source: UsageSource
    public var startedAt: Date
    public var endedAt: Date?
    public var inputTokens: Int?
    public var outputTokens: Int?
    public var totalTokens: Int?
    public var estimated: Bool
    public var model: String?
    public var sessionID: String?

    public init(
        id: String = UUID().uuidString,
        projectID: String,
        workspacePath: String,
        source: UsageSource,
        startedAt: Date,
        endedAt: Date? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil,
        totalTokens: Int? = nil,
        estimated: Bool = false,
        model: String? = nil,
        sessionID: String? = nil
    ) {
        self.id = id
        self.projectID = projectID
        self.workspacePath = workspacePath
        self.source = source
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens
        self.estimated = estimated
        self.model = model
        self.sessionID = sessionID
    }

    public var resolvedTokens: Int {
        if let totalTokens { return totalTokens }
        return (inputTokens ?? 0) + (outputTokens ?? 0)
    }
}

public struct AllowlistedProject: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: String { projectID }
    public var path: String
    public var displayName: String?
    public var projectID: String

    public init(path: String, displayName: String? = nil) {
        let normalized = (path as NSString).standardizingPath
        self.path = normalized
        self.displayName = displayName
        self.projectID = ProjectIdentity.id(for: normalized)
    }

    public var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return URL(fileURLWithPath: path).lastPathComponent
    }
}

public enum MenuBarStyle: String, Codable, Sendable, CaseIterable {
    case iconOnly
    case iconAndTokens
    case iconAndProject

    public var label: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .iconAndTokens: return "Icon + today’s tokens"
        case .iconAndProject: return "Icon + project + tokens"
        }
    }
}

public struct AppConfig: Codable, Sendable, Equatable {
    public var projects: [AllowlistedProject]
    public var dollarsPerMillionTokens: Double
    public var monthlyTokenBudget: Int?
    public var monthlyDollarBudget: Double?
    public var refreshIntervalSeconds: Int
    public var launchAtLogin: Bool
    public var menuBarStyle: MenuBarStyle

    public init(
        projects: [AllowlistedProject] = AppConfig.defaultProjects,
        dollarsPerMillionTokens: Double = 3.0,
        monthlyTokenBudget: Int? = 50_000_000,
        monthlyDollarBudget: Double? = nil,
        refreshIntervalSeconds: Int = 60,
        launchAtLogin: Bool = false,
        menuBarStyle: MenuBarStyle = .iconAndTokens
    ) {
        self.projects = projects
        self.dollarsPerMillionTokens = dollarsPerMillionTokens
        self.monthlyTokenBudget = monthlyTokenBudget
        self.monthlyDollarBudget = monthlyDollarBudget
        self.refreshIntervalSeconds = refreshIntervalSeconds
        self.launchAtLogin = launchAtLogin
        self.menuBarStyle = menuBarStyle
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        projects = try c.decodeIfPresent([AllowlistedProject].self, forKey: .projects) ?? AppConfig.defaultProjects
        dollarsPerMillionTokens = try c.decodeIfPresent(Double.self, forKey: .dollarsPerMillionTokens) ?? 3.0
        monthlyTokenBudget = try c.decodeIfPresent(Int.self, forKey: .monthlyTokenBudget)
        monthlyDollarBudget = try c.decodeIfPresent(Double.self, forKey: .monthlyDollarBudget)
        refreshIntervalSeconds = try c.decodeIfPresent(Int.self, forKey: .refreshIntervalSeconds) ?? 60
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        menuBarStyle = try c.decodeIfPresent(MenuBarStyle.self, forKey: .menuBarStyle) ?? .iconAndTokens
    }

    public static let defaultProjects: [AllowlistedProject] = []
}

public struct ProjectUsageSummary: Sendable, Identifiable, Equatable {
    public var id: String { project.projectID }
    public var project: AllowlistedProject
    public var tokensToday: Int
    public var tokens7d: Int
    public var tokens30d: Int
    public var sessionsToday: Int
    public var sessions30d: Int
    public var lastActivity: Date?
    public var mostlyEstimated: Bool
    /// Oldest → newest daily token totals for the last 7 calendar days (inclusive of today).
    public var weeklySeries: [Int]

    public init(
        project: AllowlistedProject,
        tokensToday: Int = 0,
        tokens7d: Int = 0,
        tokens30d: Int = 0,
        sessionsToday: Int = 0,
        sessions30d: Int = 0,
        lastActivity: Date? = nil,
        mostlyEstimated: Bool = false,
        weeklySeries: [Int] = Array(repeating: 0, count: 7)
    ) {
        self.project = project
        self.tokensToday = tokensToday
        self.tokens7d = tokens7d
        self.tokens30d = tokens30d
        self.sessionsToday = sessionsToday
        self.sessions30d = sessions30d
        self.lastActivity = lastActivity
        self.mostlyEstimated = mostlyEstimated
        self.weeklySeries = weeklySeries
    }

    public func costToday(rate: Double) -> Double {
        CostCalculator.cost(tokens: tokensToday, dollarsPerMillion: rate)
    }

    public func cost30d(rate: Double) -> Double {
        CostCalculator.cost(tokens: tokens30d, dollarsPerMillion: rate)
    }

    public func shareOfTotal(total30d: Int) -> Double {
        guard total30d > 0 else { return 0 }
        return Double(tokens30d) / Double(total30d)
    }
}

public enum ProjectIdentity {
    public static func id(for path: String) -> String {
        let normalized = (path as NSString).standardizingPath.lowercased()
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
