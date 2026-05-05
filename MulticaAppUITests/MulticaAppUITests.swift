import XCTest

final class Multi-CasualUITests: XCTestCase {
    private let workspaceId = "7f97e6b9-2db3-489c-a270-4e4c6d354469"
    private let par73IssueId = "9a808431-341f-4ead-8d8c-055e2e00686e"
    private let projectId = "f96f29f2-abbd-4aae-8962-f44a2c68c3aa"
    private let memberUserId = "4b05a80a-fa79-45e6-8568-f3bf08e7057b"
    private let transcriptTaskId = "9eab0d97-de00-4f90-82a6-d70cbb5161a2"
    private let mutationFlagDirectory = URL(fileURLWithPath: "/tmp/multica-ui-mutation-tests", isDirectory: true)

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testSettingsWorkspaceScreenRenders() {
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Workspace"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Log Out"].exists)
        app.buttons["Log Out"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
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

    func testInboxSwipeShowsArchiveActionWithoutSubmitting() {
        let app = launchApp(initialTab: "inbox")

        XCTAssertTrue(app.staticTexts["Inbox"].waitForExistence(timeout: 20))
        let firstNotification = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstNotification.waitForExistence(timeout: 20))
        let rowButton = firstNotification.buttons.element(boundBy: 0)
        XCTAssertTrue(rowButton.waitForExistence(timeout: 5))
        rowButton.swipeLeft()
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["Archive this notification?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(firstNotification.waitForExistence(timeout: 5))
    }

    func testIssueDetailRendersMetadataCommentsAndInput() {
        let app = launchApp(initialTab: "issues", issueId: par73IssueId)

        XCTAssertTrue(app.staticTexts["PAR-73"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Agent Activity"].waitForExistence(timeout: 20))
        let commentField = app.descendants(matching: .any)["IssueDetailCommentInput"].firstMatch
        XCTAssertTrue(commentField.waitForExistence(timeout: 10))
        commentField.tap()
        commentField.typeText("UI draft")
        XCTAssertTrue(commentField.value.debugDescription.contains("UI draft"))
        XCTAssertTrue(app.buttons["IssueDetailCommentSendButton"].isEnabled)
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
        let unreadCell = app.cells.containing(.staticText, identifier: "Unread").element(boundBy: 0)
        guard unreadCell.waitForExistence(timeout: 20) else {
            throw XCTSkip("No unread Inbox item is available to mark read.")
        }

        let rowButton = unreadCell.buttons.element(boundBy: 0)
        XCTAssertTrue(rowButton.waitForExistence(timeout: 5))
        rowButton.swipeRight()
        XCTAssertTrue(app.buttons["Read"].waitForExistence(timeout: 5))
        app.buttons["Read"].tap()
        XCTAssertTrue(unreadCell.staticTexts["Read"].waitForExistence(timeout: 10))

        rowButton.swipeLeft()
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
        createDefaults: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MULTICA_DEBUG_SKIP_PUSH_PROMPT"] = "1"
        app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_ID"] = workspaceId
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
