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

// MARK: - Issues

public enum IssueStatus: String, Codable, CaseIterable, Sendable {
    case todo
    case inProgress = "in_progress"
    case inReview = "in_review"
    case done
    case blocked

    public var displayName: String {
        switch self {
        case .todo: return "Todo"
        case .inProgress: return "In Progress"
        case .inReview: return "In Review"
        case .done: return "Done"
        case .blocked: return "Blocked"
        }
    }

    public var icon: String {
        switch self {
        case .todo: return "circle"
        case .inProgress: return "circle.dotted"
        case .inReview: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        case .blocked: return "minus.circle.fill"
        }
    }
}

public enum IssuePriority: String, Codable, CaseIterable, Sendable {
    case urgent, high, medium, low
    case noPriority = "no_priority"

    public var displayName: String {
        switch self {
        case .urgent: return "Urgent"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        case .noPriority: return "No Priority"
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
    public let createdAt: String
    public let updatedAt: String

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
                createdAt: String, updatedAt: String) {
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
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, content
        case authorId = "author_id"
        case authorType = "author_type"
        case parentId = "parent_id"
        case issueId = "issue_id"
        case createdAt = "created_at"
    }

    public init(id: String, content: String, authorId: String, authorType: String,
                parentId: String?, issueId: String, createdAt: String) {
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
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case issueId = "issue_id"
        case issueIdentifier = "issue_identifier"
        case issueTitle = "issue_title"
        case read
        case createdAt = "created_at"
    }

    public init(id: String, issueId: String, issueIdentifier: String, issueTitle: String,
                read: Bool, createdAt: String) {
        self.id = id
        self.issueId = issueId
        self.issueIdentifier = issueIdentifier
        self.issueTitle = issueTitle
        self.read = read
        self.createdAt = createdAt
    }
}

// MARK: - Projects

public struct Project: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let workspaceId: String
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case workspaceId = "workspace_id"
        case createdAt = "created_at"
    }

    public init(id: String, name: String, description: String?, workspaceId: String, createdAt: String) {
        self.id = id
        self.name = name
        self.description = description
        self.workspaceId = workspaceId
        self.createdAt = createdAt
    }
}

// MARK: - Agent Tasks

public struct AgentTask: Codable, Identifiable, Sendable {
    public let id: String
    public let issueId: String
    public let status: String
    public let startedAt: String?
    public let completedAt: String?
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case id
        case issueId = "issue_id"
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case error
    }

    public init(id: String, issueId: String, status: String, startedAt: String?, completedAt: String?, error: String?) {
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
    public let input: [String: AnyCodable]?
    public let output: String?

    public enum MessageType: String, Codable, Sendable {
        case toolUse = "tool_use"
        case toolResult = "tool_result"
        case thinking
        case text
        case error
    }

    public init(id: String, seq: Int, type: MessageType, tool: String?, content: String?,
                input: [String: AnyCodable]?, output: String?) {
        self.id = id
        self.seq = seq
        self.type = type
        self.tool = tool
        self.content = content
        self.input = input
        self.output = output
    }
}

public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) { value = str }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let dict = try? container.decode([String: String].self) { value = dict }
        else { value = "" }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let str = value as? String { try container.encode(str) }
        else if let int = value as? Int { try container.encode(int) }
        else if let bool = value as? Bool { try container.encode(bool) }
        else { try container.encode("") }
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
