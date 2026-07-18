import AppKit
import SwiftUI
import ProjectBarCore

@main
struct ProjectBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        // Only MenuBarExtra — no Window / Settings scenes.
        // Extra windows were making the menu-bar UI disappear on close.
        MenuBarExtra {
            MenuPanel()
                .environmentObject(state)
        } label: {
            MenuBarLabel(state: state)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image(fill: state.menuBarIconFill))
                .renderingMode(.template)
                .frame(width: 18, height: 18)
            if let text = caption, !text.isEmpty {
                Text(text)
                    .font(PBFont.menuBar)
            }
        }
        .help(tooltip)
    }

    private var caption: String? {
        switch state.config.menuBarStyle {
        case .iconOnly:
            return nil
        case .iconAndTokens:
            let tokens = state.overviewTotalToday
            return tokens > 0 ? CostCalculator.formatTokens(tokens) : nil
        case .iconAndProject:
            return state.menuBarTitle == "PB" ? nil : state.menuBarCompactTitle
        }
    }

    private var tooltip: String {
        let today = CostCalculator.formatTokens(state.overviewTotalToday)
        let month = CostCalculator.formatTokens(state.overviewTotal30d)
        return "ProjectBar — Today \(today) · 30d \(month)"
    }
}
