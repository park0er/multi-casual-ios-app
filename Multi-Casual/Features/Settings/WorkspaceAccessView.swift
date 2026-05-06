#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct WorkspaceAccessView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: WorkspaceAccessViewModel?
    @State private var showCreateSheet = false
    @State private var pendingDestructiveAction: WorkspaceDestructiveAction?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    Section("Workspaces") {
                        ForEach(authSession.workspaces) { workspace in
                            Button {
                                authSession.setWorkspace(workspace)
                            } label: {
                                WorkspaceAccessRow(
                                    title: workspace.name,
                                    subtitle: workspace.slug,
                                    isSelected: workspace.id == authSession.currentWorkspace?.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    invitationsSection(vm)
                    destructiveSection(vm)

                    if let errorMessage = vm.errorMessage {
                        Section {
                            ErrorRetryView(message: errorMessage) {
                                Task { await vm.load() }
                            }
                        }
                    }
                }
                .refreshable { await vm.load() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("New Workspace", systemImage: "plus")
                        }
                        .accessibilityIdentifier("WorkspaceCreateButton")
                    }
                }
                .sheet(isPresented: $showCreateSheet) {
                    WorkspaceCreateSheet(viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
                .confirmationDialog(
                    pendingDestructiveAction?.title ?? "",
                    isPresented: Binding(
                        get: { pendingDestructiveAction != nil },
                        set: { if !$0 { pendingDestructiveAction = nil } }
                    ),
                    titleVisibility: .visible
                ) {
                    if let action = pendingDestructiveAction {
                        Button(action.confirmTitle, role: .destructive) {
                            Task { await perform(action, vm: vm) }
                        }
                    }
                    Button("Cancel", role: .cancel) { pendingDestructiveAction = nil }
                } message: {
                    if let action = pendingDestructiveAction {
                        MarkdownText(action.message)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Workspaces")
        .onAppear {
            if viewModel == nil {
                let vm = WorkspaceAccessViewModel(api: api, authSession: authSession)
                viewModel = vm
                Task { await vm.load() }
            }
        }
    }

    @ViewBuilder
    private func invitationsSection(_ vm: WorkspaceAccessViewModel) -> some View {
        Section("My Invitations") {
            if vm.isLoading && vm.invitations.isEmpty {
                ProgressView()
            } else if vm.invitations.isEmpty {
                MarkdownText("No pending invitations.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.invitations) { invitation in
                    InvitationAccessRow(invitation: invitation)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await vm.declineInvitation(id: invitation.id) }
                            } label: {
                                Label("Decline", systemImage: "xmark.circle")
                            }
                            .disabled(vm.isMutating)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task { await vm.acceptInvitation(id: invitation.id) }
                            } label: {
                                Label("Accept", systemImage: "checkmark.circle")
                            }
                            .tint(.green)
                            .disabled(vm.isMutating)
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func destructiveSection(_ vm: WorkspaceAccessViewModel) -> some View {
        if let workspace = authSession.currentWorkspace {
            Section("Current Workspace") {
                Button(role: .destructive) {
                    pendingDestructiveAction = .leave(workspace)
                } label: {
                    Label("Leave Workspace", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .disabled(vm.isMutating || authSession.workspaces.count <= 1)

                Button(role: .destructive) {
                    pendingDestructiveAction = .delete(workspace)
                } label: {
                    Label("Delete Workspace", systemImage: "trash")
                }
                .disabled(vm.isMutating)
            }
        }
    }

    private func perform(_ action: WorkspaceDestructiveAction, vm: WorkspaceAccessViewModel) async {
        pendingDestructiveAction = nil
        switch action {
        case .leave(let workspace):
            await vm.leaveWorkspace(id: workspace.id)
        case .delete(let workspace):
            await vm.deleteWorkspace(id: workspace.id)
        }
    }
}

private struct WorkspaceAccessRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 3) {
                MarkdownText(title).font(.body.weight(.semibold))
                MarkdownText(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct InvitationAccessRow: View {
    let invitation: Invitation

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "envelope.open")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                MarkdownText(invitation.workspaceName ?? "Workspace")
                    .font(.body.weight(.semibold))
                MarkdownText("Invited by \(invitation.inviterName ?? invitation.inviterEmail ?? "someone")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                MarkdownText(invitation.role.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WorkspaceCreateSheet: View {
    let viewModel: WorkspaceAccessViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var slug = ""
    @State private var description = ""
    @State private var context = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("WorkspaceCreateNameField")
                    TextField("Slug", text: $slug)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("WorkspaceCreateSlugField")
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 90)
                        .accessibilityIdentifier("WorkspaceCreateDescriptionField")
                }

                Section("Context") {
                    TextEditor(text: $context)
                        .frame(minHeight: 120)
                        .accessibilityIdentifier("WorkspaceCreateContextField")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        MarkdownText(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if viewModel.isMutating {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(
                        viewModel.isMutating ||
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }

    private func submit() async {
        let workspace = await viewModel.createWorkspace(
            name: name,
            slug: slug,
            description: description,
            context: context
        )
        if workspace != nil {
            dismiss()
        }
    }
}

private enum WorkspaceDestructiveAction: Identifiable {
    case leave(Workspace)
    case delete(Workspace)

    var id: String {
        switch self {
        case .leave(let workspace): "leave-\(workspace.id)"
        case .delete(let workspace): "delete-\(workspace.id)"
        }
    }

    var title: String {
        switch self {
        case .leave(let workspace): "Leave \(workspace.name)?"
        case .delete(let workspace): "Delete \(workspace.name)?"
        }
    }

    var message: String {
        switch self {
        case .leave:
            "You will lose access to this workspace unless another member invites you again."
        case .delete:
            "This permanently deletes the workspace and its data."
        }
    }

    var confirmTitle: String {
        switch self {
        case .leave: "Leave Workspace"
        case .delete: "Delete Workspace"
        }
    }
}
#endif
