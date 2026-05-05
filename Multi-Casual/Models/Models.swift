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
    public let name: String
    public let description: String
    public let status: String
    public let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, status
        case workspaceId = "workspace_id"
        case avatarUrl = "avatar_url"
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
    public let workspaceId: String
    public let createdAt: Date
    public let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, identifier, number, title, description, status, priority
        case assigneeId = "assignee_id"
        case assigneeType = "assignee_type"
        case projectId = "project_id"
        case workspaceId = "workspace_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(id: String, identifier: String, number: Int, title: String, description: String?,
                status: IssueStatus, priority: IssuePriority, assigneeId: String?,
                assigneeType: String?, projectId: String?, workspaceId: String,
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
        self.projectId = projectId
        self.workspaceId = workspaceId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct Comment: Codable, Identifiable, Sendable {
    public let id: String
    public let content: String
    public let authorId: String
    public let authorType: String
    public let parentId: String?
    public let issueId: String
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, content
        case authorId = "author_id"
        case authorType = "author_type"
        case parentId = "parent_id"
        case issueId = "issue_id"
        case createdAt = "created_at"
    }

    public init(id: String, content: String, authorId: String, authorType: String,
                parentId: String?, issueId: String, createdAt: Date) {
        self.id = id
        self.content = content
        self.authorId = authorId
        self.authorType = authorType
        self.parentId = parentId
        self.issueId = issueId
        self.createdAt = createdAt
    }
}

// MARK: - Inbox

public struct InboxItem: Codable, Identifiable, Sendable {
    public let id: String
    public let issueId: String
    public let issueIdentifier: String
    public let issueTitle: String
    public let read: Bool
    public let archived: Bool
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case issueId = "issue_id"
        case issueIdentifier = "issue_identifier"
        case issueTitle = "issue_title"
        case read, archived
        case createdAt = "created_at"
    }

    private enum DesktopCodingKeys: String, CodingKey {
        case id, title, read, archived, details
        case issueId = "issue_id"
        case createdAt = "created_at"
    }

    public init(id: String, issueId: String, issueIdentifier: String, issueTitle: String,
                read: Bool, archived: Bool = false, createdAt: Date) {
        self.id = id
        self.issueId = issueId
        self.issueIdentifier = issueIdentifier
        self.issueTitle = issueTitle
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
        read = try legacy.decode(Bool.self, forKey: .read)
        archived = try legacy.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        createdAt = try legacy.decode(Date.self, forKey: .createdAt)
    }
}

// MARK: - Projects

public struct Project: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let workspaceId: String
    public let createdAt: Date
    public let issueCount: Int
    public let doneCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case workspaceId = "workspace_id"
        case createdAt = "created_at"
        case title
        case issueCount = "issue_count"
        case doneCount = "done_count"
    }

    public init(id: String, name: String, description: String?, workspaceId: String,
                createdAt: Date, issueCount: Int = 0, doneCount: Int = 0) {
        self.id = id
        self.name = name
        self.description = description
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
