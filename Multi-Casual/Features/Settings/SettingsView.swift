#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SettingsView: View {
    @Environment(AuthSession.self) private var authSession
    @State private var showingLogoutConfirmation = false

    public init() {}

    public var body: some View {
        List {
            Section("Account") {
                if let user = authSession.currentUser {
                    HStack {
                        Image(systemName: "person.circle.fill").font(.title2).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            MarkdownText(user.name).font(.body.bold())
                            MarkdownText(user.email).font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 4)
                }
                if authSession.workspaces.isEmpty {
                    LabeledContent("Workspace", value: "No workspace")
                } else {
                    Picker("Workspace", selection: workspaceSelection) {
                        ForEach(authSession.workspaces) { workspace in
                            MarkdownText(workspace.name).tag(workspace.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .accessibilityIdentifier("SettingsWorkspacePicker")
                    .accessibilityValue("Current workspace: \(authSession.currentWorkspace?.name ?? "None"). Workspace options loaded: \(authSession.workspaces.count)")
                }
            }

            Section("Configure") {
                NavigationLink("Workspaces") { WorkspaceAccessView() }
                NavigationLink("Workspace Details") { WorkspaceSettingsView() }
                NavigationLink("Members") { WorkspaceMembersView() }
                NavigationLink("Notifications") { NotificationPreferencesView() }
                NavigationLink("API Tokens") { PersonalAccessTokensView() }
                NavigationLink("Labels") { LabelsView() }
                NavigationLink("Agents") { AgentsView() }
                NavigationLink("Autopilots") { AutopilotsView() }
                NavigationLink("Runtimes") { RuntimesView() }
                NavigationLink("Skills") { SkillsView() }
            }

            Section {
                Button("Log Out", role: .destructive) {
                    showingLogoutConfirmation = true
                }
            }
        }
        .navigationTitle("Settings")
        .destructiveConfirmation(
            logoutConfirmation,
            isPresented: $showingLogoutConfirmation
        ) {
            Task {
                await WebSocketActor.shared.disconnect()
                authSession.logout()
            }
        }
    }

    private var logoutConfirmation: DestructiveConfirmation {
        DestructiveConfirmation.logout(workspaceName: authSession.currentWorkspace?.name)
    }

    private var workspaceSelection: Binding<String> {
        Binding(
            get: { authSession.currentWorkspace?.id ?? "" },
            set: { workspaceId in
                guard let workspace = authSession.workspaces.first(where: { $0.id == workspaceId }) else { return }
                authSession.setWorkspace(workspace)
            }
        )
    }
}

#endif
