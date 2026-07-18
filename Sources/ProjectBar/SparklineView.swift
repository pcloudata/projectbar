import SwiftUI

/// Progress bar that does not use GeometryReader (avoids MenuBarExtra layout overlap).
struct FractionBar: View {
    var fraction: Double
    var height: CGFloat = 8
    var fillOpacity: Double = 0.85

    var body: some View {
        let clamped = max(0, min(1, fraction))
        Capsule()
            .fill(Color.secondary.opacity(0.15))
            .frame(height: height)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.accentColor.opacity(fillOpacity))
                    .frame(height: height)
                    .scaleEffect(x: max(0.02, clamped), y: 1, anchor: .leading)
            }
            .clipShape(Capsule())
    }
}

struct SparklineView: View {
    let values: [Int]
    var lineWidth: CGFloat = 1.5
    var showDots: Bool = false

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
                context.fill(fill, with: .color(Color.accentColor.opacity(0.12)))

                var line = Path()
                line.move(to: points[0])
                for point in points.dropFirst() {
                    line.addLine(to: point)
                }
                context.stroke(
                    line,
                    with: .color(Color.accentColor),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )

                if showDots, let last = points.last {
                    let dot = Path(ellipseIn: CGRect(x: last.x - 2, y: last.y - 2, width: 4, height: 4))
                    context.fill(dot, with: .color(Color.accentColor))
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
            let x: CGFloat
            if count == 1 {
                x = size.width / 2
            } else {
                x = size.width * CGFloat(index) / CGFloat(count - 1)
            }
            let norm = CGFloat(value) / CGFloat(maxValue)
            let y = size.height - (norm * (size.height * 0.85) + size.height * 0.05)
            return CGPoint(x: x, y: y)
        }
    }
}

struct ShareBadge: View {
    let share: Double

    var body: some View {
        Text(label)
            .font(PBFont.badge)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.14))
            .foregroundStyle(.secondary)
            .clipShape(Capsule())
    }

    private var label: String {
        let pct = Int((share * 100).rounded())
        return "\(pct)%"
    }
}
