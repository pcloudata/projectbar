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
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            Task { await state.refresh(runBackfill: false) }
        }
    }

    // MARK: - Main panel

    private var mainChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, 10)

            tabStrip
                .frame(height: 32)

            Divider()
                .padding(.vertical, 10)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.vertical, 10)

            footer
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - In-panel settings (no separate window)

    private var settingsChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(PBFont.title)
                Spacer()
                Button("Done") {
                    showingSettings = false
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()
                .padding(.vertical, 10)

            SettingsView()
                .environmentObject(state)
                .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 520)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTitle)
                    .font(PBFont.title)
                Text(subtitle)
                    .font(PBFont.meta)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if state.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var selectedTitle: String {
        if isOverview { return "Overview" }
        return state.summaries.first { $0.project.projectID == state.selectedTab }?.project.name
            ?? "Project"
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
            HStack(spacing: 6) {
                tabButton(id: "overview", label: "Overview", systemImage: "square.grid.2x2")
                ForEach(state.summaries) { summary in
                    tabButton(
                        id: summary.project.projectID,
                        label: summary.project.name,
                        systemImage: "folder"
                    )
                }
            }
        }
    }

    private func tabButton(id: String, label: String, systemImage: String) -> some View {
        let selected = state.selectedTab == id
        return Button {
            state.selectedTab = id
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(label)
                    .lineLimit(1)
            }
            .font(PBFont.tab)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if isOverview {
            OverviewCard()
        } else if let summary = state.summaries.first(where: { $0.project.projectID == state.selectedTab }) {
            ProjectCard(summary: summary)
        } else {
            Text("No project selected")
                .font(PBFont.meta)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await state.refresh(runBackfill: true) }
            } label: {
                Label("Refresh + Backfill", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderless)

            if !isOverview,
               let summary = state.summaries.first(where: { $0.project.projectID == state.selectedTab }) {
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: summary.project.path))
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }
                .buttonStyle(.borderless)
            }

            Button {
                showingSettings = true
            } label: {
                Label("Settings…", systemImage: "gear")
            }
            .buttonStyle(.borderless)

            Button {
                AppDelegate.shared?.userRequestedQuit = true
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit ProjectBar", systemImage: "xmark.circle")
            }
            .buttonStyle(.borderless)
        }
        .font(PBFont.menuAction)
    }
}
