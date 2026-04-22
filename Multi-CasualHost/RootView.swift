import SwiftUI
import UserNotifications
import UIKit
import MultiCasual

struct RootView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var selectedTab: AppTab = .inbox

    enum AppTab: Hashable { case inbox, issues, projects, settings }

    var body: some View {
        Group {
            if authSession.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if authSession.isAuthenticated {
                mainTabView
                    .onReceive(NotificationCenter.default.publisher(for: .didRegisterPushToken)) { note in
                        guard let token = note.object as? String else { return }
                        Task { try? await api.registerPushToken(token) }
                    }
            } else {
                LoginView()
            }
        }
        .onOpenURL { url in handleDeepLink(url) }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { InboxView() }
                .tabItem { Label("Inbox", systemImage: "tray") }
                .tag(AppTab.inbox)

            NavigationStack { IssueListView() }
                .tabItem { Label("Issues", systemImage: "checklist") }
                .tag(AppTab.issues)

            NavigationStack { ProjectsView() }
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(AppTab.projects)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .onAppear { requestPushPermission() }
    }

    private func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "ai.multica.app" else { return }
        switch url.host {
        case "inbox": selectedTab = .inbox
        case "issues": selectedTab = .issues
        default: break
        }
    }
}
