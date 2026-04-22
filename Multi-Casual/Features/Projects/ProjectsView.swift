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
                    ForEach(vm.loader.items) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name).font(.body)
                                if let desc = project.description {
                                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }.padding(.vertical, 4)
                        }
                    }
                    if vm.loader.hasMore { ProgressView().onAppear { Task { await vm.loadNext() } } }
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
    }
}
#endif
