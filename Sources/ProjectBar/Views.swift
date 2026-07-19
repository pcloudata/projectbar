import SwiftUI
import ProjectBarCore

struct OverviewCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LimitMeter(
                title: "Today",
                usedTokens: state.overviewTotalToday,
                limitTokens: Int(dayScale),
                costLabel: CostCalculator.formatCost(
                    CostCalculator.cost(tokens: state.overviewTotalToday, dollarsPerMillion: state.rate)
                )
            )

            SectionRule()

            LimitMeter(
                title: "Last 30 days",
                usedTokens: state.overviewTotal30d,
                limitTokens: Int(monthScale),
                costLabel: CostCalculator.formatCost(
                    CostCalculator.cost(tokens: state.overviewTotal30d, dollarsPerMillion: state.rate)
                )
            )

            SectionRule()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Last 7 days")
                        .font(PBFont.section)
                    Spacer()
                    Text(CostCalculator.formatTokens(state.overviewTotal7d))
                        .font(PBFont.value)
                        .foregroundStyle(.primary)
                }
                SparklineView(values: state.overviewWeeklySeries, showDots: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                WeekdayLabels()
            }

            SectionRule()

            Text("Projects")
                .font(PBFont.section)
                .padding(.bottom, 8)

            if state.summaries.isEmpty {
                Text("No allowlisted projects yet. Add some in Settings.")
                    .font(PBFont.meta)
                    .foregroundStyle(.secondary)
            } else {
                let total30d = max(state.overviewTotal30d, 1)
                ForEach(Array(state.summaries.enumerated()), id: \.element.id) { index, summary in
                    let share = summary.shareOfTotal(total30d: total30d)
                    if index > 0 {
                        PBTheme.divider
                            .frame(height: 1)
                            .padding(.vertical, 8)
                    }
                    Button {
                        state.selectedTab = summary.project.projectID
                    } label: {
                        ProjectListRow(
                            name: summary.project.name,
                            share: share,
                            weeklySeries: summary.weeklySeries,
                            estimated: summary.mostlyEstimated
                        )
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
}

struct ProjectCard: View {
    @EnvironmentObject private var state: AppState
    let summary: ProjectUsageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                ProjectTile(name: summary.project.name, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.project.name)
                        .font(PBFont.title)
                    Text(updatedLabel)
                        .font(PBFont.meta)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Share of all projects")
                        .font(PBFont.meta)
                        .foregroundStyle(.secondary)
                    Text("\(Int((state.shareOfTotal30d(for: summary) * 100).rounded()))%")
                        .font(PBFont.valueLarge)
                        .foregroundStyle(PBTheme.blue)
                    if summary.mostlyEstimated {
                        EstimatedBadge()
                    }
                }
            }

            SectionRule()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weekly trend")
                        .font(PBFont.section)
                    Spacer()
                    Text("\(CostCalculator.formatTokens(summary.tokens7d)) · last 7d")
                        .font(PBFont.meta)
                        .foregroundStyle(.secondary)
                }
                SparklineView(values: summary.weeklySeries, showDots: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                WeekdayLabels()
            }

            SectionRule()

            VStack(alignment: .leading, spacing: 10) {
                Text("Usage")
                    .font(PBFont.section)
                UsageRow(title: "Today", tokens: summary.tokensToday, fraction: fraction(summary.tokensToday, scale: dayScale))
                UsageRow(title: "Last 7 days", tokens: summary.tokens7d, fraction: fraction(summary.tokens7d, scale: weekScale))
                UsageRow(title: "Last 30 days", tokens: summary.tokens30d, fraction: fraction(summary.tokens30d, scale: monthScale))
            }

            SectionRule()

            VStack(alignment: .leading, spacing: 6) {
                Text("Cost")
                    .font(PBFont.section)
                CostRow(title: "Estimated cost (today)", amount: summary.costToday(rate: state.rate))
                CostRow(title: "Estimated cost (last 7 days)", amount: CostCalculator.cost(tokens: summary.tokens7d, dollarsPerMillion: state.rate))
                CostRow(title: "Estimated cost (last 30 days)", amount: summary.cost30d(rate: state.rate))
                Text("Costs are estimated and may not reflect final charges.")
                    .font(PBFont.meta)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var updatedLabel: String {
        if let t = state.lastRefresh {
            let seconds = Date().timeIntervalSince(t)
            if seconds < 5 { return "Updated just now" }
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            return "Updated \(f.localizedString(for: t, relativeTo: Date()))"
        }
        return "Waiting for data"
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
}
