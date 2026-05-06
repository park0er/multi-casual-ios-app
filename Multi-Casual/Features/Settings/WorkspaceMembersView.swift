#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct WorkspaceMembersView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: WorkspaceMembersViewModel?
    @State private var showInviteSheet = false
    @State private var editingMember: WorkspaceMember?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    membersSection(vm)
                    invitationsSection(vm)

                    if let errorMessage = vm.errorMessage {
                        Section {
                            ErrorRetryView(message: errorMessage) {
                                Task { await vm.load() }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await vm.load() }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showInviteSheet = true
                        } label: {
                            Label("Invite Member", systemImage: "person.badge.plus")
                        }
                        .accessibilityIdentifier("MembersInviteButton")
                    }
                }
                .sheet(isPresented: $showInviteSheet) {
                    MemberInviteSheet(viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
                .sheet(item: $editingMember) { member in
                    MemberRoleSheet(member: member, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Members")
        .onAppear {
            if viewModel == nil {
                let vm = WorkspaceMembersViewModel(api: api, authSession: authSession)
                viewModel = vm
                Task { await vm.load() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            Task { await viewModel?.load() }
        }
    }

    @ViewBuilder
    private func membersSection(_ vm: WorkspaceMembersViewModel) -> some View {
        Section("Members") {
            if vm.isLoading && vm.members.isEmpty {
                ProgressView()
            } else if vm.members.isEmpty && vm.errorMessage == nil {
                ContentUnavailableView("No Members", systemImage: "person.2", description: Text("This workspace has no members yet."))
            } else {
                ForEach(vm.members) { member in
                    Button {
                        editingMember = member
                    } label: {
                        MemberRow(member: member)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await vm.removeMember(id: member.id) }
                        } label: {
                            Label("Remove", systemImage: "person.crop.circle.badge.minus")
                        }
                        .disabled(vm.isMutating || member.role == "owner")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func invitationsSection(_ vm: WorkspaceMembersViewModel) -> some View {
        Section("Invitations") {
            if vm.invitations.isEmpty {
                MarkdownText("No pending invitations.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.invitations) { invitation in
                    InvitationRow(invitation: invitation)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await vm.revokeInvitation(id: invitation.id) }
                            } label: {
                                Label("Revoke", systemImage: "xmark.circle")
                            }
                            .disabled(vm.isMutating)
                        }
                }
            }
        }
    }
}

private struct MemberRow: View {
    let member: WorkspaceMember

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.circle.fill")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                MarkdownText(member.name)
                    .font(.body.weight(.semibold))
                MarkdownText(member.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MarkdownText(member.role.capitalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct InvitationRow: View {
    let invitation: Invitation

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "envelope.badge")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                MarkdownText(invitation.email)
                    .font(.body.weight(.semibold))
                HStack(spacing: 8) {
                    MarkdownText(invitation.role.capitalized)
                    MarkdownText(invitation.status.capitalized)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MemberInviteSheet: View {
    let viewModel: WorkspaceMembersViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var role = "member"

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .accessibilityIdentifier("MemberInviteEmailField")
                    Picker("Role", selection: $role) {
                        ForEach(WorkspaceMembersViewModel.roles, id: \.self) { role in
                            MarkdownText(role.capitalized).tag(role)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        MarkdownText(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Invite Member")
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
                            Text("Invite")
                        }
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isMutating)
                }
            }
        }
    }

    private func submit() async {
        let invitation = await viewModel.inviteMember(email: email, role: role)
        if invitation != nil {
            dismiss()
        }
    }
}

private struct MemberRoleSheet: View {
    let member: WorkspaceMember
    let viewModel: WorkspaceMembersViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var role: String

    init(member: WorkspaceMember, viewModel: WorkspaceMembersViewModel) {
        self.member = member
        self.viewModel = viewModel
        _role = State(initialValue: member.role)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Member") {
                    MemberRow(member: member)
                    Picker("Role", selection: $role) {
                        ForEach(WorkspaceMembersViewModel.roles, id: \.self) { role in
                            MarkdownText(role.capitalized).tag(role)
                        }
                    }
                    .disabled(member.role == "owner")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        MarkdownText(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Member")
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
                            Text("Save")
                        }
                    }
                    .disabled(viewModel.isMutating || member.role == "owner")
                }
            }
        }
    }

    private func submit() async {
        let updated = await viewModel.updateMemberRole(memberId: member.id, role: role)
        if updated != nil {
            dismiss()
        }
    }
}
#endif
