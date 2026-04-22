import SwiftUI
import UserNotifications
import UIKit
import MultiCasual

@main
struct Multi-CasualMain: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var authSession = AuthSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authSession)
                .task {
                    let api = APIClient(authSession: authSession)
                    await authSession.restore(using: api)
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
