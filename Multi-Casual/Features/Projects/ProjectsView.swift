#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct ProjectsView: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var viewModel: ProjectsViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.loader.items.isEmpty && !vm.loader.hasMore && !vm.loader.isLoading && vm.lastError == nil {
                        ContentUnavailableView("No Projects", systemImage: "folder", description: Text("There are no projects in this workspace."))
                    }
                    ForEach(vm.loader.items) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            VStack(alignment: .leading, spacing: 4) {
                                MarkdownText(project.name).font(.body)
                                if let desc = project.description {
                                    MarkdownText(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                HStack(spacing: 8) {
                                    Label(project.status.displayName, systemImage: project.status.icon)
                                    Label(project.priority.displayName, systemImage: "flag")
                                    Text("\(project.doneCount)/\(project.issueCount) done")
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                    if vm.loader.hasMore { ProgressView().onAppear { Task { await vm.loadNext() } } }
                    if let error = vm.lastError {
                        ErrorRetryView(message: error.localizedDescription) {
                            Task { await vm.refresh() }
                        }
                    }
                }
                .listStyle(.plain).refreshable { await vm.refresh() }
            } else { ProgressView() }
        }
        .navigationTitle("Projects")
        .onAppear {
            if viewModel == nil {
                viewModel = ProjectsViewModel(api: api, authSession: authSession)
                Task { await viewModel?.loadNext() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            guard let viewModel else { return }
            Task { await viewModel.refresh() }
        }
    }
}
#endif
