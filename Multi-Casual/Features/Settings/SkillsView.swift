#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct SkillsView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: SkillsViewModel?
    @State private var showCreateSheet = false
    @State private var showImportSheet = false

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
                            NavigationLink {
                                SkillDetailView(skill: skill, viewModel: vm)
                            } label: {
                                SkillRow(skill: skill)
                            }
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
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Skills")
        .onAppear {
            if viewModel == nil {
                let vm = SkillsViewModel(api: api, authSession: authSession)
                viewModel = vm
                Task { await vm.load() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            Task { await viewModel?.load() }
        }
    }
}

private struct SkillDetailView: View {
    let skill: Skill
    let viewModel: SkillsViewModel

    @State private var detail: Skill
    @State private var selectedFilePath: String?
    @State private var showEditSheet = false

    init(skill: Skill, viewModel: SkillsViewModel) {
        self.skill = skill
        self.viewModel = viewModel
        _detail = State(initialValue: skill)
        _selectedFilePath = State(initialValue: Self.defaultSelectedPath(for: skill))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if viewModel.isLoadingSkillDetail && detail.files.isEmpty && detail.content.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }

                if let errorMessage = viewModel.skillDetailError {
                    ErrorRetryView(message: errorMessage) {
                        Task { await reload() }
                    }
                }

                skillMarkdownSection
                fileTreeSection
                selectedFileSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(detail.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit Skill", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            SkillFormSheet(skill: detail, viewModel: viewModel)
                .presentationDragIndicator(.visible)
        }
        .task(id: skill.id) {
            await reload()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownText(detail.name)
                .font(.title2.weight(.semibold))

            if !detail.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MarkdownText(detail.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                MarkdownIconLabel("\(detail.files.count) files", systemImage: "doc.on.doc")
                if let updatedAt = detail.updatedAt {
                    MarkdownIconLabel(
                        updatedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "clock"
                    )
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var skillMarkdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownText("SKILL.md")
                .font(.headline)

            if primaryMarkdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MarkdownText("No SKILL.md content returned.")
                    .foregroundStyle(.secondary)
            } else {
                MarkdownText(primaryMarkdown)
                    .textSelection(.enabled)
            }
        }
    }

    private var fileTreeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MarkdownText("Files")
                .font(.headline)

            let tree = SkillFileTreeNode.build(from: detail.files)
            if tree.isEmpty {
                MarkdownText("No files returned.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(tree) { node in
                        SkillFileTreeNodeRow(
                            node: node,
                            selectedPath: $selectedFilePath,
                            depth: 0
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var selectedFileSection: some View {
        if let selectedFile, selectedFile.path != preferredSkillFile?.path {
            VStack(alignment: .leading, spacing: 8) {
                MarkdownText(selectedFile.path)
                    .font(.headline)

                if selectedFile.path.lowercased().hasSuffix(".md") {
                    MarkdownText(selectedFile.content ?? "")
                        .textSelection(.enabled)
                } else {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(selectedFile.content ?? "")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(10)
                    }
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var primaryMarkdown: String {
        if !detail.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return detail.content
        }
        return preferredSkillFile?.content ?? ""
    }

    private var selectedFile: SkillFile? {
        if let selectedFilePath,
           let file = detail.files.first(where: { $0.path == selectedFilePath }) {
            return file
        }
        return preferredSkillFile
    }

    private var preferredSkillFile: SkillFile? {
        detail.files.first { $0.path.split(separator: "/").last?.lowercased() == "skill.md" }
    }

    private func reload() async {
        if let loaded = await viewModel.loadSkillDetail(id: skill.id) {
            detail = loaded
            let selectedPathStillExists = selectedFilePath.map { path in
                loaded.files.contains { $0.path == path }
            } ?? false
            if !selectedPathStillExists {
                selectedFilePath = Self.defaultSelectedPath(for: loaded)
            }
        }
    }

    private static func defaultSelectedPath(for skill: Skill) -> String? {
        skill.files.first { $0.path.split(separator: "/").last?.lowercased() == "skill.md" }?.path
            ?? skill.files.first?.path
    }
}

private struct SkillFileTreeNodeRow: View {
    let node: SkillFileTreeNode
    @Binding var selectedPath: String?
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if node.isDirectory {
                row(icon: "folder", title: node.name, isSelected: false)
                ForEach(node.children) { child in
                    SkillFileTreeNodeRow(
                        node: child,
                        selectedPath: $selectedPath,
                        depth: depth + 1
                    )
                }
            } else {
                Button {
                    selectedPath = node.path
                } label: {
                    row(icon: iconName, title: node.name, isSelected: selectedPath == node.path)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var iconName: String {
        node.path.lowercased().hasSuffix(".md") ? "doc.richtext" : "doc.text"
    }

    private func row(icon: String, title: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Spacer()
                .frame(width: CGFloat(depth) * 16)
            Image(systemName: icon)
                .foregroundStyle(node.isDirectory ? Color.accentColor : Color.secondary)
                .frame(width: 18)
            MarkdownText(title)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
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
