#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SkillsView: View {
    @Environment(APIClient.self) private var api
    @State private var viewModel: SkillsViewModel?
    @State private var showCreateSheet = false
    @State private var showImportSheet = false
    @State private var editingSkill: Skill?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.isLoading && vm.skills.isEmpty {
                        ProgressView()
                    } else if vm.skills.isEmpty && vm.errorMessage == nil {
                        ContentUnavailableView("No Skills", systemImage: "sparkles", description: Text("This workspace has no skills yet."))
                    } else {
                        ForEach(vm.skills) { skill in
                            Button {
                                editingSkill = skill
                            } label: {
                                SkillRow(skill: skill)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteSkill(id: skill.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(vm.isMutating)
                            }
                        }
                    }

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
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showImportSheet = true
                        } label: {
                            Label("Import Skill", systemImage: "square.and.arrow.down")
                        }
                        .accessibilityIdentifier("SkillsImportButton")

                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("New Skill", systemImage: "plus")
                        }
                        .accessibilityIdentifier("SkillsNewButton")
                    }
                }
                .sheet(isPresented: $showCreateSheet) {
                    SkillFormSheet(skill: nil, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showImportSheet) {
                    SkillImportSheet(viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
                .sheet(item: $editingSkill) { skill in
                    SkillFormSheet(skill: skill, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Skills")
        .onAppear {
            if viewModel == nil {
                let vm = SkillsViewModel(api: api)
                viewModel = vm
                Task { await vm.load() }
            }
        }
    }
}

private struct SkillRow: View {
    let skill: Skill

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                MarkdownText(skill.name)
                    .font(.body.weight(.semibold))
                if !skill.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MarkdownText(skill.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !skill.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    MarkdownText(skill.content)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SkillFormSheet: View {
    let skill: Skill?
    let viewModel: SkillsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var content: String

    init(skill: Skill?, viewModel: SkillsViewModel) {
        self.skill = skill
        self.viewModel = viewModel
        _name = State(initialValue: skill?.name ?? "")
        _description = State(initialValue: skill?.description ?? "")
        _content = State(initialValue: skill?.content ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Skill") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("SkillNameField")
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .accessibilityIdentifier("SkillDescriptionEditor")
                    TextEditor(text: $content)
                        .frame(minHeight: 180)
                        .accessibilityIdentifier("SkillContentEditor")
                }

                Section("Preview") {
                    MarkdownText(content.isEmpty ? description : content)
                        .font(.body)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        MarkdownText(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(skill == nil ? "New Skill" : "Edit Skill")
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
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("SkillSaveButton")
                }
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.isMutating
    }

    private func submit() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        let saved: Skill?
        if let skill {
            saved = await viewModel.updateSkill(
                id: skill.id,
                name: trimmedName,
                description: trimmedDescription,
                content: trimmedContent
            )
        } else {
            saved = await viewModel.createSkill(
                name: trimmedName,
                description: trimmedDescription,
                content: trimmedContent
            )
        }

        if saved != nil {
            dismiss()
        }
    }
}

private struct SkillImportSheet: View {
    let viewModel: SkillsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var url = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Import") {
                    TextField("Repository or skill URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .accessibilityIdentifier("SkillImportURLField")
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        MarkdownText(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Import Skill")
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
                            Text("Import")
                        }
                    }
                    .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isMutating)
                    .accessibilityIdentifier("SkillImportSubmitButton")
                }
            }
        }
    }

    private func submit() async {
        let imported = await viewModel.importSkill(url: url.trimmingCharacters(in: .whitespacesAndNewlines))
        if imported != nil {
            dismiss()
        }
    }
}
#endif
