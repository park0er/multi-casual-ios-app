import Foundation

// MARK: - Auth

public struct User: Codable, Identifiable, Sendable {
    public let id: String
    public let email: String
    public let name: String
    public let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case avatarUrl = "avatar_url"
    }

    public init(id: String, email: String, name: String, avatarUrl: String?) {
        self.id = id
        self.email = email
        self.name = name
        self.avatarUrl = avatarUrl
    }
}

public struct Workspace: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let slug: String
    public let issuePrefix: String

    enum CodingKeys: String, CodingKey {
        case id, name, slug
        case issuePrefix = "issue_prefix"
    }

    public init(id: String, name: String, slug: String, issuePrefix: String) {
        self.id = id
        self.name = name
        self.slug = slug
        self.issuePrefix = issuePrefix
    }
}

public struct WorkspaceMember: Codable, Identifiable, Sendable {
    public let id: String
    public let workspaceId: String
    public let userId: String
    public let role: String
    public let name: String
    public let email: String
    public let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, role, name, email
        case workspaceId = "workspace_id"
        case userId = "user_id"
        case avatarUrl = "avatar_url"
    }
}

public struct Agent: Codable, Identifiable, Sendable {
    public let id: String
    public let workspaceId: String
    public let runtimeId: String
    public let name: String
    public let description: String
    public let instructions: String
    public let status: String
    public let avatarUrl: String?
    public let runtimeMode: String
    public let visibility: String
    public let maxConcurrentTasks: Int
    public let model: String?
    public let archivedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, instructions, status, visibility, model
        case workspaceId = "workspace_id"
        case runtimeId = "runtime_id"
        case avatarUrl = "avatar_url"
        case runtimeMode = "runtime_mode"
        case maxConcurrentTasks = "max_concurrent_tasks"
        case archivedAt = "archived_at"
    }

    public init(
        id: String,
        workspaceId: String,
        runtimeId: String,
        name: String,
        description: String,
        instructions: String,
        status: String,
        avatarUrl: String?,
        runtimeMode: String,
        visibility: String,
        maxConcurrentTasks: Int,
        model: String?,
        archivedAt: String?
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.runtimeId = runtimeId
        self.name = name
        self.description = description
        self.instructions = instructions
        self.status = status
        self.avatarUrl = avatarUrl
        self.runtimeMode = runtimeMode
        self.visibility = visibility
        self.maxConcurrentTasks = maxConcurrentTasks
        self.model = model
        self.archivedAt = archivedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        workspaceId = try c.decode(String.self, forKey: .workspaceId)
        runtimeId = try c.decodeIfPresent(String.self, forKey: .runtimeId) ?? ""
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        instructions = try c.decodeIfPresent(String.self, forKey: .instructions) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        runtimeMode = try c.decodeIfPresent(String.self, forKey: .runtimeMode) ?? "cloud"
        visibility = try c.decodeIfPresent(String.self, forKey: .visibility) ?? "workspace"
        maxConcurrentTasks = try c.decodeIfPresent(Int.self, forKey: .maxConcurrentTasks) ?? 1
        model = try c.decodeIfPresent(String.self, forKey: .model)
        archivedAt = try c.decodeIfPresent(String.self, forKey: .archivedAt)
    }
}

public struct AgentRuntime: Codable, Identifiable, Sendable {
    public let id: String
    public let workspaceId: String
    public let name: String
    public let runtimeMode: String
    public let provider: String
    public let status: String

    enum CodingKeys: String, CodingKey {
        case id, name, provider, status
        case workspaceId = "workspace_id"
        case runtimeMode = "runtime_mode"
    }
}

public struct SkillFile: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let path: String
    public let content: String?

    enum CodingKeys: String, CodingKey {
        case id, path, content
    }

    public init(id: String, path: String, content: String?) {
        self.id = id
        self.path = path
        self.content = content
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decodeIfPresent(String.self, forKey: .path) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? path
    }
}

public struct Skill: Codable, Identifiable, Sendable {
    public let id: String
    public let workspaceId: String
    public let name: String
    public let description: String
    public let content: String
    public let config: [String: JSONValue]
    public let files: [SkillFile]
    public let createdBy: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, description, content, config, files
        case workspaceId = "workspace_id"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String,
        workspaceId: String,
        name: String,
        description: String,
        content: String,
        config: [String: JSONValue] = [:],
        files: [SkillFile] = [],
        createdBy: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.name = name
        self.description = description
        self.content = content
        self.config = config
        self.files = files
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        workspaceId = try container.decodeIfPresent(String.self, forKey: .workspaceId) ?? ""
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        config = try container.decodeIfPresent([String: JSONValue].self, forKey: .config) ?? [:]
        files = try container.decodeIfPresent([SkillFile].self, forKey: .files) ?? []
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

public struct ListAutopilotsResponse: Codable, Sendable {
    public let autopilots: [Autopilot]
    public let total: Int
}

public struct GetAutopilotResponse: Codable, Sendable {
    public let autopilot: Autopilot
    public let triggers: [AutopilotTrigger]
}

public struct ListAutopilotRunsResponse: Codable, Sendable {
    public let runs: [AutopilotRun]
    public let total: Int
}

public struct Autopilot: Codable, Identifiable, Sendable {
    public let id: String
    public let workspaceId: String
    public let title: String
    public let description: String?
    public let assigneeId: String
    public let status: String
    public let executionMode: String
    public let issueTitleTemplate: String?
    public let createdByType: String
    public let createdById: String
    public let lastRunAt: Date?
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, status
        case workspaceId = "workspace_id"
        case assigneeId = "assignee_id"
        case executionMode = "execution_mode"
        case issueTitleTemplate = "issue_title_template"
        case createdByType = "created_by_type"
        case createdById = "created_by_id"
        case lastRunAt = "last_run_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct AutopilotTrigger: Codable, Identifiable, Sendable {
    public let id: String
    public let autopilotId: String
    public let kind: String
    public let enabled: Bool
    public let cronExpression: String?
    public let timezone: String?
    public let nextRunAt: Date?
    public let webhookToken: String?
    public let label: String?
    public let lastFiredAt: Date?
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, enabled, timezone, label
        case autopilotId = "autopilot_id"
        case cronExpression = "cron_expression"
        case nextRunAt = "next_run_at"
        case webhookToken = "webhook_token"
        case lastFiredAt = "last_fired_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct AutopilotRun: Codable, Identifiable, Sendable {
    public let id: String
    public let autopilotId: String
    public let triggerId: String?
    public let source: String
    public let status: String
    public let issueId: String?
    public let taskId: String?
    public let triggeredAt: Date
    public let completedAt: Date?
    public let failureReason: String?
    public let triggerPayload: JSONValue?
    public let result: JSONValue?
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, source, status, result
        case autopilotId = "autopilot_id"
        case triggerId = "trigger_id"
        case issueId = "issue_id"
        case taskId = "task_id"
        case triggeredAt = "triggered_at"
        case completedAt = "completed_at"
        case failureReason = "failure_reason"
        case triggerPayload = "trigger_payload"
        case createdAt = "created_at"
    }
}

// MARK: - Date formatting

/// Shared ISO8601 formatter for UI display (date + time, no Z suffix).
/// Use `.formatted()` on Date for the primary display path; this is a fallback.
public let iso8601DisplayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm"
    f.timeZone = .current
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

/// Shared ISO8601 date-only formatter for compact UI display.
public let iso8601DateOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = .current
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

// MARK: - Issues

public enum IssueStatus: String, Codable, CaseIterable, Sendable, Comparable {
    case backlog
    case todo
    case inProgress = "in_progress"
    case inReview = "in_review"
    case done
    case blocked
    case cancelled

    /// Fallback for unknown future statuses — prevents decoding crash.
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = IssueStatus(rawValue: raw) ?? .unknown
    }

    public static let displayCases: [IssueStatus] = [
        .backlog,
        .todo,
        .inProgress,
        .inReview,
        .done,
        .blocked,
        .cancelled,
    ]

    public static let boardCases: [IssueStatus] = [
        .backlog,
        .todo,
        .inProgress,
        .inReview,
        .done,
        .blocked,
    ]

    private var sortOrder: Int {
        switch self {
        case .backlog: return 0
        case .todo: return 1
        case .inProgress: return 2
        case .inReview: return 3
        case .done: return 4
        case .blocked: return 5
        case .cancelled: return 6
        case .unknown: return 7
        }
    }

    public static func < (lhs: IssueStatus, rhs: IssueStatus) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    public var displayName: String {
        switch self {
        case .backlog: return "Backlog"
        case .todo: return "Todo"
        case .inProgress: return "In Progress"
        case .inReview: return "In Review"
        case .done: return "Done"
        case .blocked: return "Blocked"
        case .cancelled: return "Cancelled"
        case .unknown: return "Unknown"
        }
    }

    public var icon: String {
        switch self {
        case .backlog: return "tray"
        case .todo: return "circle"
        case .inProgress: return "circle.dotted"
        case .inReview: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        case .blocked: return "minus.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

public enum IssuePriority: String, Codable, CaseIterable, Sendable {
    case urgent, high, medium, low
    case noPriority = "none"
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = raw == "no_priority" ? .noPriority : (IssuePriority(rawValue: raw) ?? .unknown)
    }

    public var displayName: String {
        switch self {
        case .urgent: return "Urgent"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .noPriority: return "No Priority"
        case .unknown: return "Unknown"
        }
    }
}

public struct Attachment: Codable, Identifiable, Sendable {
    public let id: String
    public let workspaceId: String
    public let issueId: String?
    public let commentId: String?
    public let uploaderType: String
    public let uploaderId: String
    public let filename: String
    public let url: String
    public let downloadUrl: String
    public let contentType: String
    public let sizeBytes: Int
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case workspaceId = "workspace_id"
        case issueId = "issue_id"
        case commentId = "comment_id"
        case uploaderType = "uploader_type"
        case uploaderId = "uploader_id"
        case filename, url
        case downloadUrl = "download_url"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case createdAt = "created_at"
    }

    public init(
        id: String,
        workspaceId: String,
        issueId: String?,
        commentId: String?,
        uploaderType: String,
        uploaderId: String,
        filename: String,
        url: String,
        downloadUrl: String,
        contentType: String,
        sizeBytes: Int,
        createdAt: Date
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.issueId = issueId
        self.commentId = commentId
        self.uploaderType = uploaderType
        self.uploaderId = uploaderId
        self.filename = filename
        self.url = url
        self.downloadUrl = downloadUrl
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
    }
}

public struct Issue: Codable, Identifiable, Sendable {
    public let id: String
    public let identifier: String
    public let number: Int
    public let title: String
    public let description: String?
    public let status: IssueStatus
    public let priority: IssuePriority
    public let assigneeId: String?
    public let assigneeType: String?
    public let projectId: String?
    public let dueDate: String?
    public let workspaceId: String
    public let attachments: [Attachment]
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, identifier, number, title, description, status, priority
        case assigneeId = "assignee_id"
        case assigneeType = "assignee_type"
        case projectId = "project_id"
        case dueDate = "due_date"
        case workspaceId = "workspace_id"
        case attachments
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(id: String, identifier: String, number: Int, title: String, description: String?,
                status: IssueStatus, priority: IssuePriority, assigneeId: String?,
                assigneeType: String?, projectId: String?, workspaceId: String,
                dueDate: String? = nil, attachments: [Attachment] = [], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.identifier = identifier
        self.number = number
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.assigneeId = assigneeId
        self.assigneeType = assigneeType
        self.projectId = projectId
        self.dueDate = dueDate
        self.workspaceId = workspaceId
        self.attachments = attachments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        identifier = try c.decode(String.self, forKey: .identifier)
        number = try c.decode(Int.self, forKey: .number)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        status = try c.decode(IssueStatus.self, forKey: .status)
        priority = try c.decode(IssuePriority.self, forKey: .priority)
        assigneeId = try c.decodeIfPresent(String.self, forKey: .assigneeId)
        assigneeType = try c.decodeIfPresent(String.self, forKey: .assigneeType)
        projectId = try c.decodeIfPresent(String.self, forKey: .projectId)
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        workspaceId = try c.decode(String.self, forKey: .workspaceId)
        attachments = try c.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}

public struct Comment: Codable, Identifiable, Sendable {
    public let id: String
    public let content: String
    public let authorId: String
    public let authorType: String
    public let parentId: String?
    public let issueId: String
    public let attachments: [Attachment]
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, content
        case authorId = "author_id"
        case authorType = "author_type"
        case parentId = "parent_id"
        case issueId = "issue_id"
        case attachments
        case createdAt = "created_at"
    }

    public init(id: String, content: String, authorId: String, authorType: String,
                parentId: String?, issueId: String, attachments: [Attachment] = [], createdAt: Date) {
        self.id = id
        self.content = content
        self.authorId = authorId
        self.authorType = authorType
        self.parentId = parentId
        self.issueId = issueId
        self.attachments = attachments
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        content = try c.decode(String.self, forKey: .content)
        authorId = try c.decode(String.self, forKey: .authorId)
        authorType = try c.decode(String.self, forKey: .authorType)
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        issueId = try c.decode(String.self, forKey: .issueId)
        attachments = try c.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}

// MARK: - Inbox

public struct InboxItem: Codable, Identifiable, Sendable {
    public let id: String
    public let issueId: String
    public let issueIdentifier: String
    public let issueTitle: String
    public let type: String
    public let body: String?
    public let severity: String?
    public let issueStatus: IssueStatus
    public let read: Bool
    public let archived: Bool
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case issueId = "issue_id"
        case issueIdentifier = "issue_identifier"
        case issueTitle = "issue_title"
        case type, body, severity
        case issueStatus = "issue_status"
        case read, archived
        case createdAt = "created_at"
    }

    private enum DesktopCodingKeys: String, CodingKey {
        case id, title, type, body, severity, read, archived, details
        case issueId = "issue_id"
        case issueStatus = "issue_status"
        case createdAt = "created_at"
    }

    public init(id: String, issueId: String, issueIdentifier: String, issueTitle: String,
                type: String = "notification", body: String? = nil, severity: String? = nil,
                issueStatus: IssueStatus = .unknown, read: Bool, archived: Bool = false,
                createdAt: Date) {
        self.id = id
        self.issueId = issueId
        self.issueIdentifier = issueIdentifier
        self.issueTitle = issueTitle
        self.type = type
        self.body = body
        self.severity = severity
        self.issueStatus = issueStatus
        self.read = read
        self.archived = archived
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let legacy = try decoder.container(keyedBy: CodingKeys.self)
        let desktop = try decoder.container(keyedBy: DesktopCodingKeys.self)
        let details = (try? desktop.decodeIfPresent([String: String].self, forKey: .details)) ?? nil

        id = try legacy.decode(String.self, forKey: .id)
        issueId = try legacy.decodeIfPresent(String.self, forKey: .issueId) ?? ""
        issueIdentifier = try legacy.decodeIfPresent(String.self, forKey: .issueIdentifier)
            ?? details?["identifier"]
            ?? issueId
        issueTitle = try legacy.decodeIfPresent(String.self, forKey: .issueTitle)
            ?? desktop.decode(String.self, forKey: .title)
        type = try legacy.decodeIfPresent(String.self, forKey: .type)
            ?? desktop.decodeIfPresent(String.self, forKey: .type)
            ?? "notification"
        body = try legacy.decodeIfPresent(String.self, forKey: .body)
            ?? desktop.decodeIfPresent(String.self, forKey: .body)
        severity = try legacy.decodeIfPresent(String.self, forKey: .severity)
            ?? desktop.decodeIfPresent(String.self, forKey: .severity)
        issueStatus = try legacy.decodeIfPresent(IssueStatus.self, forKey: .issueStatus)
            ?? desktop.decodeIfPresent(IssueStatus.self, forKey: .issueStatus)
            ?? .unknown
        read = try legacy.decode(Bool.self, forKey: .read)
        archived = try legacy.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        createdAt = try legacy.decode(Date.self, forKey: .createdAt)
    }
}

// MARK: - Projects

public enum ProjectStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case inProgress = "in_progress"
    case paused
    case completed
    case cancelled
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ProjectStatus(rawValue: raw) ?? .unknown
    }

    public var displayName: String {
        switch self {
        case .planned: return "Planned"
        case .inProgress: return "In Progress"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .unknown: return "Unknown"
        }
    }

    public var icon: String {
        switch self {
        case .planned: return "calendar"
        case .inProgress: return "circle.dotted"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

public struct Project: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let status: ProjectStatus
    public let priority: IssuePriority
    public let workspaceId: String
    public let createdAt: Date
    public let issueCount: Int
    public let doneCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, status, priority
        case workspaceId = "workspace_id"
        case createdAt = "created_at"
        case title
        case issueCount = "issue_count"
        case doneCount = "done_count"
    }

    public init(id: String, name: String, description: String?, workspaceId: String,
                createdAt: Date, issueCount: Int = 0, doneCount: Int = 0,
                status: ProjectStatus = .unknown, priority: IssuePriority = .unknown) {
        self.id = id
        self.name = name
        self.description = description
        self.status = status
        self.priority = priority
        self.workspaceId = workspaceId
        self.createdAt = createdAt
        self.issueCount = issueCount
        self.doneCount = doneCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        status = try container.decodeIfPresent(ProjectStatus.self, forKey: .status) ?? .unknown
        priority = try container.decodeIfPresent(IssuePriority.self, forKey: .priority) ?? .unknown
        workspaceId = try container.decode(String.self, forKey: .workspaceId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        issueCount = try container.decodeIfPresent(Int.self, forKey: .issueCount) ?? 0
        doneCount = try container.decodeIfPresent(Int.self, forKey: .doneCount) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(status, forKey: .status)
        try container.encode(priority, forKey: .priority)
        try container.encode(workspaceId, forKey: .workspaceId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(issueCount, forKey: .issueCount)
        try container.encode(doneCount, forKey: .doneCount)
    }
}

public struct ProjectResource: Codable, Identifiable, Sendable {
    public let id: String
    public let projectId: String
    public let workspaceId: String
    public let resourceType: String
    public let resourceRef: [String: JSONValue]
    public let label: String?
    public let position: Int
    public let createdAt: Date
    public let createdBy: String?

    enum CodingKeys: String, CodingKey {
        case id, label, position
        case projectId = "project_id"
        case workspaceId = "workspace_id"
        case resourceType = "resource_type"
        case resourceRef = "resource_ref"
        case createdAt = "created_at"
        case createdBy = "created_by"
    }

    public var displayTitle: String {
        if let label, !label.isEmpty {
            return label
        }
        if resourceType == "github_repo",
           case .string(let url)? = resourceRef["url"],
           !url.isEmpty {
            return url
        }
        return resourceType
    }
}

// MARK: - Agent Tasks

public struct AgentTask: Codable, Identifiable, Sendable {
    public let id: String
    public let issueId: String
    public let status: String
    public let startedAt: Date?
    public let completedAt: Date?
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case issueId = "issue_id"
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case error
    }

    public init(id: String, issueId: String, status: String, startedAt: Date?, completedAt: Date?, error: String?) {
        self.id = id
        self.issueId = issueId
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.error = error
    }
}

public struct TaskMessage: Codable, Identifiable, Sendable {
    public let id: String
    public let seq: Int
    public let type: MessageType
    public let tool: String?
    public let content: String?
    public let input: [String: JSONValue]?
    public let output: String?

    public enum MessageType: String, Codable, Sendable {
        case toolUse = "tool_use"
        case toolResult = "tool_result"
        case thinking
        case text
        case error
    }

    public init(id: String, seq: Int, type: MessageType, tool: String?, content: String?,
                input: [String: JSONValue]?, output: String?) {
        self.id = id
        self.seq = seq
        self.type = type
        self.tool = tool
        self.content = content
        self.input = input
        self.output = output
    }

    enum CodingKeys: String, CodingKey {
        case id, seq, type, tool, content, input, output
        case taskId = "task_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seq = try container.decode(Int.self, forKey: .seq)
        type = try container.decode(MessageType.self, forKey: .type)
        tool = try container.decodeIfPresent(String.self, forKey: .tool)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        input = try container.decodeIfPresent([String: JSONValue].self, forKey: .input)
        output = try container.decodeIfPresent(String.self, forKey: .output)
        if let decodedId = try container.decodeIfPresent(String.self, forKey: .id) {
            id = decodedId
        } else if let taskId = try container.decodeIfPresent(String.self, forKey: .taskId) {
            id = "\(taskId):\(seq)"
        } else {
            id = "\(seq)"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(seq, forKey: .seq)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(tool, forKey: .tool)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(input, forKey: .input)
        try container.encodeIfPresent(output, forKey: .output)
    }
}

public indirect enum JSONValue: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let b = try? container.decode(Bool.self) { self = .bool(b); return }
        if let i = try? container.decode(Int.self) { self = .int(i); return }
        if let d = try? container.decode(Double.self) { self = .double(d); return }
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let a = try? container.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? container.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported JSON value"
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }

    /// Flat string representation for UI summaries (not round-trip).
    public var displayString: String {
        switch self {
        case .null: return ""
        case .bool(let v): return String(v)
        case .int(let v): return String(v)
        case .double(let v): return String(v)
        case .string(let v): return v
        case .array(let v): return "[\(v.count) items]"
        case .object(let v): return "{\(v.count) keys}"
        }
    }
}

// MARK: - WebSocket Events

public struct WSEvent: Sendable {
    public let type: String
    public let taskId: String?
    public let payload: Data

    public init(type: String, taskId: String?, payload: Data) {
        self.type = type
        self.taskId = taskId
        self.payload = payload
    }
}
