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
                            Text(user.name).font(.body.bold())
                            Text(user.email).font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 4)
                }
                if authSession.workspaces.isEmpty {
                    LabeledContent("Workspace", value: "No workspace")
                } else {
                    Picker("Workspace", selection: workspaceSelection) {
                        ForEach(authSession.workspaces) { workspace in
                            Text(workspace.name).tag(workspace.id)
                        }
                    }
                    .disabled(authSession.workspaces.count == 1)
                }
            }

            Section("Configure") {
                NavigationLink("Agents") { ComingSoonView(title: "Agents") }
                NavigationLink("Autopilots") { ComingSoonView(title: "Autopilots") }
                NavigationLink("Runtimes") { ComingSoonView(title: "Runtimes") }
                NavigationLink("Skills") { ComingSoonView(title: "Skills") }
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

struct ComingSoonView: View {
    let title: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "clock", description: Text("Available in v2."))
            .navigationTitle(title)
    }
}
#endif
