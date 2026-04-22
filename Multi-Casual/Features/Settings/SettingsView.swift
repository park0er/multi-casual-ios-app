#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SettingsView: View {
    @Environment(AuthSession.self) private var authSession

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
                if let ws = authSession.currentWorkspace {
                    LabeledContent("Workspace", value: ws.name)
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
                    Task {
                        await WebSocketActor.shared.disconnect()
                        authSession.logout()
                    }
                }
            }
        }
        .navigationTitle("Settings")
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
