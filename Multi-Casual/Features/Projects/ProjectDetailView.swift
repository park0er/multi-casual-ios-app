#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct ProjectDetailView: View {
    public let project: Project
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var viewModel: ProjectDetailViewModel?

    public init(project: Project) { self.project = project }

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    Section("Details") {
                        if let desc = vm.project.description {
                            Text(desc).foregroundStyle(.secondary)
                        }
                        LabeledContent("Status", value: vm.project.status.displayName)
                        LabeledContent("Priority", value: vm.project.priority.displayName)
                        LabeledContent("Progress", value: vm.progressText)
                    }

                    Section("Resources (\(vm.resources.count))") {
                        if vm.isLoading {
                            ProgressView()
                        } else if vm.resources.isEmpty {
                            Text("No resources").foregroundStyle(.secondary)
                        } else {
                            ForEach(vm.resources) { resource in
                                ProjectResourceRow(resource: resource)
                            }
                        }
                    }

                    Section("Issues (\(vm.issues.count))") {
                        if vm.isLoading {
                            ProgressView()
                        } else if vm.issues.isEmpty {
                            Text("No issues").foregroundStyle(.secondary)
                        } else {
                            ForEach(vm.issues) { issue in
                                NavigationLink(destination: IssueDetailView(issueId: issue.id)) {
                                    IssueRowView(issue: issue)
                                }
                            }
                        }
                    }

                    if let error = vm.errorMessage {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(project.name)
        .refreshable { await viewModel?.load() }
        .task {
            if viewModel == nil {
                let vm = ProjectDetailViewModel(project: project, api: api, authSession: authSession)
                viewModel = vm
                await vm.load()
            }
        }
    }
}

private struct ProjectResourceRow: View {
    let resource: ProjectResource

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: resource.resourceType == "github_repo" ? "folder.badge.gearshape" : "link")
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.displayTitle)
                    .font(.body)
                    .lineLimit(1)
                Text(resource.resourceType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
#endif
