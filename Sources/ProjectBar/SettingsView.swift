import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ProjectBarCore

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var dollarsText: String = ""
    @State private var budgetText: String = ""
    @State private var refreshText: String = ""

    var body: some View {
        Form {
            Section("Projects") {
                ForEach(state.config.projects) { project in
                    HStack {
                        VStack(alignment: .leading) {
                            TextField(
                                "Display name",
                                text: bindingName(for: project)
                            )
                            Text(project.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Button(role: .destructive) {
                            state.removeProject(project)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add Project Folder…") {
                    pickFolder()
                }
            }

            Section("Cost & Budgets") {
                TextField("$ per 1M tokens", text: $dollarsText)
                    .onSubmit { applyNumbers() }
                TextField("Monthly token budget (optional)", text: $budgetText)
                    .onSubmit { applyNumbers() }
                TextField("Refresh interval (seconds)", text: $refreshText)
                    .onSubmit { applyNumbers() }
                Button("Apply") { applyNumbers() }
            }

            Section("Cursor Hooks") {
                HStack {
                    Image(systemName: state.hooksInstalled ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(state.hooksInstalled ? .green : .secondary)
                    Text(state.hooksInstalled ? "Hooks installed" : "Hooks not installed")
                    Spacer()
                }
                Button("Install Cursor Hooks") { state.installHooks() }
                Button("Uninstall Cursor Hooks", role: .destructive) { state.uninstallHooks() }
                Text("User-level hooks write live session events into ProjectBar’s local store. Fail-open: never blocks the agent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Menu Bar") {
                Picker("Display", selection: $state.config.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases, id: \.self) { style in
                        Text(style.label).tag(style)
                    }
                }
                .onChange(of: state.config.menuBarStyle) { _, _ in
                    state.saveConfig()
                }
                Text("Default is a chart icon plus today’s total tokens — quieter than a full project name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $state.config.launchAtLogin)
                    .onChange(of: state.config.launchAtLogin) { _, _ in
                        state.saveConfig()
                    }
                if let msg = state.backfillMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .onAppear {
            dollarsText = String(state.config.dollarsPerMillionTokens)
            budgetText = state.config.monthlyTokenBudget.map(String.init) ?? ""
            refreshText = String(state.config.refreshIntervalSeconds)
        }
    }

    private func bindingName(for project: AllowlistedProject) -> Binding<String> {
        Binding(
            get: {
                state.config.projects.first { $0.projectID == project.projectID }?.displayName
                    ?? project.name
            },
            set: { newValue in
                guard let idx = state.config.projects.firstIndex(where: { $0.projectID == project.projectID }) else { return }
                state.config.projects[idx].displayName = newValue
                state.saveConfig()
            }
        )
    }

    private func applyNumbers() {
        if let v = Double(dollarsText) {
            state.config.dollarsPerMillionTokens = v
        }
        if budgetText.trimmingCharacters(in: .whitespaces).isEmpty {
            state.config.monthlyTokenBudget = nil
        } else if let v = Int(budgetText) {
            state.config.monthlyTokenBudget = v
        }
        if let v = Int(refreshText), v >= 15 {
            state.config.refreshIntervalSeconds = v
        }
        state.saveConfig()
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        if panel.runModal() == .OK, let url = panel.url {
            state.addProject(path: url.path)
        }
    }
}
