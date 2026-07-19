import SwiftUI
import ProjectBarCore

struct FractionBar: View {
    var fraction: Double
    var height: CGFloat = 10
    var fill: Color = PBTheme.blue

    var body: some View {
        let clamped = max(0, min(1, fraction))
        Capsule()
            .fill(PBTheme.track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(fill)
                    .frame(height: height)
                    .scaleEffect(x: max(0.02, clamped), y: 1, anchor: .leading)
            }
            .clipShape(Capsule())
    }
}

struct SparklineView: View {
    let values: [Int]
    var lineWidth: CGFloat = 2
    var showDots: Bool = true
    var color: Color = PBTheme.blue

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            let points = normalizedPoints(in: size)

            if points.count >= 2 {
                var fill = Path()
                fill.move(to: CGPoint(x: points[0].x, y: size.height))
                for point in points {
                    fill.addLine(to: point)
                }
                fill.addLine(to: CGPoint(x: points[points.count - 1].x, y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .color(color.opacity(0.14)))

                var line = Path()
                line.move(to: points[0])
                for point in points.dropFirst() {
                    line.addLine(to: point)
                }
                context.stroke(
                    line,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )

                if showDots {
                    for point in points {
                        let dot = Path(ellipseIn: CGRect(x: point.x - 2.2, y: point.y - 2.2, width: 4.4, height: 4.4))
                        context.fill(dot, with: .color(color))
                    }
                }
            } else {
                var flat = Path()
                let y = size.height * 0.7
                flat.move(to: CGPoint(x: 0, y: y))
                flat.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(
                    flat,
                    with: .color(Color.secondary.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let maxValue = max(values.max() ?? 0, 1)
        let count = values.count
        return values.enumerated().map { index, value in
            let x: CGFloat = count == 1
                ? size.width / 2
                : size.width * CGFloat(index) / CGFloat(count - 1)
            let norm = CGFloat(value) / CGFloat(maxValue)
            let y = size.height - (norm * (size.height * 0.82) + size.height * 0.08)
            return CGPoint(x: x, y: y)
        }
    }
}

struct WeekdayLabels: View {
    var body: some View {
        let labels = weekdayLabels()
        HStack {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(PBFont.day)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekdayLabels() -> [String] {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let today = cal.startOfDay(for: Date())
        return (0..<7).compactMap { offset -> String? in
            guard let day = cal.date(byAdding: .day, value: offset - 6, to: today) else { return nil }
            return String(formatter.string(from: day).prefix(3))
        }
    }
}

struct EstimatedBadge: View {
    var body: some View {
        Text("Estimated")
            .font(PBFont.badge)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(PBTheme.estimatedOrange)
            .background(PBTheme.estimatedOrange.opacity(0.12))
            .overlay(
                Capsule().strokeBorder(PBTheme.estimatedOrange.opacity(0.45), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

/// Overview project row: fixed columns so %, bars, Estimated, and sparklines align.
struct ProjectListRow: View {
    let name: String
    let share: Double
    let weeklySeries: [Int]
    let estimated: Bool

    private let percentWidth: CGFloat = 36
    private let barWidth: CGFloat = 72
    private let badgeWidth: CGFloat = 72
    private let sparkWidth: CGFloat = 48

    var body: some View {
        HStack(spacing: 8) {
            ProjectTile(name: name, size: 24)

            Text(name)
                .font(PBFont.bodyMedium)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(Int((share * 100).rounded()))%")
                .font(PBFont.percent)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: percentWidth, alignment: .trailing)

            FractionBar(fraction: share, height: 5)
                .frame(width: barWidth)

            Group {
                if estimated {
                    EstimatedBadge()
                } else {
                    Color.clear
                }
            }
            .frame(width: badgeWidth, alignment: .leading)

            SparklineView(values: weeklySeries, lineWidth: 1.5, showDots: false)
                .frame(width: sparkWidth, height: 22)
        }
        .padding(.vertical, 2)
    }
}

struct ProjectTile: View {
    let name: String
    var size: CGFloat = 22

    var body: some View {
        let color = PBTheme.projectColor(for: name)
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: PBTheme.projectSymbol(for: name))
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
            )
    }
}

struct BrandMark: View {
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(PBTheme.blue)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}

/// Mockup-style meter: title + budget line, thick bar, % left / detail right.
struct LimitMeter: View {
    let title: String
    let usedTokens: Int
    let limitTokens: Int
    let costLabel: String?

    private var fraction: Double {
        min(1, Double(usedTokens) / max(Double(limitTokens), 1))
    }

    private var percent: Int { Int((fraction * 100).rounded()) }

    private var remaining: Int { max(0, limitTokens - usedTokens) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(PBFont.section)
                Spacer(minLength: 8)
                Text("\(CostCalculator.formatTokens(usedTokens)) / \(CostCalculator.formatTokens(limitTokens))")
                    .font(PBFont.metaMedium)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            FractionBar(fraction: fraction, height: 10)
            HStack {
                Text("\(percent)%")
                    .font(PBFont.percent)
                    .foregroundStyle(PBTheme.blue)
                Spacer()
                if let costLabel {
                    Text("\(CostCalculator.formatTokens(remaining)) left · \(costLabel)")
                        .font(PBFont.meta)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(CostCalculator.formatTokens(remaining)) left")
                        .font(PBFont.meta)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Compact usage row: label | tokens | bar | %
struct UsageRow: View {
    let title: String
    let tokens: Int
    let fraction: Double

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(PBFont.body)
                .frame(width: 92, alignment: .leading)
            Text(CostCalculator.formatTokens(tokens))
                .font(PBFont.value)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            FractionBar(fraction: fraction, height: 8)
            Text("\(Int((min(1, fraction) * 100).rounded()))%")
                .font(PBFont.percent)
                .foregroundStyle(PBTheme.blue)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

struct CostRow: View {
    let title: String
    let amount: Double

    var body: some View {
        HStack {
            Text(title)
                .font(PBFont.body)
                .foregroundStyle(.primary)
            Spacer()
            Text(CostCalculator.formatCost(amount))
                .font(PBFont.value)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }
}
