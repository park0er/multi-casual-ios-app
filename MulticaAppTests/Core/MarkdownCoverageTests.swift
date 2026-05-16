import XCTest

final class MarkdownCoverageTests: XCTestCase {
    func test_markdownTextEnablesRenderedTextSelection() throws {
        let sourceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fileURL = sourceRoot.appendingPathComponent("Multi-Casual/Features/Common/MarkdownText.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertTrue(
            source.contains(".selectableRenderedText()"),
            "MarkdownText should apply selectableRenderedText() so member and agent rendered text can be long-pressed, selected, and copied."
        )
        XCTAssertTrue(
            source.contains("textSelection(.enabled)"),
            "selectableRenderedText() should enable SwiftUI text selection."
        )
    }

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
            ),
            (
                "Multi-Casual/Features/Issues/IssueListView.swift",
                "                    Button(status.displayName) { onStatus(status) }"
            ),
            (
                "Multi-Casual/Features/Issues/IssueListView.swift",
                "                    Button(priority.displayName) { onPriority(priority) }"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                Text(comment.authorType == \"agent\" ? \"Agent\" : \"Member\")"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                Text(run.startedAt.map(iso8601DisplayFormatter.string(from:)) ?? \"\")"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                    Text(iso8601DateOnlyFormatter.string(from: entry.createdAt))"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "            Text(value.formatted())"
            ),
            (
                "Multi-Casual/Features/Issues/IssueCreateSheet.swift",
                "                                Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.sizeBytes), countStyle: .file))"
            ),
            (
                "Multi-Casual/Features/Chat/ChatView.swift",
                "                    Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))"
            ),
            (
                "Multi-Casual/Features/Inbox/InboxView.swift",
                "                Text(item.createdAt, style: .relative)"
            ),
            (
                "Multi-Casual/Features/Settings/WorkspaceAccessView.swift",
                "                        Button(action.confirmTitle, role: .destructive)"
            ),
            (
                "Multi-Casual/Features/Settings/AgentsView.swift",
                "                    Text(completedAt.formatted(date: .abbreviated, time: .shortened))"
            ),
            (
                "Multi-Casual/Features/Settings/AgentsView.swift",
                "                    Text(startedAt.formatted(date: .abbreviated, time: .shortened))"
            ),
            (
                "Multi-Casual/Features/Settings/AgentsView.swift",
                #"                        Text("Runs \(runCount.formatted())")"#
            ),
            (
                "Multi-Casual/Features/Settings/AutopilotsView.swift",
                "                    Text(\"Next \\(nextRunAt.formatted(date: .abbreviated, time: .shortened))\")"
            ),
            (
                "Multi-Casual/Features/Settings/AutopilotsView.swift",
                "                Text(run.triggeredAt.formatted(date: .abbreviated, time: .shortened))"
            ),
            (
                "Multi-Casual/Features/Issues/IssueListView.swift",
                #"                            Text("(\(issues.count))").font(.caption).foregroundStyle(.secondary)"#
            ),
            (
                "Multi-Casual/Features/Projects/ProjectDetailView.swift",
                #"                    Section("Resources (\(vm.resources.count))")"#
            ),
            (
                "Multi-Casual/Features/Projects/ProjectDetailView.swift",
                #"                    Section("Issues (\(vm.issues.count))")"#
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                #"                    Text("\(badge.emoji) \(badge.count)")"#
            ),
            (
                "Multi-Casual/Features/Issues/AgentLiveView.swift",
                #"                        Text("\(timeline.count) events").font(.caption).foregroundStyle(.secondary)"#
            ),
            (
                "Multi-Casual/Features/Chat/ChatView.swift",
                #"                Text("Replied in \(max(1, elapsedMs / 1000))s")"#
            ),
            (
                "Multi-Casual/Features/Auth/OTPView.swift",
                #"                    Text("Resend in \(viewModel.cooldownSeconds)s").foregroundStyle(.secondary)"#
            ),
            (
                "Multi-Casual/Features/Auth/OTPView.swift",
                "                    Text(char).font(.title2.bold())"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "            Text(title)"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                #"                        Text(vm.isSubscribed(userId: currentUserId, userType: "member") ? "Unsubscribe" : "Subscribe")"#
            ),
            (
                "Multi-Casual/Features/Chat/ChatView.swift",
                #"                        Label(viewModel.isCancellingTask ? "Cancelling" : "Cancel Task", systemImage:"#
            ),
            (
                "Multi-Casual/Features/Chat/ChatView.swift",
                #"                    Button(viewModel.isCreating ? "Creating" : "Create")"#
            ),
            (
                "Multi-Casual/Features/Settings/PersonalAccessTokensView.swift",
                #"                        Label(copied ? "Copied" : "Copy Token", systemImage:"#
            ),
            (
                "Multi-Casual/Features/Settings/RuntimesView.swift",
                #"                            Label(vm.isUpdatingRuntime ? "Updating Runtime" : "Update Runtime", systemImage:"#
            ),
            (
                "Multi-Casual/Features/Settings/RuntimesView.swift",
                #"                                Label(vm.isUpdatingRuntime ? "Refreshing Update Status" : "Refresh Update Status", systemImage:"#
            ),
            (
                "Multi-Casual/Features/Settings/RuntimesView.swift",
                #"                            Label(vm.isRefreshingModels ? "Refreshing Models" : "Refresh Models", systemImage:"#
            ),
            (
                "Multi-Casual/Features/Settings/RuntimesView.swift",
                #"                            Label(vm.isRefreshingLocalSkills ? "Refreshing Local Skills" : "Refresh Local Skills", systemImage:"#
            ),
            (
                "Multi-Casual/Features/Settings/RuntimesView.swift",
                #"                                Label(vm.isImportingLocalSkill ? "Refreshing Import Status" : "Refresh Import Status", systemImage:"#
            ),
            (
                "Multi-Casual/Core/DesignSystem/DestructiveConfirmation.swift",
                "            confirmation.title,"
            ),
            (
                "Multi-Casual/Core/DesignSystem/DestructiveConfirmation.swift",
                "            Button(confirmation.confirmTitle, role: .destructive"
            ),
            (
                "Multi-Casual/Core/DesignSystem/DestructiveConfirmation.swift",
                "            Button(confirmation.cancelTitle, role: .cancel"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                    Button(emoji) {"
            ),
            (
                "Multi-Casual/Features/Issues/IssueDetailView.swift",
                "                            Label(\n                                pinViewModel.isPinned ? \"Unpin Issue\" : \"Pin Issue\","
            ),
            (
                "Multi-Casual/Features/Projects/ProjectDetailView.swift",
                "                        Label(\n                            pinViewModel.isPinned ? \"Unpin Project\" : \"Pin Project\","
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
