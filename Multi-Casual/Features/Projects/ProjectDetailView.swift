#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct ProjectDetailView: View {
    public let project: Project
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var issues: [Issue] = []
    @State private var isLoading = true

    public init(project: Project) { self.project = project }

    public var body: some View {
        List {
            Section("Details") {
                if let desc = project.description { Text(desc).foregroundStyle(.secondary) }
            }
            Section("Issues (\(issues.count))") {
                if isLoading { ProgressView() }
                else {
                    ForEach(issues) { issue in
                        NavigationLink(destination: IssueDetailView(issueId: issue.id)) {
                            IssueRowView(issue: issue)
                        }
                    }
                }
            }
        }
        .navigationTitle(project.name)
        .task {
            if let wsId = authSession.currentWorkspace?.id {
                if let page = try? await api.listIssues(workspaceId: wsId, limit: 200, offset: 0) {
                    issues = page.items.filter { $0.projectId == project.id }
                }
            }
            isLoading = false
        }
    }
}
#endif
