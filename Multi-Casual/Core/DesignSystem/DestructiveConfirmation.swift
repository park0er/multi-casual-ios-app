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

    public static func archiveInboxBulk(_ action: InboxBulkArchiveAction) -> DestructiveConfirmation {
        DestructiveConfirmation(
            title: action.confirmationTitle,
            message: action.confirmationMessage,
            confirmTitle: "Archive"
        )
    }

    public static func deleteIssue(identifier: String?, title: String?) -> DestructiveConfirmation {
        let id = identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let issueTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = id?.isEmpty == false ? id! : (issueTitle?.isEmpty == false ? issueTitle! : "this issue")
        return DestructiveConfirmation(
            title: "Delete \(subject)?",
            message: "This removes the issue and its activity from the workspace. This action cannot be undone.",
            confirmTitle: "Delete"
        )
    }

    public static func deleteAttachment(filename: String) -> DestructiveConfirmation {
        let name = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = name.isEmpty ? "this attachment" : "\"\(name)\""
        return DestructiveConfirmation(
            title: "Delete \(subject)?",
            message: "This removes the file from the issue. This action cannot be undone.",
            confirmTitle: "Delete"
        )
    }

    public static func deleteIssues(count: Int) -> DestructiveConfirmation {
        let noun = count == 1 ? "issue" : "issues"
        return DestructiveConfirmation(
            title: "Delete \(count) \(noun)?",
            message: "This removes the selected \(noun) and their activity from the workspace. This action cannot be undone.",
            confirmTitle: "Delete"
        )
    }

    public static func cancelTask(id: String) -> DestructiveConfirmation {
        let taskId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = taskId.isEmpty ? "this task" : "task \(taskId)"
        return DestructiveConfirmation(
            title: "Cancel \(subject)?",
            message: "The running agent task will be cancelled. Existing messages and history stay available.",
            confirmTitle: "Cancel Task",
            cancelTitle: "Keep Running"
        )
    }

    public static func archiveAgent(name: String) -> DestructiveConfirmation {
        let agentName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = agentName.isEmpty ? "this agent" : "\"\(agentName)\""
        return DestructiveConfirmation(
            title: "Archive agent \(subject)?",
            message: "The agent will be hidden from active workflows and can be restored later.",
            confirmTitle: "Archive",
            cancelTitle: "Cancel"
        )
    }

    public static func cancelAgentTasks(name: String) -> DestructiveConfirmation {
        let agentName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = agentName.isEmpty ? "this agent" : "\"\(agentName)\""
        return DestructiveConfirmation(
            title: "Cancel active tasks for \(subject)?",
            message: "All currently running tasks for this agent will be cancelled. Existing messages and history stay available.",
            confirmTitle: "Cancel Tasks",
            cancelTitle: "Keep Running"
        )
    }

    public static func deleteProject(name: String) -> DestructiveConfirmation {
        let projectName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = projectName.isEmpty ? "this project" : "\"\(projectName)\""
        return DestructiveConfirmation(
            title: "Delete \(subject)?",
            message: "This removes the project from the workspace. Linked issues stay available.",
            confirmTitle: "Delete",
            cancelTitle: "Cancel"
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
            Text(MarkdownRenderer.attributedString(from: confirmation.message))
        }
    }
}
#endif
