import AppKit
import Foundation

/// Menu-bar mark: three ascending bars on a baseline (projects + spend).
/// Template image — adapts to light/dark. No plate, no letterforms.
enum MenuBarIcon {
    /// - Parameter fill: 0...1 how many bars are fully lit (usage cue).
    static func image(fill: Double = 0.35) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let clamped = max(0, min(1, fill))

            // Optical inset — keep clear of menu-bar edge clipping
            let content = NSRect(x: 3, y: 2.5, width: 12, height: 13)

            let barWidth: CGFloat = 2.75
            let gap: CGFloat = 1.75
            let heights: [CGFloat] = [0.42, 0.68, 1.0]
            let lit = litBarCount(fill: clamped)

            let clusterWidth = barWidth * 3 + gap * 2
            let originX = content.midX - clusterWidth / 2
            let baselineY = content.minY + 1.0
            let maxBarHeight = content.height - 3.5

            // Baseline = “projects shelf” — one stroke that makes it not a generic chart
            let baseline = NSBezierPath()
            baseline.move(to: NSPoint(x: originX - 0.5, y: baselineY))
            baseline.line(to: NSPoint(x: originX + clusterWidth + 0.5, y: baselineY))
            baseline.lineWidth = 1.25
            baseline.lineCapStyle = .round
            NSColor.black.setStroke()
            baseline.stroke()

            for (index, heightFrac) in heights.enumerated() {
                let h = maxBarHeight * heightFrac
                let x = originX + CGFloat(index) * (barWidth + gap)
                let barRect = NSRect(
                    x: x,
                    y: baselineY + 1.1,
                    width: barWidth,
                    height: h
                )
                let bar = NSBezierPath(roundedRect: barRect, xRadius: 1.0, yRadius: 1.0)
                let alpha: CGFloat = index < lit ? 1.0 : 0.22
                NSColor.black.withAlphaComponent(alpha).setFill()
                bar.fill()
            }

            return true
        }
        image.isTemplate = true
        return image
    }

    private static func litBarCount(fill: Double) -> Int {
        // Always show structure; light 1…3 bars from usage
        let raw = Int((fill * 3).rounded(.up))
        return min(3, max(1, raw))
    }
}
