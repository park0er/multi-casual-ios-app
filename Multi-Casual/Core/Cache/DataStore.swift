import Foundation

public actor DataStore {
    public static let shared = DataStore()

    public private(set) var issues: [Issue] = []
    public private(set) var inbox: [InboxItem] = []
    public private(set) var projects: [Project] = []

    public init() {}

    public func setIssues(_ list: [Issue]) { issues = list }
    public func appendIssues(_ list: [Issue]) { issues += list }
    public func setInbox(_ list: [InboxItem]) { inbox = list }
    public func setProjects(_ list: [Project]) { projects = list }

    public func invalidateIssue(_ id: String) {
        issues.removeAll { $0.id == id }
    }
}
