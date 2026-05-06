#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct ProjectDetailView: View {
    public let project: Project
    @Environment(AuthSession.self) private var authSession
    @Environment(APIClient.self) private var api
    @State private var viewModel: ProjectDetailViewModel?
    @State private var pinViewModel: PinToggleViewModel?
    @State private var isAddingResource = false

    public init(project: Project) { self.project = project }

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    Section("Details") {
                        if let icon = vm.project.icon, !icon.isEmpty {
                            MarkdownLabeledContent("Icon", value: icon)
                        }
                        if let desc = vm.project.description {
                            MarkdownText(desc).foregroundStyle(.secondary)
                        }
                        MarkdownLabeledContent("Status", value: vm.project.status.displayName)
                        MarkdownLabeledContent("Priority", value: vm.project.priority.displayName)
                        if let leadText {
                            MarkdownLabeledContent("Lead", value: leadText)
                        }
                        MarkdownLabeledContent("Progress", value: vm.progressText)
                    }

                    Section {
                        if vm.isLoading {
                            ProgressView()
                        } else if vm.resources.isEmpty {
                            Text("No resources").foregroundStyle(.secondary)
                        } else {
                            ForEach(vm.resources) { resource in
                                ProjectResourceRow(resource: resource)
                            }
                            .onDelete { offsets in
                                let ids = offsets.map { vm.resources[$0].id }
                                Task {
                                    for id in ids {
                                        await vm.removeResource(id: id)
                                    }
                                }
                            }
                        }
                        Button {
                            isAddingResource = true
                        } label: {
                            Label("Add Resource", systemImage: "plus")
                        }
                        .disabled(vm.isMutatingResource)
                    } header: {
                        MarkdownText("Resources (\(vm.resources.count))")
                    }

                    Section {
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
                    } header: {
                        MarkdownText("Issues (\(vm.issues.count))")
                    }

                    if let error = vm.errorMessage {
                        Section {
                            ErrorRetryView(message: error) {
                                Task { await vm.load() }
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .markdownNavigationTitle(project.name)
        .sheet(isPresented: $isAddingResource) {
            if let vm = viewModel {
                ProjectResourceAddSheet(
                    repos: authSession.currentWorkspace?.repos ?? [],
                    attachedURLs: attachedResourceURLs(vm.resources),
                    isSubmitting: vm.isMutatingResource
                ) { url in
                    await vm.attachGitHubResource(url: url)
                    if vm.errorMessage == nil {
                        isAddingResource = false
                    }
                }
            }
        }
        .toolbar {
            if let pinViewModel {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await pinViewModel.toggle() }
                    } label: {
                        Label(
                            pinViewModel.isPinned ? "Unpin Project" : "Pin Project",
                            systemImage: pinViewModel.isPinned ? "pin.slash" : "pin"
                        )
                    }
                    .disabled(pinViewModel.isLoading)
                    .accessibilityIdentifier("ProjectDetailPinButton")
                }
            }
        }
        .refreshable { await viewModel?.load() }
        .task {
            if viewModel == nil {
                let vm = ProjectDetailViewModel(project: project, api: api, authSession: authSession)
                let pinVM = PinToggleViewModel(itemType: .project, itemId: project.id, api: api, authSession: authSession)
                viewModel = vm
                pinViewModel = pinVM
                await pinVM.load()
                await vm.load()
            }
        }
    }

    private var leadText: String? {
        guard let type = viewModel?.project.leadType,
              let id = viewModel?.project.leadId,
              !type.isEmpty,
              !id.isEmpty
        else { return nil }
        return "\(type.capitalized) \(id.prefix(8))"
    }

    private func attachedResourceURLs(_ resources: [ProjectResource]) -> Set<String> {
        Set(resources.compactMap { resource in
            guard resource.resourceType == "github_repo",
                  case .string(let url)? = resource.resourceRef["url"],
                  !url.isEmpty
            else { return nil }
            return url
        })
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
                MarkdownText(resource.displayTitle)
                    .font(.body)
                    .lineLimit(1)
                MarkdownText(resource.resourceType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ProjectResourceAddSheet: View {
    let repos: [WorkspaceRepo]
    let attachedURLs: Set<String>
    let isSubmitting: Bool
    let onSubmit: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customURL = ""

    private var trimmedCustomURL: String {
        customURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                if !repos.isEmpty {
                    Section("Workspace Repositories") {
                        ForEach(repos, id: \.url) { repo in
                            let isAttached = attachedURLs.contains(repo.url)
                            Button {
                                Task { await onSubmit(repo.url) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.badge.gearshape")
                                        .foregroundStyle(.secondary)
                                    MarkdownText(repo.url)
                                        .lineLimit(1)
                                    Spacer()
                                    if isAttached {
                                        Text("Attached")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(isAttached || isSubmitting)
                        }
                    }
                }

                Section("Custom GitHub URL") {
                    TextField("https://github.com/owner/repo", text: $customURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button {
                        let url = trimmedCustomURL
                        Task { await onSubmit(url) }
                    } label: {
                        Label("Add Custom URL", systemImage: "plus")
                    }
                    .disabled(trimmedCustomURL.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Add Resource")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
#endif
