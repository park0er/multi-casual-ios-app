import SwiftUI
import UserNotifications
import UIKit
import MultiCasual

struct RootView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var selectedTab: AppTab = AppTab.debugInitialTab

    enum AppTab: Hashable {
        case inbox, issues, projects, settings

        static var debugInitialTab: AppTab {
            #if DEBUG
            switch ProcessInfo.processInfo.environment["MULTICA_DEBUG_INITIAL_TAB"] {
            case "issues": return .issues
            case "projects": return .projects
            case "settings": return .settings
            default: return .inbox
            }
            #else
            return .inbox
            #endif
        }
    }

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

            NavigationStack { debugInitialIssueView }
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

    @ViewBuilder
    private var debugInitialIssueView: some View {
        #if DEBUG
        if let taskId = ProcessInfo.processInfo.environment["MULTICA_DEBUG_INITIAL_TASK_ID"], !taskId.isEmpty {
            AgentTranscriptView(taskId: taskId)
        } else if let issueId = ProcessInfo.processInfo.environment["MULTICA_DEBUG_INITIAL_ISSUE_ID"], !issueId.isEmpty {
            IssueDetailView(issueId: issueId)
        } else {
            IssueListView()
        }
        #else
        IssueListView()
        #endif
    }

    private func requestPushPermission() {
        #if DEBUG
        if ProcessInfo.processInfo.environment["MULTICA_DEBUG_SKIP_PUSH_PROMPT"] == "1" {
            return
        }
        #endif
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
