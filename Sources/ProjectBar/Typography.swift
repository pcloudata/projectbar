import SwiftUI

/// Typography aligned with CodexBar / macOS menu cards — San Francisco, not rounded.
enum PBFont {
    static let title = Font.system(size: 15, weight: .semibold)
    static let section = Font.system(size: 11, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyMedium = Font.system(size: 13, weight: .medium)
    static let meta = Font.system(size: 11, weight: .regular)
    static let metaMedium = Font.system(size: 11, weight: .medium)
    static let value = Font.system(size: 12, weight: .medium).monospacedDigit()
    static let valueSmall = Font.system(size: 11, weight: .medium).monospacedDigit()
    static let badge = Font.system(size: 10, weight: .semibold).monospacedDigit()
    static let menuAction = Font.system(size: 13, weight: .regular)
    static let menuBar = Font.system(size: 12, weight: .semibold).monospacedDigit()
    static let tab = Font.system(size: 11, weight: .medium)
}
