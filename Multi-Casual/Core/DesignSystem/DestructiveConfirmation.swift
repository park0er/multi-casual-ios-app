import Foundation

public struct DestructiveConfirmation: Equatable, Sendable {
    public let title: String
    public let message: String
    public let confirmTitle: String
    public let cancelTitle: String

    public init(title: String, message: String, confirmTitle: String, cancelTitle: String = "Cancel") {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
    }

    public static func logout(workspaceName: String?) -> DestructiveConfirmation {
        let target = workspaceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = target?.isEmpty == false ? "Log out of \(target!)?" : "Log out?"
        return DestructiveConfirmation(
            title: title,
            message: "You will need to sign in again to use this workspace.",
            confirmTitle: "Log Out"
        )
    }

    public static func archiveInboxItem(issueTitle: String) -> DestructiveConfirmation {
        let title = issueTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = title.isEmpty ? "This notification" : title
        return DestructiveConfirmation(
            title: "Archive this notification?",
            message: "\(subject) will be removed from Inbox.",
            confirmTitle: "Archive"
        )
    }
}

#if canImport(SwiftUI)
import SwiftUI

public extension View {
    func destructiveConfirmation(
        _ confirmation: DestructiveConfirmation,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        alert(
            confirmation.title,
            isPresented: isPresented
        ) {
            Button(confirmation.confirmTitle, role: .destructive, action: onConfirm)
            Button(confirmation.cancelTitle, role: .cancel, action: onCancel)
        } message: {
            Text(confirmation.message)
        }
    }
}
#endif
