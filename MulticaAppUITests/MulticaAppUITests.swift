import XCTest

final class Multi-CasualUITests: XCTestCase {
    private let workspaceId = "7f97e6b9-2db3-489c-a270-4e4c6d354469"
    private let workspaceName = "park0er"
    private let par73IssueId = "9a808431-341f-4ead-8d8c-055e2e00686e"
    private let projectId = "f96f29f2-abbd-4aae-8962-f44a2c68c3aa"
    private let memberUserId = "4b05a80a-fa79-45e6-8568-f3bf08e7057b"
    private let memberDisplayName = "XishengGmail"
    private let agentDisplayName = "RollieCC"
    private let transcriptTaskId = "9eab0d97-de00-4f90-82a6-d70cbb5161a2"
    private let backendTimeoutMessage = "The server took too long to respond. Please try again."
    private let mutationFlagDirectory = URL(fileURLWithPath: "/tmp/multica-ui-mutation-tests", isDirectory: true)
    private let debugTokenFile = URL(fileURLWithPath: "/tmp/multica-ui-debug-token")
    private let debugNetworkLogFile = URL(fileURLWithPath: "/tmp/multica-ui-network-log")

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLoginScreenRendersAndEnablesContinueWithoutSendingCode() {
        let app = launchLoggedOutApp()

        XCTAssertTrue(app.staticTexts["Sign in to Multica"].waitForExistence(timeout: 20))
        let emailField = app.textFields["LoginEmailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 10))
        let continueButton = app.buttons["LoginContinueButton"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertFalse(continueButton.isEnabled)

        emailField.tap()
        emailField.typeText("parker@example.com")

        XCTAssertTrue(waitForEnabled(continueButton, timeout: 5))
    }

    func testSettingsWorkspaceScreenRenders() {
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 10))
        let workspacePicker = app.buttons["SettingsWorkspacePicker"]
        XCTAssertTrue(workspacePicker.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(workspacePicker, timeout: 10) { value in
            value.contains("Current workspace: \(workspaceName)")
        })
        XCTAssertTrue(app.buttons["Log Out"].exists)
        app.buttons["Log Out"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
    }

    func testSettingsWorkspacePickerShowsAvailableWorkspace() {
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        let workspacePicker = app.buttons["SettingsWorkspacePicker"]
        XCTAssertTrue(workspacePicker.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(workspacePicker, timeout: 10) { value in
            value.contains("Workspace options loaded:") && !value.contains("Workspace options loaded: 0")
        })
        workspacePicker.tap()

        XCTAssertTrue(app.navigationBars["Workspace"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[workspaceName].waitForExistence(timeout: 10))
    }

    func testSettingsWorkspacePickerSwitchesToAnotherWorkspaceWhenAvailable() throws {
        let app = launchApp(initialTab: "settings", useWorkspaceOverride: false)

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        let workspacePicker = app.buttons["SettingsWorkspacePicker"]
        XCTAssertTrue(workspacePicker.waitForExistence(timeout: 10))
        let initialValue = waitForWorkspacePickerValue(workspacePicker, timeout: 10)
        let initialWorkspace = currentWorkspaceName(from: initialValue) ?? workspaceName
        guard (workspaceOptionCount(from: initialValue) ?? 0) > 1 else {
            throw XCTSkip("Only one workspace is available for this account.")
        }

        workspacePicker.tap()
        XCTAssertTrue(app.navigationBars["Workspace"].waitForExistence(timeout: 10))

        let alternate = try alternateWorkspaceButton(in: app, excluding: initialWorkspace)
        let alternateName = alternate.label
        alternate.tap()

        XCTAssertTrue(waitForValue(workspacePicker, timeout: 10) { value in
            value.contains("Current workspace: \(alternateName)")
        })

        workspacePicker.tap()
        XCTAssertTrue(app.navigationBars["Workspace"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[initialWorkspace].waitForExistence(timeout: 10))
        app.buttons[initialWorkspace].tap()
        XCTAssertTrue(waitForValue(workspacePicker, timeout: 10) { value in
            value.contains("Current workspace: \(initialWorkspace)")
        })
    }

    func testSettingsWorkspaceRestoresAcrossRelaunchWithoutDebugWorkspaceOverride() {
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        let workspacePicker = app.buttons["SettingsWorkspacePicker"]
        XCTAssertTrue(workspacePicker.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(workspacePicker, timeout: 10) { value in
            value.contains("Current workspace: \(workspaceName)")
        })

        app.terminate()

        let relaunchedApp = launchApp(initialTab: "settings", useWorkspaceOverride: false)
        XCTAssertTrue(relaunchedApp.staticTexts["Settings"].waitForExistence(timeout: 20))
        let restoredWorkspacePicker = relaunchedApp.buttons["SettingsWorkspacePicker"]
        XCTAssertTrue(restoredWorkspacePicker.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(restoredWorkspacePicker, timeout: 10) { value in
            value.contains("Current workspace: \(workspaceName)")
        })
    }

    func testSettingsAgentsScreenRenders() {
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Agents"].waitForExistence(timeout: 10))
        app.buttons["Agents"].tap()

        XCTAssertTrue(app.staticTexts["Agents"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["AgentsNewButton"].waitForExistence(timeout: 10))
    }

    func testSettingsAutopilotsScreenRenders() {
        let app = launchStubbedAuthenticatedApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Autopilots"].waitForExistence(timeout: 10))
        app.buttons["Autopilots"].tap()

        XCTAssertTrue(app.staticTexts["Autopilots"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["AutopilotsNewButton"].waitForExistence(timeout: 10))
    }

    func testSettingsRuntimesScreenRenders() {
        let app = launchStubbedAuthenticatedApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Runtimes"].waitForExistence(timeout: 10))
        app.buttons["Runtimes"].tap()

        XCTAssertTrue(app.staticTexts["Runtimes"].waitForExistence(timeout: 20))
    }

    func testSettingsSkillsScreenRenders() {
        let app = launchStubbedAuthenticatedApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Skills"].waitForExistence(timeout: 10))
        app.buttons["Skills"].tap()

        XCTAssertTrue(app.staticTexts["Skills"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["SkillsNewButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["SkillsImportButton"].waitForExistence(timeout: 10))
    }

    func testCreateIssueSheetRendersRequiredFields() {
        let app = launchApp(initialTab: "issues", openCreateSheet: true)

        XCTAssertTrue(app.navigationBars["New Issue"].waitForExistence(timeout: 20))
        let titleField = app.textFields["Issue title"]
        XCTAssertTrue(titleField.exists)
        XCTAssertTrue(app.staticTexts["Description"].exists)
        XCTAssertTrue(app.staticTexts["Status"].exists)
        XCTAssertTrue(app.staticTexts["Priority"].exists)
        XCTAssertTrue(app.staticTexts["Assignee"].exists)
        XCTAssertTrue(app.staticTexts["Project"].exists)
        XCTAssertTrue(app.staticTexts["Due Date"].exists)

        titleField.tap()
        titleField.typeText("UI smoke draft")
        XCTAssertTrue(app.buttons["Create"].isEnabled)
    }

    func testCreateIssueAssigneePickerShowsMembersAndAgents() {
        let app = launchApp(initialTab: "issues", openCreateSheet: true)

        XCTAssertTrue(app.navigationBars["New Issue"].waitForExistence(timeout: 20))
        let assigneePicker = app.buttons["IssueCreateAssigneePicker"]
        XCTAssertTrue(assigneePicker.waitForExistence(timeout: 20))
        XCTAssertTrue(waitForValue(assigneePicker, timeout: 30) { value in
            value.contains("Assignee options loaded:") && !value.contains("Assignee options loaded: 0")
        })
        assigneePicker.tap()

        XCTAssertTrue(app.buttons["Unassigned"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[memberDisplayName].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[agentDisplayName].waitForExistence(timeout: 10))
    }

    func testIssueListFilterSortAndBoardControlsAreReachable() {
        let app = launchApp(initialTab: "issues")

        XCTAssertTrue(app.staticTexts["Issues"].waitForExistence(timeout: 20))

        let filterMenu = app.buttons["IssuePriorityFilterMenu"]
        XCTAssertTrue(filterMenu.waitForExistence(timeout: 10))
        filterMenu.tap()
        XCTAssertTrue(app.buttons["All Priorities"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Urgent"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["No Priority"].waitForExistence(timeout: 5))
        app.buttons["All Priorities"].tap()

        let sortMenu = app.buttons["IssueSortMenu"]
        XCTAssertTrue(sortMenu.waitForExistence(timeout: 10))
        sortMenu.tap()
        XCTAssertTrue(app.buttons["Default"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Priority"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Updated"].waitForExistence(timeout: 5))
        app.buttons["Default"].tap()

        let boardToggle = app.buttons["IssueViewModeToggle"]
        XCTAssertTrue(boardToggle.waitForExistence(timeout: 10))
        boardToggle.tap()
        XCTAssertTrue(app.staticTexts["Backlog"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Todo"].waitForExistence(timeout: 10))
    }

    func testIssueListBatchSelectionActionsAreReachableWithoutSubmitting() {
        let app = launchApp(initialTab: "issues")

        XCTAssertTrue(app.staticTexts["Issues"].waitForExistence(timeout: 20))
        let selectionToggle = app.buttons["IssueSelectionToggle"]
        XCTAssertTrue(selectionToggle.waitForExistence(timeout: 10))
        selectionToggle.tap()

        let firstIssue = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstIssue.waitForExistence(timeout: 20))
        firstIssue.tap()

        XCTAssertTrue(app.staticTexts["1 selected"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["IssueBatchStatusMenu"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["IssueBatchPriorityMenu"].waitForExistence(timeout: 5))
        let assigneeMenu = app.buttons["IssueBatchAssigneeMenu"]
        XCTAssertTrue(assigneeMenu.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue(assigneeMenu, timeout: 30) { value in
            value.contains("Assignee options loaded:") && !value.contains("Assignee options loaded: 0")
        })
        assigneeMenu.tap()
        XCTAssertTrue(app.buttons[memberDisplayName].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[agentDisplayName].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Delete Selected Issues"].waitForExistence(timeout: 5))
    }

    func testCreateIssueSubmitsToBackendWhenMutationTestsEnabled() throws {
        try requireMutationTestsEnabled(reason: "create a real backend issue")
        guard mutationFlagEnabled(
            environmentKey: "MULTICA_UI_MUTATION_CREATE",
            fileName: "create.enabled"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_CREATE=1 or touch /tmp/multica-ui-mutation-tests/create.enabled to create a real issue.")
        }

        let app = launchApp(initialTab: "issues", openCreateSheet: true)
        let title = "iOS UI mutation \(Int(Date().timeIntervalSince1970))"

        XCTAssertTrue(app.navigationBars["New Issue"].waitForExistence(timeout: 20))
        let titleField = app.textFields["Issue title"]
        XCTAssertTrue(titleField.exists)
        titleField.tap()
        titleField.typeText(title)

        let createButton = app.buttons["Create"]
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()

        XCTAssertTrue(waitForNonExistence(app.navigationBars["New Issue"], timeout: 20))
        XCTAssertTrue(scrollUntilStaticTextExists(title, app: app, timeout: 45))
    }

    func testCreateIssueSubmitsMemberProjectDueDateWhenMutationTestsEnabled() throws {
        try requireMutationTestsEnabled(reason: "create a real backend issue with member, project, and due date")
        guard mutationFlagEnabled(
            environmentKey: "MULTICA_UI_MUTATION_CREATE_FIELDS",
            fileName: "create-fields.enabled"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_CREATE_FIELDS=1 or touch /tmp/multica-ui-mutation-tests/create-fields.enabled to create a real issue with extra fields.")
        }

        let title = mutationValue(
            environmentKey: "MULTICA_UI_MUTATION_CREATE_TITLE",
            fileName: "create-title"
        ) ?? "iOS UI field mutation \(Int(Date().timeIntervalSince1970))"
        let app = launchApp(
            initialTab: "issues",
            openCreateSheet: true,
            createDefaults: [
                "MULTICA_DEBUG_CREATE_TITLE": title,
                "MULTICA_DEBUG_CREATE_STATUS": "todo",
                "MULTICA_DEBUG_CREATE_PRIORITY": "high",
                "MULTICA_DEBUG_CREATE_ASSIGNEE_OPTION_ID": "member:\(memberUserId)",
                "MULTICA_DEBUG_CREATE_PROJECT_ID": projectId,
                "MULTICA_DEBUG_CREATE_DUE_DATE": "2026-12-31T00:00:00Z",
            ]
        )

        XCTAssertTrue(app.navigationBars["New Issue"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.textFields["Issue title"].exists)

        let createButton = app.buttons["Create"]
        XCTAssertTrue(waitForEnabled(createButton, timeout: 30))
        createButton.tap()

        XCTAssertTrue(waitForNonExistence(app.navigationBars["New Issue"], timeout: 20))
    }

    func testInboxSwipeShowsArchiveActionWithoutSubmitting() throws {
        let app = launchApp(initialTab: "inbox")

        XCTAssertTrue(app.staticTexts["Inbox"].waitForExistence(timeout: 20))
        let firstNotification = try firstInboxNotificationCell(in: app)
        revealTrailingActions(on: firstNotification)
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["Archive this notification?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(firstNotification.waitForExistence(timeout: 5))
    }

    func testInboxMarkAllReadToolbarStateWithoutSubmitting() {
        let app = launchApp(initialTab: "inbox")

        XCTAssertTrue(app.staticTexts["Inbox"].waitForExistence(timeout: 20))
        let actionsMenu = app.buttons["InboxActionsMenu"]
        XCTAssertTrue(actionsMenu.waitForExistence(timeout: 10))
        actionsMenu.tap()

        let markAllReadButton = app.buttons["Mark All Read"]
        XCTAssertTrue(markAllReadButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Archive Read"].exists)
        XCTAssertTrue(app.buttons["Archive Completed"].exists)
        XCTAssertTrue(app.buttons["Archive All"].exists)

        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if app.staticTexts[backendTimeoutMessage].exists || app.staticTexts["No Inbox Items"].exists {
                XCTAssertFalse(markAllReadButton.isEnabled)
                return
            }
            if app.staticTexts["Unread"].exists {
                XCTAssertTrue(markAllReadButton.isEnabled)
                return
            }
            if app.staticTexts["Read"].exists {
                XCTAssertFalse(markAllReadButton.isEnabled)
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTFail("Timed out waiting for Inbox toolbar state.")
    }

    func testIssueDetailRendersMetadataCommentsAndInput() throws {
        let app = launchApp(initialTab: "issues", issueId: par73IssueId)

        try waitForElementOrBackendTimeout(
            app.staticTexts["PAR-73"],
            in: app,
            timeout: 20,
            reason: "Issue detail endpoint timed out before metadata coverage could run."
        )
        XCTAssertTrue(app.staticTexts["Agent Activity"].waitForExistence(timeout: 20))
        let commentField = app.descendants(matching: .any)["IssueDetailCommentInput"].firstMatch
        XCTAssertTrue(commentField.waitForExistence(timeout: 10))
        commentField.tap()
        commentField.typeText("UI draft")
        XCTAssertTrue(commentField.value.debugDescription.contains("UI draft"))
        XCTAssertTrue(app.buttons["IssueDetailCommentSendButton"].isEnabled)
    }

    func testIssueDetailEditSheetRendersAssignableFields() throws {
        let app = launchApp(initialTab: "issues", issueId: par73IssueId)

        try waitForElementOrBackendTimeout(
            app.staticTexts["PAR-73"],
            in: app,
            timeout: 20,
            reason: "Issue detail endpoint timed out before edit sheet coverage could run."
        )
        XCTAssertTrue(app.buttons["IssueDetailEditButton"].waitForExistence(timeout: 10))
        app.buttons["IssueDetailEditButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit Issue"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["IssueEditTitleField"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Assignee"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["IssueEditAssigneePicker"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Cancel"].exists)
        app.buttons["Cancel"].tap()
    }

    func testIssueDetailLongCommentsScrollKeepsComposerReachable() {
        let app = launchApp(initialTab: "issues", issueId: par73IssueId)

        XCTAssertTrue(app.staticTexts["Comments"].waitForExistence(timeout: 20))
        let scrollView = app.scrollViews["IssueDetailScrollView"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 10))

        for _ in 0..<3 {
            scrollView.swipeUp()
        }

        let commentField = app.descendants(matching: .any)["IssueDetailCommentInput"].firstMatch
        XCTAssertTrue(commentField.waitForExistence(timeout: 5))
        commentField.tap()
        commentField.typeText("Scroll smoke")
        XCTAssertTrue(commentField.value.debugDescription.contains("Scroll smoke"))
        XCTAssertTrue(app.buttons["IssueDetailCommentSendButton"].isEnabled)
    }

    func testIssueListSwipeShowsDoneActionWithoutSubmitting() {
        let app = launchApp(initialTab: "issues")

        XCTAssertTrue(app.staticTexts["Issues"].waitForExistence(timeout: 20))
        let firstIssue = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstIssue.waitForExistence(timeout: 20))
        let rowButton = firstIssue.buttons.element(boundBy: 0)
        XCTAssertTrue(rowButton.waitForExistence(timeout: 5))
        rowButton.swipeLeft()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
    }

    func testIssueListMarksDoneWhenMutationTestsEnabled() throws {
        try requireMutationTestsEnabled(reason: "mark a disposable issue done from the Issue list")
        guard mutationFlagEnabled(
            environmentKey: "MULTICA_UI_MUTATION_ISSUE_STATUS",
            fileName: "issue-status.enabled"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_ISSUE_STATUS=1 or touch /tmp/multica-ui-mutation-tests/issue-status.enabled to update a disposable issue status.")
        }
        guard let issueTitle = mutationValue(
            environmentKey: "MULTICA_UI_MUTATION_ISSUE_TITLE",
            fileName: "issue-title"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_ISSUE_TITLE or write a disposable issue title to /tmp/multica-ui-mutation-tests/issue-title before updating status.")
        }
        let app = launchApp(initialTab: "issues")

        XCTAssertTrue(app.staticTexts["Issues"].waitForExistence(timeout: 20))
        XCTAssertTrue(scrollUntilStaticTextExists(issueTitle, app: app, timeout: 45))
        let issueCell = app.cells.containing(.staticText, identifier: issueTitle).element(boundBy: 0)
        XCTAssertTrue(issueCell.waitForExistence(timeout: 5))
        let rowButton = issueCell.buttons.element(boundBy: 0)
        XCTAssertTrue(rowButton.waitForExistence(timeout: 5))
        rowButton.swipeLeft()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(waitForNonExistence(app.buttons["Done"], timeout: 10))
    }

    func testIssueDetailSubmitsCommentWhenMutationTestsEnabled() throws {
        try requireMutationTestsEnabled(reason: "post a real backend comment")
        guard mutationFlagEnabled(
            environmentKey: "MULTICA_UI_MUTATION_COMMENT",
            fileName: "comment.enabled"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_COMMENT=1 or touch /tmp/multica-ui-mutation-tests/comment.enabled to post a real comment.")
        }
        guard let issueId = mutationValue(
            environmentKey: "MULTICA_UI_MUTATION_ISSUE_ID",
            fileName: "issue-id"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_ISSUE_ID or write a disposable issue id to /tmp/multica-ui-mutation-tests/issue-id before posting a real comment.")
        }

        let app = launchApp(initialTab: "issues", issueId: issueId)
        let comment = "iOS UI mutation comment \(Int(Date().timeIntervalSince1970))"

        XCTAssertTrue(app.staticTexts["Comments"].waitForExistence(timeout: 20))
        let commentField = app.descendants(matching: .any)["IssueDetailCommentInput"].firstMatch
        XCTAssertTrue(commentField.waitForExistence(timeout: 10))
        commentField.tap()
        commentField.typeText(comment)

        let sendButton = app.buttons["IssueDetailCommentSendButton"]
        XCTAssertTrue(sendButton.isEnabled)
        sendButton.tap()

        XCTAssertTrue(app.staticTexts[comment].waitForExistence(timeout: 30))
    }

    func testAgentTranscriptRendersTimeline() {
        let app = launchApp(initialTab: "issues", taskId: transcriptTaskId)

        XCTAssertTrue(app.staticTexts["Agent Transcript"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Tool Use"].waitForExistence(timeout: 20))
    }

    func testProjectDetailRendersResourcesAndIssues() {
        let app = launchApp(initialTab: "projects", projectId: projectId)

        XCTAssertTrue(app.staticTexts["Multica iOS App"].waitForExistence(timeout: 20))
        XCTAssertTrue(staticText(in: app, beginsWith: "Resources").waitForExistence(timeout: 20))
        XCTAssertTrue(staticText(in: app, beginsWith: "Issues").waitForExistence(timeout: 20))
    }

    func testProjectCreateSheetOpensWithoutSubmitting() {
        let app = launchApp(initialTab: "projects")

        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 20))
        let newProjectButton = app.buttons["ProjectsNewButton"]
        XCTAssertTrue(newProjectButton.waitForExistence(timeout: 10))
        newProjectButton.tap()

        XCTAssertTrue(app.navigationBars["New Project"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["ProjectTitleField"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
    }

    func testInboxMarksReadAndArchivesWhenMutationTestsEnabled() throws {
        try requireMutationTestsEnabled(reason: "mark a real inbox item read and archive it")
        guard mutationFlagEnabled(
            environmentKey: "MULTICA_UI_MUTATION_INBOX_ACTIONS",
            fileName: "inbox-actions.enabled"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_INBOX_ACTIONS=1 or touch /tmp/multica-ui-mutation-tests/inbox-actions.enabled to mutate a real Inbox item.")
        }

        let app = launchApp(initialTab: "inbox")

        XCTAssertTrue(app.staticTexts["Inbox"].waitForExistence(timeout: 20))
        guard let unreadCell = try firstUnreadInboxNotificationCell(in: app) else {
            throw XCTSkip("No unread Inbox item is available to mark read.")
        }

        revealLeadingActions(on: unreadCell)
        XCTAssertTrue(app.buttons["Read"].waitForExistence(timeout: 5))
        app.buttons["Read"].tap()
        XCTAssertTrue(unreadCell.staticTexts["Read"].waitForExistence(timeout: 10))

        revealTrailingActions(on: unreadCell)
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["Archive this notification?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()
        XCTAssertTrue(waitForNonExistence(unreadCell, timeout: 10))
    }

    private func launchApp(
        initialTab: String,
        issueId: String? = nil,
        projectId: String? = nil,
        taskId: String? = nil,
        openCreateSheet: Bool = false,
        useWorkspaceOverride: Bool = true,
        createDefaults: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MULTICA_DEBUG_SKIP_PUSH_PROMPT"] = "1"
        if ProcessInfo.processInfo.environment["MULTICA_UI_DEBUG_NETWORK_LOG"] == "1"
            || FileManager.default.fileExists(atPath: debugNetworkLogFile.path) {
            app.launchEnvironment["MULTICA_DEBUG_NETWORK_LOG"] = "1"
        }
        if let token = debugToken() {
            app.launchEnvironment["MULTICA_DEBUG_TOKEN"] = token
        } else {
            XCTFail("Authenticated UI tests require MULTICA_UI_DEBUG_TOKEN in the test runner environment.")
        }
        if useWorkspaceOverride {
            app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_ID"] = workspaceId
        }
        app.launchEnvironment["MULTICA_DEBUG_INITIAL_TAB"] = initialTab
        if let issueId {
            app.launchEnvironment["MULTICA_DEBUG_INITIAL_ISSUE_ID"] = issueId
        }
        if let projectId {
            app.launchEnvironment["MULTICA_DEBUG_INITIAL_PROJECT_ID"] = projectId
        }
        if let taskId {
            app.launchEnvironment["MULTICA_DEBUG_INITIAL_TASK_ID"] = taskId
        }
        if openCreateSheet {
            app.launchEnvironment["MULTICA_DEBUG_OPEN_CREATE_SHEET"] = "1"
        }
        for (key, value) in createDefaults {
            app.launchEnvironment[key] = value
        }
        addTeardownBlock {
            if app.state != .notRunning {
                app.terminate()
            }
        }
        app.launch()
        return app
    }

    private func debugToken() -> String? {
        if let token = ProcessInfo.processInfo.environment["MULTICA_UI_DEBUG_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }
        if let token = try? String(contentsOf: debugTokenFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !token.isEmpty {
            return token
        }
        return nil
    }

    private func launchLoggedOutApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MULTICA_DEBUG_SKIP_PUSH_PROMPT"] = "1"
        app.launchEnvironment["MULTICA_DEBUG_FORCE_LOGIN_SCREEN"] = "1"
        addTeardownBlock {
            if app.state != .notRunning {
                app.terminate()
            }
        }
        app.launch()
        return app
    }

    private func launchStubbedAuthenticatedApp(initialTab: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MULTICA_DEBUG_SKIP_PUSH_PROMPT"] = "1"
        app.launchEnvironment["MULTICA_DEBUG_AUTH_STUB"] = "1"
        app.launchEnvironment["MULTICA_DEBUG_INITIAL_TAB"] = initialTab
        app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_ID"] = workspaceId
        app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_NAME"] = workspaceName
        app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_SLUG"] = workspaceName
        app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_PREFIX"] = "PAR"
        addTeardownBlock {
            if app.state != .notRunning {
                app.terminate()
            }
        }
        app.launch()
        return app
    }

    private func staticText(in app: XCUIApplication, beginsWith prefix: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func requireMutationTestsEnabled(reason: String) throws {
        guard mutationFlagEnabled(
            environmentKey: "MULTICA_UI_MUTATION_TESTS",
            fileName: "enabled"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_TESTS=1 in the Xcode test runner, or touch /tmp/multica-ui-mutation-tests/enabled, to \(reason).")
        }
    }

    private func mutationFlagEnabled(environmentKey: String, fileName: String) -> Bool {
        if ProcessInfo.processInfo.environment[environmentKey] == "1" {
            return true
        }
        return FileManager.default.fileExists(atPath: mutationFlagDirectory.appendingPathComponent(fileName).path)
    }

    private func mutationValue(environmentKey: String, fileName: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        let url = mutationFlagDirectory.appendingPathComponent(fileName)
        guard let value = try? String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func waitForNonExistence(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return !element.exists
    }

    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isEnabled { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.exists && element.isEnabled
    }

    private func waitForValue(_ element: XCUIElement, timeout: TimeInterval, matches predicate: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, predicate(String(describing: element.value)) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.exists && predicate(String(describing: element.value))
    }

    private func waitForWorkspacePickerValue(_ element: XCUIElement, timeout: TimeInterval) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let value = String(describing: element.value)
            if element.exists && value.contains("Current workspace:") {
                return value
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return String(describing: element.value)
    }

    private func currentWorkspaceName(from pickerValue: String) -> String? {
        guard let range = pickerValue.range(of: "Current workspace: ") else { return nil }
        let suffix = pickerValue[range.upperBound...]
        if let end = suffix.range(of: ". Workspace options loaded:") {
            return String(suffix[..<end.lowerBound])
        }
        return String(suffix)
    }

    private func workspaceOptionCount(from pickerValue: String) -> Int? {
        guard let range = pickerValue.range(of: "Workspace options loaded: ") else { return nil }
        let suffix = pickerValue[range.upperBound...]
        let digits = suffix.prefix(while: { $0.isNumber })
        return Int(digits)
    }

    private func alternateWorkspaceButton(in app: XCUIApplication, excluding currentWorkspace: String) throws -> XCUIElement {
        let ignoredLabels: Set<String> = [
            "Workspace",
            "Settings",
            "Back",
            "Inbox",
            "Issues",
            "Projects",
            "tray",
            "checklist",
            "folder",
            "gearshape",
            currentWorkspace
        ]
        let buttons = app.buttons.allElementsBoundByIndex.filter { button in
            let label = button.label.trimmingCharacters(in: .whitespacesAndNewlines)
            return !label.isEmpty && !ignoredLabels.contains(label) && button.isHittable
        }
        guard let button = buttons.first else {
            throw XCTSkip("No alternate workspace row is hittable.")
        }
        return button
    }

    private func firstInboxNotificationCell(in app: XCUIApplication, timeout: TimeInterval = 20) throws -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let cells = app.cells.allElementsBoundByIndex
            if let notificationCell = cells.first(where: { cell in
                cell.staticTexts["Unread"].exists || cell.staticTexts["Read"].exists
            }) {
                return notificationCell
            }
            let unreadStatus = app.staticTexts["Unread"].firstMatch
            if unreadStatus.exists {
                return unreadStatus
            }
            let readStatus = app.staticTexts["Read"].firstMatch
            if readStatus.exists {
                return readStatus
            }
            if app.staticTexts["No Inbox Items"].exists {
                throw XCTSkip("No Inbox item is available for swipe action coverage.")
            }
            if app.staticTexts[backendTimeoutMessage].exists {
                throw XCTSkip("Inbox endpoint timed out before swipe action coverage could run.")
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTFail("Timed out waiting for an Inbox notification row.")
        return app.cells.element(boundBy: 0)
    }

    private func firstUnreadInboxNotificationCell(in app: XCUIApplication, timeout: TimeInterval = 20) throws -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let unreadCell = app.cells.containing(.staticText, identifier: "Unread").element(boundBy: 0)
            if unreadCell.exists {
                return unreadCell
            }
            let unreadStatus = app.staticTexts["Unread"].firstMatch
            if unreadStatus.exists {
                return unreadStatus
            }
            if app.staticTexts["No Inbox Items"].exists {
                return nil
            }
            let readCell = app.cells.containing(.staticText, identifier: "Read").element(boundBy: 0)
            if readCell.exists {
                return nil
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTFail("Timed out waiting for Inbox rows.")
        return nil
    }

    private func waitForElementOrBackendTimeout(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval,
        reason: String
    ) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return }
            if app.staticTexts[backendTimeoutMessage].exists {
                throw XCTSkip(reason)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }

        XCTAssertTrue(element.exists)
    }

    private func revealTrailingActions(on element: XCUIElement) {
        drag(element, from: CGVector(dx: 0.92, dy: 0.5), to: CGVector(dx: 0.12, dy: 0.5))
    }

    private func revealLeadingActions(on element: XCUIElement) {
        drag(element, from: CGVector(dx: 0.08, dy: 0.5), to: CGVector(dx: 0.88, dy: 0.5))
    }

    private func drag(_ element: XCUIElement, from start: CGVector, to end: CGVector) {
        let startCoordinate = element.coordinate(withNormalizedOffset: start)
        let endCoordinate = element.coordinate(withNormalizedOffset: end)
        startCoordinate.press(forDuration: 0.05, thenDragTo: endCoordinate)
    }

    private func scrollUntilStaticTextExists(_ text: String, app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let element = app.staticTexts[text]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return true }
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return element.exists
    }
}
