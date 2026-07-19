import AppKit
import SwiftUI
import ProjectBarCore

struct MenuPanel: View {
    @EnvironmentObject private var state: AppState
    @State private var showingSettings = false

    private var isOverview: Bool { state.selectedTab == "overview" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showingSettings {
                settingsChrome
            } else {
                mainChrome
            }
        }
        .padding(16)
        .frame(width: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            Task { await state.refresh(runBackfill: false) }
        }
    }

    private var mainChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isOverview {
                header
                sectionDivider
            }

            tabStrip
                .padding(.bottom, 2)
            sectionDivider
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            sectionDivider
            footer
        }
    }

    private var settingsChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BrandMark(size: 22)
                Text("Settings")
                    .font(PBFont.brand)
                Spacer()
                Button("Done") { showingSettings = false }
                    .keyboardShortcut(.defaultAction)
            }
            sectionDivider
            SettingsView()
                .environmentObject(state)
                .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 520)
        }
    }

    private var sectionDivider: some View {
        PBTheme.divider
            .frame(height: 1)
            .padding(.vertical, 12)
    }

    private var header: some View {
        HStack(spacing: 10) {
            BrandMark(size: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("ProjectBar")
                    .font(PBFont.brand)
                Text(subtitle)
                    .font(PBFont.meta)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if state.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var selectedSummary: ProjectUsageSummary? {
        state.summaries.first { $0.project.projectID == state.selectedTab }
    }

    private var subtitle: String {
        if let err = state.lastError { return err }
        if let t = state.lastRefresh {
            let seconds = Date().timeIntervalSince(t)
            if seconds < 5 { return "Updated just now" }
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .short
            return "Updated \(f.localizedString(for: t, relativeTo: Date()))"
        }
        return "Waiting for data"
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                tabButton(id: "overview", label: "Overview")
                ForEach(state.summaries) { summary in
                    tabButton(id: summary.project.projectID, label: summary.project.name)
                }
            }
        }
        .frame(height: 34)
    }

    private func tabButton(id: String, label: String) -> some View {
        let selected = state.selectedTab == id
        return Button {
            state.selectedTab = id
        } label: {
            Text(label)
                .font(PBFont.tab)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? PBTheme.blue : PBTheme.blueSoft)
                .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.85))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if isOverview {
            OverviewCard()
        } else if let summary = selectedSummary {
            ProjectCard(summary: summary)
        } else {
            Text("No project selected")
                .font(PBFont.meta)
                .foregroundStyle(.secondary)
                .padding(.vertical, 24)
        }
    }

    private var footer: some View {
        // Same horizontal blue action bar on Overview and project tabs
        HStack(spacing: 0) {
            footerButton(title: isOverview ? "Refresh + Backfill" : "Refresh", systemImage: "arrow.clockwise") {
                Task { await state.refresh(runBackfill: true) }
            }
            Spacer(minLength: 4)
            if !isOverview, let summary = selectedSummary {
                footerButton(title: "Open Folder", systemImage: "folder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: summary.project.path))
                }
                Spacer(minLength: 4)
            }
            footerButton(title: "Settings", systemImage: "gearshape") {
                showingSettings = true
            }
            Spacer(minLength: 4)
            footerButton(title: "Quit ProjectBar", systemImage: "power") {
                AppDelegate.shared?.userRequestedQuit = true
                NSApplication.shared.terminate(nil)
            }
        }
        .font(PBFont.menuAction)
        .foregroundStyle(PBTheme.blue)
        .padding(.top, 2)
    }

    private func footerButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
            }
        }
        .buttonStyle(.plain)
    }
}
