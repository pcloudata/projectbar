import SwiftUI

/// Visual system matched to the ProjectBar reference mockups (layout + color).
enum PBTheme {
    static let blue = Color(red: 0.0, green: 0.478, blue: 1.0) // #007AFF-ish
    static let blueSoft = Color(red: 0.90, green: 0.94, blue: 1.0)
    static let track = Color(red: 0.90, green: 0.91, blue: 0.93)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let estimatedOrange = Color(red: 0.95, green: 0.45, blue: 0.15)
    static let divider = Color.primary.opacity(0.08)

    /// Stable accent color per project name (mockup-style colored tiles).
    static func projectColor(for name: String) -> Color {
        let key = name.lowercased()
        if key.contains("vaanika") {
            return Color(red: 0.45, green: 0.28, blue: 0.92) // violet — AI tutor
        }
        let palette: [Color] = [
            Color(red: 0.20, green: 0.48, blue: 0.96),
            Color(red: 0.10, green: 0.65, blue: 0.62),
            Color(red: 0.56, green: 0.35, blue: 0.90),
            Color(red: 0.95, green: 0.50, blue: 0.20),
            Color(red: 0.90, green: 0.30, blue: 0.45),
            Color(red: 0.25, green: 0.55, blue: 0.35)
        ]
        return palette[stableHash(name) % palette.count]
    }

    static func projectSymbol(for name: String) -> String {
        let key = name.lowercased()
        // Named overrides (reliable SF Symbols)
        if key.contains("vaanika") { return "graduationcap.fill" } // online AI tutor
        if key.contains("core") { return "sun.max.fill" }
        if key.contains("signal") { return "airplane" }
        if key.contains("logi") { return "leaf.fill" }
        if key.contains("build") || key.contains("mestra") { return "hammer.fill" }

        // Fallbacks — avoid symbols that may be missing on some OS versions
        let symbols = [
            "airplane",
            "anchor",
            "book.fill",
            "sun.max.fill",
            "leaf.fill",
            "flame.fill",
            "sparkles",
            "cpu"
        ]
        return symbols[stableHash(name) % symbols.count]
    }

    private static func stableHash(_ name: String) -> Int {
        var hash = 0
        for u in name.unicodeScalars {
            hash = (hash &* 31 &+ Int(u.value)) & 0x7fffffff
        }
        return hash
    }
}

enum PBFont {
    static let brand = Font.system(size: 16, weight: .bold)
    static let title = Font.system(size: 18, weight: .bold)
    static let section = Font.system(size: 13, weight: .bold)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .semibold)
    static let meta = Font.system(size: 11, weight: .regular)
    static let metaMedium = Font.system(size: 11, weight: .medium)
    static let value = Font.system(size: 12, weight: .bold).monospacedDigit()
    static let valueLarge = Font.system(size: 22, weight: .bold).monospacedDigit()
    static let percent = Font.system(size: 12, weight: .bold).monospacedDigit()
    static let badge = Font.system(size: 10, weight: .semibold)
    static let menuAction = Font.system(size: 12, weight: .semibold)
    static let menuBar = Font.system(size: 12, weight: .semibold).monospacedDigit()
    static let tab = Font.system(size: 12, weight: .semibold)
    static let day = Font.system(size: 10, weight: .medium)
}

struct SectionRule: View {
    var body: some View {
        PBTheme.divider
            .frame(height: 1)
            .padding(.vertical, 12)
    }
}
