import XCTest

final class MarkdownCoverageTests: XCTestCase {
    func test_dynamicUserAndBackendTextUsesMarkdownRendering() throws {
        let sourceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let forbiddenPatterns: [(path: String, pattern: String)] = [
            (
                "Multi-Casual/Features/Auth/OTPView.swift",
                #"            Text("We sent a code to **"#
            ),
            (
                "Multi-Casual/Features/Issues/IssueCreateSheet.swift",
                "                        LabeledContent(assignee.subtitle"
            ),
            (
                "Multi-Casual/Features/Settings/AgentsView.swift",
                #"                        LabeledContent("Runtime", value: agent?.runtimeId"#
            ),
            (
                "Multi-Casual/Features/Issues/IssueListView.swift",
                "                        Label(option.displayName, systemImage:"
            ),
            (
                "Multi-Casual/Features/Chat/ChatView.swift",
                "                            Text(agent.name).tag(agent.id)"
            ),
            (
                "Multi-Casual/Features/Chat/ChatView.swift",
                "        .navigationTitle(session.title)"
            ),
            (
                "Multi-Casual/Features/Projects/ProjectDetailView.swift",
                "        .navigationTitle(project.name)"
            ),
            (
                "Multi-Casual/Features/Settings/AutopilotsView.swift",
                "        .navigationTitle(item.title)"
            ),
            (
                "Multi-Casual/Features/Settings/RuntimesView.swift",
                "        .navigationTitle(runtime.name)"
            ),
            (
                "Multi-Casual/Features/Settings/WorkspaceAccessView.swift",
                "                        Text(action.message)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "        .navigationTitle(viewModel?.issue?.identifier ?? \"\")"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                        Text(parentIssue.identifier)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                        Text(child.identifier)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueListView.swift",
                "                Text(issue.identifier).font(.caption).foregroundStyle(.secondary)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueCreateSheet.swift",
                "                        Label(parentIssueIdentifier, systemImage:"
            ),
            (
                "Multi-Casual/Features/Issues/AgentTranscriptView.swift",
                "                                Text(\"#\\(item.id)\").font(.caption2).foregroundStyle(.tertiary)"
            ),
            (
                "Multi-Casual/Features/Settings/AgentsView.swift",
                "        .navigationTitle(\"Agent Detail\")"
            ),
            (
                "Multi-Casual/Features/Issues/IssueListView.swift",
                "                            Text(IssueListViewModel.Scope.assignedToMe.displayName)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueListView.swift",
                "                                    Label(priority.displayName, systemImage:"
            ),
            (
                "Multi-Casual/Features/Issues/IssueListView.swift",
                "                    description: Text(vm.scope.emptyDescription)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueListView.swift",
                "                            Text(status.displayName).font(.caption.bold())"
            ),
            (
                "Multi-Casual/Features/Issues/IssueListView.swift",
                "                Label(childProgressText, systemImage: \"checklist\")"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                            Text(vm.parentChildProgressText)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                            Label(status.displayName, systemImage: status.icon)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                    Label(issue.status.displayName, systemImage: issue.status.icon)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                    Text(vm.childProgressText)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                Text(fileDetails)"
            ),
            (
                "Multi-Casual/Features/Issues/AgentTranscriptView.swift",
                "                                Text(labelForType(item.type)).font(.caption.bold()).foregroundStyle(.secondary)"
            ),
            (
                "Multi-Casual/Features/Projects/ProjectsView.swift",
                "                                        Label(project.status.displayName, systemImage: project.status.icon)"
            ),
            (
                "Multi-Casual/Features/Projects/ProjectsView.swift",
                "                            Label(status.displayName, systemImage: status.icon).tag(status)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueCreateSheet.swift",
                "                            Label(status.displayName, systemImage: status.icon)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueCreateSheet.swift",
                "                            Text(priority.displayName).tag(priority)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueEditSheet.swift",
                "                                    Text(status.displayName).tag(status)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueEditSheet.swift",
                "                                    Text(priority.displayName).tag(priority)"
            ),
            (
                "Multi-Casual/Features/Inbox/InboxView.swift",
                "                            Label(InboxBulkArchiveAction.read.menuTitle, systemImage:"
            ),
            (
                "Multi-Casual/Features/Settings/PersonalAccessTokensView.swift",
                "                                Text(option.title).tag(option)"
            )
        ]

        for forbidden in forbiddenPatterns {
            let fileURL = sourceRoot.appendingPathComponent(forbidden.path)
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertFalse(
                source.contains(forbidden.pattern),
                "\(forbidden.path) still renders dynamic text without Markdown support."
            )
        }
    }
}
