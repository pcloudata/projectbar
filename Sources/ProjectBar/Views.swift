import SwiftUI
import ProjectBarCore

struct OverviewCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UsageMeter(
                title: "Today",
                usedLabel: "\(percentLabel(fraction(tokens: state.overviewTotalToday, scale: dayScale))) · \(CostCalculator.formatTokens(state.overviewTotalToday))",
                fraction: fraction(tokens: state.overviewTotalToday, scale: dayScale),
                detail: CostCalculator.formatCost(
                    CostCalculator.cost(tokens: state.overviewTotalToday, dollarsPerMillion: state.rate)
                )
            )
            UsageMeter(
                title: "Last 30 days",
                usedLabel: "\(percentLabel(fraction(tokens: state.overviewTotal30d, scale: monthScale))) · \(CostCalculator.formatTokens(state.overviewTotal30d))",
                fraction: fraction(tokens: state.overviewTotal30d, scale: monthScale),
                detail: CostCalculator.formatCost(
                    CostCalculator.cost(tokens: state.overviewTotal30d, dollarsPerMillion: state.rate)
                )
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Last 7 days")
                        .font(PBFont.section)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(CostCalculator.formatTokens(state.overviewTotal7d))
                        .font(PBFont.valueSmall)
                        .foregroundStyle(.secondary)
                }
                SparklineView(values: state.overviewWeeklySeries, showDots: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }

            Text("Projects")
                .font(PBFont.section)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            if state.summaries.isEmpty {
                Text("No allowlisted projects yet. Add some in Settings.")
                    .font(PBFont.meta)
                    .foregroundStyle(.secondary)
            } else {
                let total30d = max(state.overviewTotal30d, 1)
                ForEach(Array(state.summaries.enumerated()), id: \.element.id) { index, summary in
                    let share = summary.shareOfTotal(total30d: total30d)
                    Button {
                        state.selectedTab = summary.project.projectID
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text("\(index + 1).")
                                    .font(PBFont.valueSmall)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 16, alignment: .trailing)
                                Text(summary.project.name)
                                    .font(PBFont.bodyMedium)
                                    .lineLimit(1)
                                ShareBadge(share: share)
                                if summary.mostlyEstimated {
                                    EstimatedBadge()
                                }
                                Spacer(minLength: 4)
                                Text(CostCalculator.formatTokens(summary.tokens30d))
                                    .font(PBFont.value)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 8) {
                                FractionBar(fraction: share, height: 4, fillOpacity: 0.55)
                                SparklineView(values: summary.weeklySeries, lineWidth: 1.25)
                                    .frame(width: 56, height: 16)
                            }
                            .padding(.leading, 22)
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var dayScale: Double {
        if let budget = state.config.monthlyTokenBudget {
            return Double(budget) / 30.0
        }
        return max(Double(state.overviewTotalToday), 1)
    }

    private var monthScale: Double {
        if let budget = state.config.monthlyTokenBudget {
            return Double(budget)
        }
        return max(Double(state.overviewTotal30d), 1)
    }

    private func fraction(tokens: Int, scale: Double) -> Double {
        min(1.0, Double(tokens) / max(scale, 1))
    }

    private func percentLabel(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))% used"
    }
}

struct ProjectCard: View {
    @EnvironmentObject private var state: AppState
    let summary: ProjectUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Share of all projects")
                    .font(PBFont.section)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                ShareBadge(share: state.shareOfTotal30d(for: summary))
                if summary.mostlyEstimated {
                    EstimatedBadge()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Weekly trend")
                        .font(PBFont.section)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(CostCalculator.formatTokens(summary.tokens7d)) · last 7d")
                        .font(PBFont.valueSmall)
                        .foregroundStyle(.secondary)
                }
                SparklineView(values: summary.weeklySeries, showDots: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }

            UsageMeter(
                title: "Today",
                usedLabel: "\(percentLabel(fraction(summary.tokensToday, scale: dayScale))) · \(CostCalculator.formatTokens(summary.tokensToday))",
                fraction: fraction(summary.tokensToday, scale: dayScale),
                detail: "\(summary.sessionsToday) sessions · \(CostCalculator.formatCost(summary.costToday(rate: state.rate)))"
            )
            UsageMeter(
                title: "Last 7 days",
                usedLabel: "\(percentLabel(fraction(summary.tokens7d, scale: weekScale))) · \(CostCalculator.formatTokens(summary.tokens7d))",
                fraction: fraction(summary.tokens7d, scale: weekScale),
                detail: nil
            )
            UsageMeter(
                title: "Last 30 days",
                usedLabel: "\(percentLabel(fraction(summary.tokens30d, scale: monthScale))) · \(CostCalculator.formatTokens(summary.tokens30d))",
                fraction: fraction(summary.tokens30d, scale: monthScale),
                detail: "\(Int((state.shareOfTotal30d(for: summary) * 100).rounded()))% of all projects · \(summary.sessions30d) sessions"
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Cost")
                    .font(PBFont.section)
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Today")
                        .font(PBFont.body)
                    Spacer()
                    Text("\(CostCalculator.formatCost(summary.costToday(rate: state.rate))) · \(CostCalculator.formatTokens(summary.tokensToday)) tokens")
                        .font(PBFont.value)
                }
                HStack {
                    Text("Last 30 days")
                        .font(PBFont.body)
                    Spacer()
                    Text("\(CostCalculator.formatCost(summary.cost30d(rate: state.rate))) · \(CostCalculator.formatTokens(summary.tokens30d)) tokens")
                        .font(PBFont.value)
                }

                if let last = summary.lastActivity {
                    Text("Last activity \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(PBFont.meta)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var dayScale: Double {
        if let budget = state.config.monthlyTokenBudget {
            return Double(budget) / 30.0
        }
        return max(Double(summary.tokensToday), 1)
    }

    private var weekScale: Double {
        if let budget = state.config.monthlyTokenBudget {
            return Double(budget) / 30.0 * 7.0
        }
        return max(Double(summary.tokens7d), 1)
    }

    private var monthScale: Double {
        if let budget = state.config.monthlyTokenBudget {
            return Double(budget)
        }
        return max(Double(summary.tokens30d), 1)
    }

    private func fraction(_ tokens: Int, scale: Double) -> Double {
        min(1.0, Double(tokens) / max(scale, 1))
    }

    private func percentLabel(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))% used"
    }
}

struct UsageMeter: View {
    let title: String
    let usedLabel: String
    let fraction: Double
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(PBFont.section)
                Spacer(minLength: 8)
                Text(usedLabel)
                    .font(PBFont.metaMedium)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            FractionBar(fraction: fraction, height: 8)
            if let detail {
                Text(detail)
                    .font(PBFont.meta)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct EstimatedBadge: View {
    var body: some View {
        Text("Estimated")
            .font(PBFont.badge)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.2))
            .foregroundStyle(.orange)
            .clipShape(Capsule())
    }
}
