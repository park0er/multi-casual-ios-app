import XCTest

final class Multi-CasualUITests: XCTestCase {
    private let backendTimeoutMessage = "The server took too long to respond. Please try again."
    private let mutationFlagDirectory = URL(fileURLWithPath: "/tmp/multica-ui-mutation-tests", isDirectory: true)
    private let debugTokenFile = URL(fileURLWithPath: "/tmp/multica-ui-debug-token")
    private let debugNetworkLogFile = URL(fileURLWithPath: "/tmp/multica-ui-network-log")

    private var workspaceId: String {
        uiConfigValue(
            environmentKey: "MULTICA_UI_WORKSPACE_ID",
            fileName: "workspace-id",
            defaultValue: "7f97e6b9-2db3-489c-a270-4e4c6d354469"
        )
    }

    private var workspaceName: String {
        uiConfigValue(
            environmentKey: "MULTICA_UI_WORKSPACE_NAME",
            fileName: "workspace-name",
            defaultValue: "park0er"
        )
    }

    private var par73IssueId: String {
        uiConfigValue(
            environmentKey: "MULTICA_UI_PAR73_ISSUE_ID",
            fileName: "par73-issue-id",
            defaultValue: "9a808431-341f-4ead-8d8c-055e2e00686e"
        )
    }

    private var projectId: String {
        uiConfigValue(
            environmentKey: "MULTICA_UI_PROJECT_ID",
            fileName: "project-id",
            defaultValue: "f96f29f2-abbd-4aae-8962-f44a2c68c3aa"
        )
    }

    private var memberUserId: String {
        uiConfigValue(
            environmentKey: "MULTICA_UI_MEMBER_USER_ID",
            fileName: "member-user-id",
            defaultValue: "4b05a80a-fa79-45e6-8568-f3bf08e7057b"
        )
    }

    private var memberDisplayName: String {
        uiConfigValue(
            environmentKey: "MULTICA_UI_MEMBER_DISPLAY_NAME",
            fileName: "member-display-name",
            defaultValue: "ZhaoXishengGmail"
        )
    }

    private var agentDisplayName: String {
        uiConfigValue(
            environmentKey: "MULTICA_UI_AGENT_DISPLAY_NAME",
            fileName: "agent-display-name",
            defaultValue: "RollieCC"
        )
    }

    private var transcriptTaskId: String {
        uiConfigValue(
            environmentKey: "MULTICA_UI_TRANSCRIPT_TASK_ID",
            fileName: "transcript-task-id",
            defaultValue: "9eab0d97-de00-4f90-82a6-d70cbb5161a2"
        )
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testUITestLaunchConfigurationUsesWorkspaceEnvironmentOverrides() throws {
        let expectedWorkspaceId = try requiredMutationFileValue("workspace-id")
        let expectedWorkspaceName = try requiredMutationFileValue("workspace-name")
        let expectedAgentDisplayName = try requiredMutationFileValue("agent-display-name")

        XCTAssertEqual(workspaceId, expectedWorkspaceId)
        XCTAssertEqual(workspaceName, expectedWorkspaceName)
        XCTAssertEqual(agentDisplayName, expectedAgentDisplayName)
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
        XCTAssertTrue(scrollUntilButtonExists("Log Out", app: app, timeout: 10))
        app.buttons["Log Out"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
    }

    func testSettingsCanLaunchInChineseLanguage() {
        let app = launchStubbedAuthenticatedApp(initialTab: "settings", language: "zh-Hans")

        XCTAssertTrue(app.staticTexts["设置"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["工作区"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["SettingsLanguagePicker"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["收件箱"].waitForExistence(timeout: 10))
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
        returnToSettingsFromWorkspacePicker(in: app)

        XCTAssertTrue(waitForValue(workspacePicker, timeout: 10) { value in
            value.contains("Current workspace: \(alternateName)")
        })

        workspacePicker.tap()
        XCTAssertTrue(app.navigationBars["Workspace"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[initialWorkspace].waitForExistence(timeout: 10))
        app.buttons[initialWorkspace].tap()
        returnToSettingsFromWorkspacePicker(in: app)
        XCTAssertTrue(waitForValue(workspacePicker, timeout: 10) { value in
            value.contains("Current workspace: \(initialWorkspace)")
        })
    }

    func testWorkspaceSwitchRefreshesAlreadyLoadedResourceTabsWhenAvailable() throws {
        let app = launchApp(initialTab: "issues", useWorkspaceOverride: false)

        try waitForWorkspaceResourceState(
            title: "Issues",
            emptyTitle: "No Issues",
            timeoutReason: "Issues endpoint timed out before workspace refresh coverage could run.",
            in: app
        )
        addScreenshot(named: "issues-before-workspace-switch", from: app)

        tapTab("Projects", in: app)
        try waitForWorkspaceResourceState(
            title: "Projects",
            emptyTitle: "No Projects",
            timeoutReason: "Projects endpoint timed out before workspace refresh coverage could run.",
            in: app
        )
        addScreenshot(named: "projects-before-workspace-switch", from: app)

        tapTab("Settings", in: app)
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
        returnToSettingsFromWorkspacePicker(in: app)
        XCTAssertTrue(waitForValue(workspacePicker, timeout: 10) { value in
            value.contains("Current workspace: \(alternateName)")
        })

        tapTab("Issues", in: app)
        try waitForWorkspaceResourceState(
            title: "Issues",
            emptyTitle: "No Issues",
            timeoutReason: "Issues endpoint timed out after switching workspace.",
            in: app
        )
        addScreenshot(named: "issues-after-switch-to-\(alternateName)", from: app)

        tapTab("Projects", in: app)
        try waitForWorkspaceResourceState(
            title: "Projects",
            emptyTitle: "No Projects",
            timeoutReason: "Projects endpoint timed out after switching workspace.",
            in: app
        )
        addScreenshot(named: "projects-after-switch-to-\(alternateName)", from: app)

        app.terminate()
        let relaunchedApp = launchApp(initialTab: "settings", useWorkspaceOverride: false)
        XCTAssertTrue(relaunchedApp.staticTexts["Settings"].waitForExistence(timeout: 20))
        let restoredPicker = relaunchedApp.buttons["SettingsWorkspacePicker"]
        XCTAssertTrue(restoredPicker.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(restoredPicker, timeout: 10) { value in
            value.contains("Current workspace: \(alternateName)")
        })

        restoredPicker.tap()
        XCTAssertTrue(relaunchedApp.navigationBars["Workspace"].waitForExistence(timeout: 10))
        XCTAssertTrue(relaunchedApp.buttons[initialWorkspace].waitForExistence(timeout: 10))
        relaunchedApp.buttons[initialWorkspace].tap()
        returnToSettingsFromWorkspacePicker(in: relaunchedApp)
        XCTAssertTrue(waitForValue(restoredPicker, timeout: 10) { value in
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

    func testSettingsAgentCreateSheetShowsEnvironmentAndArgsEditors() {
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Agents"].waitForExistence(timeout: 10))
        app.buttons["Agents"].tap()

        XCTAssertTrue(app.staticTexts["Agents"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["AgentsNewButton"].waitForExistence(timeout: 10))
        app.buttons["AgentsNewButton"].tap()

        XCTAssertTrue(app.textFields["AgentNameField"].waitForExistence(timeout: 10))
        XCTAssertTrue(scrollUntilElementExists(app.textViews["AgentCustomEnvEditor"], app: app, timeout: 10))
        XCTAssertTrue(scrollUntilElementExists(app.textViews["AgentCustomArgsEditor"], app: app, timeout: 10))
        app.buttons["Cancel"].tap()
    }

    func testSettingsAgentDetailRendersWhenAgentExists() throws {
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Agents"].waitForExistence(timeout: 10))
        app.buttons["Agents"].tap()

        XCTAssertTrue(app.staticTexts["Agents"].waitForExistence(timeout: 20))
        let firstAgent = app.cells.firstMatch
        guard firstAgent.waitForExistence(timeout: 20) else {
            throw XCTSkip("No agent row is available for detail smoke coverage.")
        }
        firstAgent.tap()

        XCTAssertTrue(app.staticTexts["Agent Detail"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Activity"].waitForExistence(timeout: 10))
    }

    func testSettingsAgentCancelTasksRequiresConfirmation() throws {
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Agents"].waitForExistence(timeout: 10))
        app.buttons["Agents"].tap()

        XCTAssertTrue(app.staticTexts["Agents"].waitForExistence(timeout: 20))
        let firstAgent = app.cells.firstMatch
        guard firstAgent.waitForExistence(timeout: 20) else {
            throw XCTSkip("No agent row is available to test destructive confirmation.")
        }

        revealLeadingActions(on: firstAgent)
        XCTAssertTrue(app.buttons["Cancel Tasks"].waitForExistence(timeout: 5))
        app.buttons["Cancel Tasks"].tap()
        XCTAssertTrue(staticText(in: app, contains: "Cancel active tasks for").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Keep Running"].waitForExistence(timeout: 5))
        app.buttons["Keep Running"].tap()
        XCTAssertTrue(app.staticTexts["Agents"].waitForExistence(timeout: 5))
    }

    func testSettingsAgentCreateEditArchiveRestoreWhenMutationTestsEnabled() throws {
        try requireMutationTestsEnabled(reason: "create, edit, archive, and restore a disposable agent")
        guard mutationFlagEnabled(
            environmentKey: "MULTICA_UI_MUTATION_AGENT_MANAGEMENT",
            fileName: "agent-management.enabled"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_AGENT_MANAGEMENT=1 or touch /tmp/multica-ui-mutation-tests/agent-management.enabled to mutate a disposable agent.")
        }

        let baseName = mutationValue(
            environmentKey: "MULTICA_UI_MUTATION_AGENT_NAME",
            fileName: "agent-name"
        ) ?? "iOS UI agent \(Int(Date().timeIntervalSince1970))"
        let updatedName = "\(baseName) updated"
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Agents"].waitForExistence(timeout: 10))
        app.buttons["Agents"].tap()

        XCTAssertTrue(app.staticTexts["Agents"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["AgentsNewButton"].waitForExistence(timeout: 10))
        app.buttons["AgentsNewButton"].tap()

        let nameField = app.textFields["AgentNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText(baseName)

        let saveButton = app.buttons["AgentSaveButton"]
        guard waitForEnabled(saveButton, timeout: 30) else {
            throw XCTSkip("Agent form is not saveable, likely because no runtime is available.")
        }
        saveButton.tap()

        XCTAssertTrue(waitForNonExistence(app.navigationBars["New Agent"], timeout: 30))
        XCTAssertTrue(scrollUntilStaticTextExists(baseName, app: app, timeout: 45))

        let createdCell = app.cells.containing(.staticText, identifier: baseName).element(boundBy: 0)
        XCTAssertTrue(createdCell.waitForExistence(timeout: 10))
        createdCell.tap()

        XCTAssertTrue(app.staticTexts["Agent Detail"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["AgentDetailEditButton"].waitForExistence(timeout: 10))
        app.buttons["AgentDetailEditButton"].tap()

        let editNameField = app.textFields["AgentNameField"]
        XCTAssertTrue(editNameField.waitForExistence(timeout: 10))
        replaceText(in: editNameField, with: updatedName)
        XCTAssertTrue(waitForEnabled(saveButton, timeout: 10))
        saveButton.tap()

        XCTAssertTrue(waitForNonExistence(app.navigationBars["Edit Agent"], timeout: 30))
        XCTAssertTrue(app.staticTexts[updatedName].waitForExistence(timeout: 30))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.staticTexts["Agents"].waitForExistence(timeout: 10))
        let updatedCell = app.cells.containing(.staticText, identifier: updatedName).element(boundBy: 0)
        XCTAssertTrue(updatedCell.waitForExistence(timeout: 10))
        revealTrailingActions(on: updatedCell)
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()
        XCTAssertTrue(staticText(in: app, contains: "Archive").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()

        XCTAssertTrue(app.staticTexts["Archived"].waitForExistence(timeout: 30))
        revealTrailingActions(on: updatedCell)
        XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 5))
        app.buttons["Restore"].tap()
        XCTAssertTrue(waitForNonExistence(app.buttons["Restore"], timeout: 30))

        revealTrailingActions(on: updatedCell)
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.buttons["Archive"].waitForExistence(timeout: 5))
        app.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["Archived"].waitForExistence(timeout: 30))
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

    func testSettingsRuntimeDetailRendersWhenRuntimeExists() throws {
        let app = launchApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Runtimes"].waitForExistence(timeout: 10))
        app.buttons["Runtimes"].tap()

        XCTAssertTrue(app.staticTexts["Runtimes"].waitForExistence(timeout: 20))
        let firstRuntime = app.buttons["RuntimeRow"].firstMatch
        guard firstRuntime.waitForExistence(timeout: 20) else {
            throw XCTSkip("No runtime row is available for detail smoke coverage.")
        }
        firstRuntime.tap()

        XCTAssertTrue(app.collectionViews["RuntimeDetailList"].waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Serving Agents"].waitForExistence(timeout: 10))
    }

    func testSettingsSkillsScreenRenders() {
        let app = launchStubbedAuthenticatedApp(initialTab: "settings")

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 20))
        tapSettingsRow("Skills", in: app)

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
        titleField.tap()
        titleField.typeText("UI smoke draft")

        XCTAssertTrue(scrollUntilStaticTextExists("Assignee", app: app, timeout: 10))
        XCTAssertTrue(scrollUntilStaticTextExists("Project", app: app, timeout: 10))
        XCTAssertTrue(scrollUntilStaticTextExists("Due Date", app: app, timeout: 10))

        let addAttachmentButton = app.buttons["IssueCreateAddAttachmentButton"]
        XCTAssertTrue(scrollUntilElementExists(addAttachmentButton, app: app, timeout: 10))

        XCTAssertTrue(app.buttons["Create"].isEnabled)
    }

    func testCreateIssueAssigneePickerShowsMembersAndAgents() {
        let app = launchApp(initialTab: "issues", openCreateSheet: true)

        XCTAssertTrue(app.navigationBars["New Issue"].waitForExistence(timeout: 20))
        let assigneePicker = app.buttons["IssueCreateAssigneePicker"]
        XCTAssertTrue(scrollUntilElementExists(assigneePicker, app: app, timeout: 20))
        XCTAssertTrue(waitForValue(assigneePicker, timeout: 30) { value in
            value.contains("Assignee options loaded:") && !value.contains("Assignee options loaded: 0")
        })
        assigneePicker.tap()

        XCTAssertTrue(app.buttons["Unassigned"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[memberDisplayName].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[agentDisplayName].waitForExistence(timeout: 10))
    }

    func testCreateIssuePickersAreTappableFromIssuesTab() {
        let app = launchApp(initialTab: "issues", openCreateSheet: true)

        XCTAssertTrue(app.navigationBars["New Issue"].waitForExistence(timeout: 20))

        let statusPicker = app.buttons["IssueCreateStatusPicker"]
        XCTAssertTrue(scrollUntilElementExists(statusPicker, app: app, timeout: 10))
        statusPicker.tap()
        XCTAssertTrue(app.buttons["Todo"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let priorityPicker = app.buttons["IssueCreatePriorityPicker"]
        XCTAssertTrue(scrollUntilElementExists(priorityPicker, app: app, timeout: 10))
        priorityPicker.tap()
        XCTAssertTrue(app.buttons["No Priority"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let projectPicker = app.buttons["IssueCreateProjectPicker"]
        XCTAssertTrue(scrollUntilElementExists(projectPicker, app: app, timeout: 10))
        projectPicker.tap()
        XCTAssertTrue(app.buttons["No Project"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(app.buttons["Number"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Priority"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Updated"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Ascending"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Descending"].waitForExistence(timeout: 5))
        app.buttons["Descending"].tap()

        let statusHeader = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "IssueStatusSectionHeader-")).firstMatch
        XCTAssertTrue(statusHeader.waitForExistence(timeout: 10))
        statusHeader.tap()
        XCTAssertTrue(waitForValue(statusHeader, timeout: 5) { $0.contains("Collapsed") })
        statusHeader.tap()
        XCTAssertTrue(waitForValue(statusHeader, timeout: 5) { $0.contains("Expanded") })

        let boardToggle = app.buttons["IssueViewModeToggle"]
        XCTAssertTrue(boardToggle.waitForExistence(timeout: 10))
        boardToggle.tap()
        XCTAssertTrue(app.staticTexts["Backlog"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Todo"].waitForExistence(timeout: 10))
    }

    func testMyIssuesTabRendersScopesWithoutSubmitting() throws {
        let app = launchApp(initialTab: "my-issues")

        try waitForWorkspaceResourceState(
            title: "My Issues",
            emptyTitle: "No Assigned Issues",
            timeoutReason: "My Issues endpoint timed out before scope coverage could run.",
            in: app
        )

        let scopePicker = app.segmentedControls["MyIssuesScopePicker"]
        XCTAssertTrue(scopePicker.waitForExistence(timeout: 10))
        XCTAssertTrue(scopePicker.buttons["Assigned"].exists)
        XCTAssertTrue(scopePicker.buttons["Created"].exists)
        XCTAssertTrue(scopePicker.buttons["My Agents"].exists)

        scopePicker.buttons["Created"].tap()
        XCTAssertTrue(app.staticTexts["My Issues"].waitForExistence(timeout: 10))
        scopePicker.buttons["My Agents"].tap()
        XCTAssertTrue(app.staticTexts["My Issues"].waitForExistence(timeout: 10))
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

    func testDemoInteractiveWalkthroughForVideo() throws {
        let language = uiConfigValue(
            environmentKey: "MULTICA_UI_DEMO_LANGUAGE",
            fileName: "demo-language",
            defaultValue: "en"
        )
        let localized = DemoLabels(language: language)
        let app = launchApp(initialTab: "inbox", language: language)

        XCTAssertTrue(app.staticTexts[localized.inbox].waitForExistence(timeout: 30))
        pauseForDemo(2)

        tapTab(localized.issues, in: app)
        XCTAssertTrue(app.staticTexts[localized.issues].waitForExistence(timeout: 30))
        pauseForDemo(2)

        if app.buttons["IssueSortMenu"].waitForExistence(timeout: 10) {
            app.buttons["IssueSortMenu"].tap()
            pauseForDemo(1)
            if app.buttons[localized.descending].exists {
                app.buttons[localized.descending].tap()
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.52, dy: 0.35)).tap()
            }
        }
        pauseForDemo(2)

        if app.buttons["IssueViewModeToggle"].waitForExistence(timeout: 10) {
            app.buttons["IssueViewModeToggle"].tap()
            pauseForDemo(2)
            app.buttons["IssueViewModeToggle"].tap()
        }
        pauseForDemo(1)

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.095)).tap()
        if app.navigationBars[localized.newIssue].waitForExistence(timeout: 10) {
            pauseForDemo(2)
            app.buttons[localized.cancel].tap()
            pauseForDemo(1)
        }

        let firstIssue = app.cells.element(boundBy: 0)
        if firstIssue.waitForExistence(timeout: 20) {
            firstIssue.tap()
            pauseForDemo(4)
            if app.buttons["IssueDetailEditButton"].waitForExistence(timeout: 8) {
                app.buttons["IssueDetailEditButton"].tap()
                pauseForDemo(2)
                if app.buttons[localized.cancel].exists {
                    app.buttons[localized.cancel].tap()
                }
                pauseForDemo(1)
            }
        }

        tapTab(localized.projects, in: app)
        XCTAssertTrue(app.staticTexts[localized.projects].waitForExistence(timeout: 30))
        pauseForDemo(2)

        let firstProject = app.cells.element(boundBy: 0)
        if firstProject.waitForExistence(timeout: 20) {
            firstProject.tap()
            pauseForDemo(3)
        }

        tapTab(localized.settings, in: app)
        XCTAssertTrue(app.staticTexts[localized.settings].waitForExistence(timeout: 30))
        pauseForDemo(2)

        if app.buttons[localized.agents].waitForExistence(timeout: 10) {
            app.buttons[localized.agents].tap()
            pauseForDemo(3)
        }
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
        XCTAssertTrue(scrollUntilElementExists(app.staticTexts["Latest Progress"], app: app, timeout: 20))
        XCTAssertTrue(scrollUntilElementExists(app.staticTexts["Comments"], app: app, timeout: 10))
        XCTAssertTrue(scrollUntilElementExists(app.buttons["IssueDetailAgentWorkDetails"], app: app, timeout: 20))
        XCTAssertTrue(scrollUntilElementExists(app.buttons["IssueDetailAddCommentAttachmentButton"], app: app, timeout: 10))
        let commentField = app.descendants(matching: .any)["IssueDetailCommentInput"].firstMatch
        XCTAssertTrue(scrollUntilElementExists(commentField, app: app, timeout: 10))
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
        let assigneePicker = app.buttons["IssueEditAssigneePicker"]
        XCTAssertTrue(assigneePicker.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(assigneePicker, timeout: 30) { value in
            value.contains("Assignee options loaded:") && !value.contains("Assignee options loaded: 0")
        })
        assigneePicker.tap()
        XCTAssertTrue(app.buttons["Unassigned"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[memberDisplayName].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[agentDisplayName].waitForExistence(timeout: 10))
        app.buttons["Unassigned"].tap()
        XCTAssertTrue(app.buttons["Cancel"].exists)
        app.buttons["Cancel"].tap()
    }

    func testIssueDetailReassignsIssueWhenMutationTestsEnabled() throws {
        try requireMutationTestsEnabled(reason: "reassign a disposable issue to a member and an agent")
        guard mutationFlagEnabled(
            environmentKey: "MULTICA_UI_MUTATION_ISSUE_REASSIGN",
            fileName: "issue-reassign.enabled"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_ISSUE_REASSIGN=1 or touch /tmp/multica-ui-mutation-tests/issue-reassign.enabled to reassign a disposable issue.")
        }
        guard let issueId = mutationValue(
            environmentKey: "MULTICA_UI_MUTATION_ISSUE_ID",
            fileName: "issue-id"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_ISSUE_ID or write a disposable issue id to /tmp/multica-ui-mutation-tests/issue-id before reassigning it.")
        }

        let app = launchApp(initialTab: "issues", issueId: issueId)

        try waitForElementOrBackendTimeout(
            app.buttons["IssueDetailEditButton"],
            in: app,
            timeout: 20,
            reason: "Issue detail endpoint timed out before reassign coverage could run."
        )

        try reassignIssue(in: app, to: memberDisplayName)
        XCTAssertTrue(app.staticTexts[memberDisplayName].waitForExistence(timeout: 30))

        try reassignIssue(in: app, to: agentDisplayName)
        XCTAssertTrue(app.staticTexts[agentDisplayName].waitForExistence(timeout: 30))

        try reassignIssue(in: app, to: "Unassigned")
        XCTAssertTrue(app.staticTexts["Unassigned"].waitForExistence(timeout: 30))
    }

    func testIssueDetailLongCommentsScrollKeepsComposerReachable() {
        let app = launchApp(initialTab: "issues", issueId: par73IssueId)

        XCTAssertTrue(app.staticTexts["Comments"].waitForExistence(timeout: 20))
        for _ in 0..<3 {
            app.swipeUp()
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
        guard let issueId = mutationValue(
            environmentKey: "MULTICA_UI_MUTATION_ISSUE_ID",
            fileName: "issue-id"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_ISSUE_ID or write a disposable issue id to /tmp/multica-ui-mutation-tests/issue-id before updating status.")
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

        app.terminate()
        let detailApp = launchApp(initialTab: "issues", issueId: issueId)
        XCTAssertTrue(detailApp.staticTexts["Done"].waitForExistence(timeout: 20))
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

        XCTAssertTrue(waitForValue(commentField, timeout: 30) { value in
            !value.contains(comment)
        })
    }

    func testAgentTranscriptRendersTimeline() {
        let app = launchApp(initialTab: "issues", taskId: transcriptTaskId)

        XCTAssertTrue(app.staticTexts["Agent Transcript"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["Tool Use"].waitForExistence(timeout: 20))
    }

    func testIssueDetailLiveAgentTimelineUpdatesWhenEnabled() throws {
        try requireMutationTestsEnabled(reason: "observe a real running task WebSocket update")
        guard mutationFlagEnabled(
            environmentKey: "MULTICA_UI_MUTATION_RUNNING_TASK",
            fileName: "running-task.enabled"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_RUNNING_TASK=1 or touch /tmp/multica-ui-mutation-tests/running-task.enabled to observe a real running task.")
        }
        guard let issueId = mutationValue(
            environmentKey: "MULTICA_UI_MUTATION_RUNNING_ISSUE_ID",
            fileName: "running-issue-id"
        ) else {
            throw XCTSkip("Set MULTICA_UI_MUTATION_RUNNING_ISSUE_ID or write a running issue id to /tmp/multica-ui-mutation-tests/running-issue-id.")
        }

        let app = launchApp(initialTab: "issues", issueId: issueId)

        XCTAssertTrue(app.staticTexts["Agent"].waitForExistence(timeout: 30))
        let initialCount = try waitForAgentEventCount(in: app, timeout: 30)
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            if let count = agentEventCount(in: app), count > initialCount {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }

        XCTFail("Timed out waiting for live agent timeline event count to increase from \(initialCount).")
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

    func testChatCreateSheetOpensWithoutSubmitting() {
        let app = launchStubbedAuthenticatedApp(initialTab: "inbox")

        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 20))
        let chatButton = app.buttons["InboxChatButton"]
        XCTAssertTrue(chatButton.waitForExistence(timeout: 10))
        chatButton.tap()
        XCTAssertTrue(app.navigationBars["Chat"].waitForExistence(timeout: 10))
        let newChatButton = app.buttons["ChatNewButton"]
        XCTAssertTrue(newChatButton.waitForExistence(timeout: 10))
        newChatButton.tap()

        XCTAssertTrue(app.navigationBars["New Chat"].waitForExistence(timeout: 10))
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
        createDefaults: [String: String] = [:],
        language: String = "en"
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
        app.launchEnvironment["MULTICA_DEBUG_APP_LANGUAGE"] = language
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

    private func launchStubbedAuthenticatedApp(initialTab: String, language: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MULTICA_DEBUG_SKIP_PUSH_PROMPT"] = "1"
        app.launchEnvironment["MULTICA_DEBUG_AUTH_STUB"] = "1"
        app.launchEnvironment["MULTICA_DEBUG_INITIAL_TAB"] = initialTab
        app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_ID"] = workspaceId
        app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_NAME"] = workspaceName
        app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_SLUG"] = workspaceName
        app.launchEnvironment["MULTICA_DEBUG_WORKSPACE_PREFIX"] = "PAR"
        app.launchEnvironment["MULTICA_DEBUG_APP_LANGUAGE"] = language ?? "en"
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

    private func staticText(in app: XCUIApplication, contains text: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func agentEventCount(in app: XCUIApplication) -> Int? {
        for element in app.staticTexts.allElementsBoundByIndex {
            let label = element.label
            guard label.hasSuffix(" events") else { continue }
            let digits = label.prefix(while: { $0.isNumber })
            if let count = Int(digits) {
                return count
            }
        }
        return nil
    }

    private func waitForAgentEventCount(in app: XCUIApplication, timeout: TimeInterval) throws -> Int {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let count = agentEventCount(in: app) {
                return count
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }

        throw XCTSkip("No live agent timeline event count is visible for the supplied running issue.")
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

    private func uiConfigValue(environmentKey: String, fileName: String, defaultValue: String) -> String {
        if let value = ProcessInfo.processInfo.environment[environmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        let url = mutationFlagDirectory.appendingPathComponent(fileName)
        if let value = try? String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }

        return defaultValue
    }

    private func requiredMutationFileValue(_ fileName: String) throws -> String {
        let url = mutationFlagDirectory.appendingPathComponent(fileName)
        guard let value = try? String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            throw XCTSkip("Write \(url.path) to verify UI mutation tests target a disposable workspace.")
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

    private func replaceText(in element: XCUIElement, with text: String) {
        let endCoordinate = element.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        endCoordinate.tap()
        element.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 120))
        element.typeText(text)
    }

    private func reassignIssue(in app: XCUIApplication, to assigneeButtonLabel: String) throws {
        XCTAssertTrue(app.buttons["IssueDetailEditButton"].waitForExistence(timeout: 10))
        app.buttons["IssueDetailEditButton"].tap()
        XCTAssertTrue(app.navigationBars["Edit Issue"].waitForExistence(timeout: 10))
        let assigneePicker = app.buttons["IssueEditAssigneePicker"]
        XCTAssertTrue(assigneePicker.waitForExistence(timeout: 10))
        XCTAssertTrue(waitForValue(assigneePicker, timeout: 30) { value in
            value.contains("Assignee options loaded:") && !value.contains("Assignee options loaded: 0")
        })
        assigneePicker.tap()
        guard app.buttons[assigneeButtonLabel].waitForExistence(timeout: 10) else {
            throw XCTSkip("Assignee option \(assigneeButtonLabel) is not available.")
        }
        app.buttons[assigneeButtonLabel].tap()

        let saveButton = app.buttons["IssueEditSaveButton"]
        XCTAssertTrue(waitForEnabled(saveButton, timeout: 10))
        saveButton.tap()
        XCTAssertTrue(waitForNonExistence(app.navigationBars["Edit Issue"], timeout: 30))
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
            "BackButton",
            "Inbox",
            "Issues",
            "My Issues",
            "Projects",
            "More",
            "tray",
            "checklist",
            "person.crop.circle.badge.checkmark",
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

    private func tapTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
    }

    private func pauseForDemo(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private struct DemoLabels {
        let inbox: String
        let issues: String
        let projects: String
        let settings: String
        let agents: String
        let newIssue: String
        let cancel: String
        let descending: String

        init(language: String) {
            if language == "zh-Hans" {
                inbox = "收件箱"
                issues = "Issues"
                projects = "项目"
                settings = "设置"
                agents = "Agents"
                newIssue = "新建 Issue"
                cancel = "取消"
                descending = "降序"
            } else {
                inbox = "Inbox"
                issues = "Issues"
                projects = "Projects"
                settings = "Settings"
                agents = "Agents"
                newIssue = "New Issue"
                cancel = "Cancel"
                descending = "Descending"
            }
        }
    }

    private func waitForWorkspaceResourceState(
        title: String,
        emptyTitle: String,
        timeoutReason: String,
        in app: XCUIApplication,
        timeout: TimeInterval = 30
    ) throws {
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: timeout))
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.staticTexts[emptyTitle].exists {
                return
            }
            if app.staticTexts[backendTimeoutMessage].exists {
                throw XCTSkip(timeoutReason)
            }
            if app.cells.count > 0 {
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTFail("Timed out waiting for \(title) to load rows, empty state, or a retryable timeout.")
    }

    private func addScreenshot(named name: String, from app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    private func scrollUntilButtonExists(_ label: String, app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let element = app.buttons[label]
        return scrollUntilElementExists(element, app: app, timeout: timeout)
    }

    private func scrollUntilElementExists(_ element: XCUIElement, app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return true }
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return element.exists
    }

    private func tapSettingsRow(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label]
        XCTAssertTrue(scrollUntilButtonExists(label, app: app, timeout: 10))
        button.tap()
    }

    private func returnToSettingsFromWorkspacePicker(in app: XCUIApplication) {
        if app.staticTexts["Settings"].exists { return }
        let backButton = app.buttons["BackButton"]
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
        } else {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10))
    }
}
