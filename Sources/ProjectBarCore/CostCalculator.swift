import Foundation

public enum CostCalculator {
    public static func cost(tokens: Int, dollarsPerMillion: Double) -> Double {
        Double(tokens) / 1_000_000.0 * dollarsPerMillion
    }

    public static func formatTokens(_ tokens: Int) -> String {
        let value = Double(tokens)
        switch value {
        case 1_000_000_000...:
            return String(format: "%.1fB", value / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%.1fM", value / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", value / 1_000)
        default:
            return "\(tokens)"
        }
    }

    public static func formatCost(_ amount: Double) -> String {
        if amount < 0.01 && amount > 0 {
            return String(format: "$%.3f", amount)
        }
        return String(format: "$%.2f", amount)
    }
}

public enum TokenEstimator {
    /// Rough heuristic: ~4 characters per token for mixed code/prose.
    public static let charsPerToken: Double = 4.0

    public static func estimateTokens(fromCharacterCount chars: Int) -> Int {
        max(1, Int((Double(chars) / charsPerToken).rounded()))
    }

    public static func estimateTokens(from text: String) -> Int {
        estimateTokens(fromCharacterCount: text.utf8.count)
    }
}
