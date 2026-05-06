import SwiftUI
import UserNotifications
import UIKit
import MultiCasual

@main
struct Multi-CasualMain: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authSession = AuthSession()
    @State private var apiClient = APIClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authSession)
                .environment(apiClient)
                .task {
                    apiClient.configure(authSession: authSession)
                    #if DEBUG
                    let env = ProcessInfo.processInfo.environment
                    if env["MULTICA_DEBUG_AUTH_STUB"] == "1" {
                        authSession.currentUser = User(
                            id: "debug-user",
                            email: "debug@example.com",
                            name: "Debug User",
                            avatarUrl: nil
                        )
                        let workspace = Workspace(
                            id: env["MULTICA_DEBUG_WORKSPACE_ID"] ?? "debug-workspace",
                            name: env["MULTICA_DEBUG_WORKSPACE_NAME"] ?? "Debug Workspace",
                            slug: env["MULTICA_DEBUG_WORKSPACE_SLUG"] ?? "debug",
                            issuePrefix: env["MULTICA_DEBUG_WORKSPACE_PREFIX"] ?? "DBG"
                        )
                        authSession.workspaces = [workspace]
                        authSession.currentWorkspace = workspace
                        authSession.isLoading = false
                        return
                    }
                    try? authSession.installDebugToken(env["MULTICA_DEBUG_TOKEN"])
                    let preferredWorkspaceId = env["MULTICA_DEBUG_WORKSPACE_ID"]
                    #else
                    let preferredWorkspaceId: String? = nil
                    #endif
                    await authSession.restore(using: apiClient, preferredWorkspaceId: preferredWorkspaceId)
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .didRegisterPushToken, object: token)
    }
}

extension Notification.Name {
    static let didRegisterPushToken = Notification.Name("didRegisterPushToken")
}
