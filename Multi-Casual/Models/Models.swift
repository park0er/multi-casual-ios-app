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
    public let description: String?
    public let context: String?
    public let repos: [WorkspaceRepo]

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, context, repos
        case issuePrefix = "issue_prefix"
    }

    public init(
        id: String,
        name: String,
        slug: String,
        issuePrefix: String,
        description: String? = nil,
        context: String? = nil,
        repos: [WorkspaceRepo] = []
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.issuePrefix = issuePrefix
        self.description = description
        self.context = context
        self.repos = repos
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        slug = try container.decode(String.self, forKey: .slug)
        issuePrefix = try container.decode(String.self, forKey: .issuePrefix)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        context = try container.decodeIfPresent(String.self, forKey: .context)
        repos = try container.decodeIfPresent([WorkspaceRepo].self, forKey: .repos) ?? []
    }
}

public struct WorkspaceRepo: Codable, Hashable, Sendable {
    public let url: String
    public let defaultBranchHint: String?

    enum CodingKeys: String, CodingKey {
        case url
        case defaultBranchHint = "default_branch_hint"
    }

    public init(url: String, defaultBranchHint: String? = nil) {
        self.url = url
        self.defaultBranchHint = defaultBranchHint
    }
}

public enum PinnedItemType: String, Codable, Sendable {
    case issue
    case project
}

public struct PinnedItem: Codable, Identifiable, Sendable {
    public let id: String
    public let workspaceId: String
    public let userId: String
    public let itemType: PinnedItemType
    public let itemId: String
    public let position: Int
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, position
        case workspaceId = "workspace_id"
        case userId = "user_id"
        case itemType = "item_type"
        case itemId = "item_id"
        case createdAt = "created_at"
    }

    public init(
        id: String,
        workspaceId: String,
        userId: String,
        itemType: PinnedItemType,
        itemId: String,
        position: Int,
        createdAt: Date
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.userId = userId
        self.itemType = itemType
        self.itemId = itemId
        self.position = position
        self.createdAt = createdAt
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

public struct Invitation: Codable, Identifiable, Sendable {
    public let id: String
    public let workspaceId: String
    public let email: String
    public let role: String
    public let status: String
    public let createdAt: String?
    public let updatedAt: String?
    public let expiresAt: String?
    public let inviterId: String?
    public let inviteeUserId: String?
    public let inviterName: String?
    public let inviterEmail: String?
    public let workspaceName: String?

    enum CodingKeys: String, CodingKey {
        case id, email, role, status
        case workspaceId = "workspace_id"
        case inviterId = "inviter_id"
        case inviteeEmail = "invitee_email"
        case inviteeUserId = "invitee_user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case expiresAt = "expires_at"
        case inviterName = "inviter_name"
        case inviterEmail = "inviter_email"
        case workspaceName = "workspace_name"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        workspaceId = try container.decode(String.self, forKey: .workspaceId)
        email = try container.decodeIfPresent(String.self, forKey: .inviteeEmail)
            ?? container.decodeIfPresent(String.self, forKey: .email)
            ?? ""
        role = try container.decode(String.self, forKey: .role)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt)
        inviterId = try container.decodeIfPresent(String.self, forKey: .inviterId)
        inviteeUserId = try container.decodeIfPresent(String.self, forKey: .inviteeUserId)
        inviterName = try container.decodeIfPresent(String.self, forKey: .inviterName)
        inviterEmail = try container.decodeIfPresent(String.self, forKey: .inviterEmail)
        workspaceName = try container.decodeIfPresent(String.self, forKey: .workspaceName)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(workspaceId, forKey: .workspaceId)
        try container.encode(email, forKey: .inviteeEmail)
        try container.encode(role, forKey: .role)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
        try container.encodeIfPresent(inviterId, forKey: .inviterId)
        try container.encodeIfPresent(inviteeUserId, forKey: .inviteeUserId)
        try container.encodeIfPresent(inviterName, forKey: .inviterName)
        try container.encodeIfPresent(inviterEmail, forKey: .inviterEmail)
        try container.encodeIfPresent(workspaceName, forKey: .workspaceName)
    }
}

// MARK: - Personal Access Tokens

public struct PersonalAccessToken: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let tokenPrefix: String
    public let expiresAt: String?
    public let lastUsedAt: String?
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case tokenPrefix = "token_prefix"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
    }

    public init(
        id: String,
        name: String,
        tokenPrefix: String,
        expiresAt: String?,
        lastUsedAt: String?,
        createdAt: String
    ) {
        self.id = id
        self.name = name
        self.tokenPrefix = tokenPrefix
        self.expiresAt = expiresAt
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
    }
}

public struct CreatedPersonalAccessToken: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let tokenPrefix: String
    public let expiresAt: String?
    public let lastUsedAt: String?
    public let createdAt: String
    public let token: String

    enum CodingKeys: String, CodingKey {
        case id, name, token
        case tokenPrefix = "token_prefix"
        case expiresAt = "expires_at"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
    }
}

// MARK: - Notification Preferences

public enum NotificationPreferenceGroup: String, Codable, CaseIterable, Identifiable, Sendable {
    case assignments
    case statusChanges = "status_changes"
    case comments
    case updates
    case agentActivity = "agent_activity"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .assignments:
            "Assignments"
        case .statusChanges:
            "Status Changes"
        case .comments:
            "Comments & Mentions"
        case .updates:
            "Priority & Due Date"
        case .agentActivity:
            "Agent Activity"
        }
    }

    public var detail: String {
        switch self {
        case .assignments:
            "When you are assigned or unassigned from an issue"
        case .statusChanges:
            "When an issue you follow changes status"
        case .comments:
            "New comments on followed issues and mentions"
        case .updates:
            "When priority or due date changes on followed issues"
        case .agentActivity:
            "When an agent task completes or fails"
        }
    }
}

public enum NotificationPreferenceValue: String, Codable, Sendable {
    case all
    case muted
}

public struct NotificationPreferences: Codable, Equatable, Sendable {
    public var assignments: NotificationPreferenceValue?
    public var statusChanges: NotificationPreferenceValue?
    public var comments: NotificationPreferenceValue?
    public var updates: NotificationPreferenceValue?
    public var agentActivity: NotificationPreferenceValue?

    enum CodingKeys: String, CodingKey {
        case assignments
        case statusChanges = "status_changes"
        case comments
        case updates
        case agentActivity = "agent_activity"
    }

    public init(
        assignments: NotificationPreferenceValue? = nil,
        statusChanges: NotificationPreferenceValue? = nil,
        comments: NotificationPreferenceValue? = nil,
        updates: NotificationPreferenceValue? = nil,
        agentActivity: NotificationPreferenceValue? = nil
    ) {
        self.assignments = assignments
        self.statusChanges = statusChanges
        self.comments = comments
        self.updates = updates
        self.agentActivity = agentActivity
    }

    public func value(for group: NotificationPreferenceGroup) -> NotificationPreferenceValue {
        switch group {
        case .assignments:
            assignments ?? .all
        case .statusChanges:
            statusChanges ?? .all
        case .comments:
            comments ?? .all
        case .updates:
            updates ?? .all
        case .agentActivity:
            agentActivity ?? .all
        }
    }

    public mutating func set(_ group: NotificationPreferenceGroup, to value: NotificationPreferenceValue?) {
        switch group {
        case .assignments:
            assignments = value
        case .statusChanges:
            statusChanges = value
        case .comments:
            comments = value
        case .updates:
            updates = value
        case .agentActivity:
            agentActivity = value
        }
    }
}

public struct NotificationPreferenceResponse: Codable, Sendable {
    public let workspaceId: String
    public let preferences: NotificationPreferences

    enum CodingKeys: String, CodingKey {
        case workspaceId = "workspace_id"
        case preferences
    }

    public init(workspaceId: String, preferences: NotificationPreferences) {
        self.workspaceId = workspaceId
        self.preferences = preferences
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
    public let ownerId: String?
    public let archivedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, instructions, status, visibility, model
        case workspaceId = "workspace_id"
        case runtimeId = "runtime_id"
        case avatarUrl = "avatar_url"
        case runtimeMode = "runtime_mode"
        case maxConcurrentTasks = "max_concurrent_tasks"
        case ownerId = "owner_id"
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
        ownerId: String? = nil,
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
        self.ownerId = ownerId
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
        ownerId = try c.decodeIfPresent(String.self, forKey: .ownerId)
        archivedAt = try c.decodeIfPresent(String.self, forKey: .archivedAt)
    }
}

public struct AgentRuntime: Codable, Identifiable, Sendable {
    public let id: String
    public let workspaceId: String
    public let daemonId: String?
    public let name: String
    public let runtimeMode: String
    public let provider: String
    public let launchHeader: String
    public let status: String
    public let deviceInfo: String
    public let metadata: [String: JSONValue]
    public let ownerId: String?
    public let lastSeenAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, provider, status
        case workspaceId = "workspace_id"
        case daemonId = "daemon_id"
        case runtimeMode = "runtime_mode"
        case launchHeader = "launch_header"
        case deviceInfo = "device_info"
        case metadata
        case ownerId = "owner_id"
        case lastSeenAt = "last_seen_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String,
        workspaceId: String,
        name: String,
        runtimeMode: String,
        provider: String,
        status: String,
        daemonId: String? = nil,
        launchHeader: String = "",
        deviceInfo: String = "",
        metadata: [String: JSONValue] = [:],
        ownerId: String? = nil,
        lastSeenAt: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.name = name
        self.runtimeMode = runtimeMode
        self.provider = provider
        self.status = status
        self.daemonId = daemonId
        self.launchHeader = launchHeader
        self.deviceInfo = deviceInfo
        self.metadata = metadata
        self.ownerId = ownerId
        self.lastSeenAt = lastSeenAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        workspaceId = try c.decode(String.self, forKey: .workspaceId)
        daemonId = try c.decodeIfPresent(String.self, forKey: .daemonId)
        name = try c.decode(String.self, forKey: .name)
        runtimeMode = try c.decodeIfPresent(String.self, forKey: .runtimeMode) ?? "cloud"
        provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? ""
        launchHeader = try c.decodeIfPresent(String.self, forKey: .launchHeader) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "offline"
        deviceInfo = try c.decodeIfPresent(String.self, forKey: .deviceInfo) ?? ""
        metadata = try c.decodeIfPresent([String: JSONValue].self, forKey: .metadata) ?? [:]
        ownerId = try c.decodeIfPresent(String.self, forKey: .ownerId)
        lastSeenAt = try c.decodeIfPresent(Date.self, forKey: .lastSeenAt)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

public struct RuntimeUsage: Codable, Sendable, Hashable {
    public let runtimeId: String
    public let date: String
    public let provider: String
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheReadTokens: Int
    public let cacheWriteTokens: Int

    public var totalTokens: Int {
        inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens
    }

    enum CodingKeys: String, CodingKey {
        case runtimeId = "runtime_id"
        case date, provider, model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cacheWriteTokens = "cache_write_tokens"
    }
}

public struct RuntimeUsageSummary: Sendable, Hashable {
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let totalCacheReadTokens: Int
    public let totalCacheWriteTokens: Int

    public var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheReadTokens + totalCacheWriteTokens
    }

    public static func summarize(_ rows: [RuntimeUsage]) -> RuntimeUsageSummary {
        RuntimeUsageSummary(
            totalInputTokens: rows.reduce(0) { $0 + $1.inputTokens },
            totalOutputTokens: rows.reduce(0) { $0 + $1.outputTokens },
            totalCacheReadTokens: rows.reduce(0) { $0 + $1.cacheReadTokens },
            totalCacheWriteTokens: rows.reduce(0) { $0 + $1.cacheWriteTokens }
        )
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

public struct IssueLabel: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let workspaceId: String
    public let name: String
    public let color: String
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, color
        case workspaceId = "workspace_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(id: String, workspaceId: String, name: String, color: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.workspaceId = workspaceId
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ListLabelsResponse: Codable, Sendable {
    public let labels: [IssueLabel]
    public let total: Int?
}

public struct IssueLabelsResponse: Codable, Sendable {
    public let labels: [IssueLabel]
}

public struct IssueReaction: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let issueId: String
    public let actorType: String
    public let actorId: String
    public let emoji: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, emoji
        case issueId = "issue_id"
        case actorType = "actor_type"
        case actorId = "actor_id"
        case createdAt = "created_at"
    }

    public init(id: String, issueId: String, actorType: String, actorId: String, emoji: String, createdAt: Date) {
        self.id = id
        self.issueId = issueId
        self.actorType = actorType
        self.actorId = actorId
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

public struct Reaction: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let commentId: String
    public let actorType: String
    public let actorId: String
    public let emoji: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, emoji
        case commentId = "comment_id"
        case actorType = "actor_type"
        case actorId = "actor_id"
        case createdAt = "created_at"
    }

    public init(id: String, commentId: String, actorType: String, actorId: String, emoji: String, createdAt: Date) {
        self.id = id
        self.commentId = commentId
        self.actorType = actorType
        self.actorId = actorId
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

public struct IssueSubscriber: Codable, Identifiable, Hashable, Sendable {
    public let issueId: String
    public let userType: String
    public let userId: String
    public let reason: String
    public let createdAt: Date

    public var id: String { "\(userType):\(userId)" }

    enum CodingKeys: String, CodingKey {
        case reason
        case issueId = "issue_id"
        case userType = "user_type"
        case userId = "user_id"
        case createdAt = "created_at"
    }

    public init(issueId: String, userType: String, userId: String, reason: String, createdAt: Date) {
        self.issueId = issueId
        self.userType = userType
        self.userId = userId
        self.reason = reason
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
    public let parentIssueId: String?
    public let projectId: String?
    public let dueDate: String?
    public let workspaceId: String
    public let attachments: [Attachment]
    public let labels: [IssueLabel]
    public let reactions: [IssueReaction]
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, identifier, number, title, description, status, priority
        case assigneeId = "assignee_id"
        case assigneeType = "assignee_type"
        case parentIssueId = "parent_issue_id"
        case projectId = "project_id"
        case dueDate = "due_date"
        case workspaceId = "workspace_id"
        case attachments, labels, reactions
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(id: String, identifier: String, number: Int, title: String, description: String?,
                status: IssueStatus, priority: IssuePriority, assigneeId: String?,
                assigneeType: String?, parentIssueId: String? = nil, projectId: String?, workspaceId: String,
                dueDate: String? = nil, attachments: [Attachment] = [], labels: [IssueLabel] = [],
                reactions: [IssueReaction] = [],
                createdAt: Date, updatedAt: Date) {
        self.id = id
        self.identifier = identifier
        self.number = number
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.assigneeId = assigneeId
        self.assigneeType = assigneeType
        self.parentIssueId = parentIssueId
        self.projectId = projectId
        self.dueDate = dueDate
        self.workspaceId = workspaceId
        self.attachments = attachments
        self.labels = labels
        self.reactions = reactions
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
        parentIssueId = try c.decodeIfPresent(String.self, forKey: .parentIssueId)
        projectId = try c.decodeIfPresent(String.self, forKey: .projectId)
        dueDate = try c.decodeIfPresent(String.self, forKey: .dueDate)
        workspaceId = try c.decode(String.self, forKey: .workspaceId)
        attachments = try c.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        labels = try c.decodeIfPresent([IssueLabel].self, forKey: .labels) ?? []
        reactions = try c.decodeIfPresent([IssueReaction].self, forKey: .reactions) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }

    public func replacingLabels(_ labels: [IssueLabel]) -> Issue {
        Issue(
            id: id,
            identifier: identifier,
            number: number,
            title: title,
            description: description,
            status: status,
            priority: priority,
            assigneeId: assigneeId,
            assigneeType: assigneeType,
            parentIssueId: parentIssueId,
            projectId: projectId,
            workspaceId: workspaceId,
            dueDate: dueDate,
            attachments: attachments,
            labels: labels,
            reactions: reactions,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public func replacingReactions(_ reactions: [IssueReaction]) -> Issue {
        Issue(
            id: id,
            identifier: identifier,
            number: number,
            title: title,
            description: description,
            status: status,
            priority: priority,
            assigneeId: assigneeId,
            assigneeType: assigneeType,
            parentIssueId: parentIssueId,
            projectId: projectId,
            workspaceId: workspaceId,
            dueDate: dueDate,
            attachments: attachments,
            labels: labels,
            reactions: reactions,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

public struct ChildIssuesResponse: Codable, Sendable {
    public let issues: [Issue]
}

public struct ChildIssueProgressEntry: Codable, Identifiable, Sendable {
    public let parentIssueId: String
    public let total: Int
    public let done: Int

    public var id: String { parentIssueId }

    enum CodingKeys: String, CodingKey {
        case parentIssueId = "parent_issue_id"
        case total, done
    }
}

public struct ChildIssueProgressResponse: Codable, Sendable {
    public let progress: [ChildIssueProgressEntry]
}

public enum TimelineEntryType: String, Codable, Sendable {
    case activity
    case comment
}

public struct TimelineEntry: Codable, Identifiable, Sendable {
    public let type: TimelineEntryType
    public let id: String
    public let actorType: String
    public let actorId: String
    public let createdAt: Date
    public let action: String?
    public let details: [String: JSONValue]
    public let content: String?
    public let parentId: String?
    public let updatedAt: Date?
    public let commentType: String?
    public let reactions: [Reaction]
    public let attachments: [Attachment]

    enum CodingKeys: String, CodingKey {
        case type, id, action, details, content, reactions, attachments
        case actorType = "actor_type"
        case actorId = "actor_id"
        case createdAt = "created_at"
        case parentId = "parent_id"
        case updatedAt = "updated_at"
        case commentType = "comment_type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(TimelineEntryType.self, forKey: .type)
        id = try container.decode(String.self, forKey: .id)
        actorType = try container.decode(String.self, forKey: .actorType)
        actorId = try container.decode(String.self, forKey: .actorId)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        details = try container.decodeIfPresent([String: JSONValue].self, forKey: .details) ?? [:]
        content = try container.decodeIfPresent(String.self, forKey: .content)
        parentId = try container.decodeIfPresent(String.self, forKey: .parentId)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        commentType = try container.decodeIfPresent(String.self, forKey: .commentType)
        reactions = try container.decodeIfPresent([Reaction].self, forKey: .reactions) ?? []
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
    }

    public func detailString(_ key: String) -> String? {
        guard let value = details[key] else { return nil }
        let display = value.displayString
        return display.isEmpty ? nil : display
    }
}

public struct IssueUsageSummary: Codable, Sendable, Hashable {
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let totalCacheReadTokens: Int
    public let totalCacheWriteTokens: Int
    public let taskCount: Int

    public var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheReadTokens + totalCacheWriteTokens
    }

    enum CodingKeys: String, CodingKey {
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case totalCacheReadTokens = "total_cache_read_tokens"
        case totalCacheWriteTokens = "total_cache_write_tokens"
        case taskCount = "task_count"
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
    public let reactions: [Reaction]
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, content
        case authorId = "author_id"
        case authorType = "author_type"
        case parentId = "parent_id"
        case issueId = "issue_id"
        case attachments, reactions
        case createdAt = "created_at"
    }

    public init(id: String, content: String, authorId: String, authorType: String,
                parentId: String?, issueId: String, attachments: [Attachment] = [],
                reactions: [Reaction] = [], createdAt: Date) {
        self.id = id
        self.content = content
        self.authorId = authorId
        self.authorType = authorType
        self.parentId = parentId
        self.issueId = issueId
        self.attachments = attachments
        self.reactions = reactions
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
        reactions = try c.decodeIfPresent([Reaction].self, forKey: .reactions) ?? []
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    public func replacingReactions(_ reactions: [Reaction]) -> Comment {
        Comment(
            id: id,
            content: content,
            authorId: authorId,
            authorType: authorType,
            parentId: parentId,
            issueId: issueId,
            attachments: attachments,
            reactions: reactions,
            createdAt: createdAt
        )
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
    public let icon: String?
    public let status: ProjectStatus
    public let priority: IssuePriority
    public let leadType: String?
    public let leadId: String?
    public let workspaceId: String
    public let createdAt: Date
    public let issueCount: Int
    public let doneCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, status, priority
        case workspaceId = "workspace_id"
        case leadType = "lead_type"
        case leadId = "lead_id"
        case createdAt = "created_at"
        case title
        case issueCount = "issue_count"
        case doneCount = "done_count"
    }

    public init(id: String, name: String, description: String?, workspaceId: String,
                createdAt: Date, issueCount: Int = 0, doneCount: Int = 0,
                status: ProjectStatus = .unknown, priority: IssuePriority = .unknown,
                icon: String? = nil, leadType: String? = nil, leadId: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.status = status
        self.priority = priority
        self.leadType = leadType
        self.leadId = leadId
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
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        status = try container.decodeIfPresent(ProjectStatus.self, forKey: .status) ?? .unknown
        priority = try container.decodeIfPresent(IssuePriority.self, forKey: .priority) ?? .unknown
        leadType = try container.decodeIfPresent(String.self, forKey: .leadType)
        leadId = try container.decodeIfPresent(String.self, forKey: .leadId)
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
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encode(status, forKey: .status)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(leadType, forKey: .leadType)
        try container.encodeIfPresent(leadId, forKey: .leadId)
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
