#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct LabelsView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: LabelsViewModel?
    @State private var showCreateSheet = false
    @State private var editingLabel: IssueLabel?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                List {
                    if vm.isLoading && vm.labels.isEmpty {
                        ProgressView()
                    } else if vm.labels.isEmpty && vm.errorMessage == nil {
                        ContentUnavailableView("No Labels", systemImage: "tag", description: Text("This workspace has no labels yet."))
                    } else {
                        ForEach(vm.labels) { label in
                            Button {
                                editingLabel = label
                            } label: {
                                LabelRow(label: label)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await vm.deleteLabel(id: label.id) }
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
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("New Label", systemImage: "plus")
                        }
                        .accessibilityIdentifier("LabelsNewButton")
                    }
                }
                .sheet(isPresented: $showCreateSheet) {
                    LabelFormSheet(label: nil, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
                .sheet(item: $editingLabel) { label in
                    LabelFormSheet(label: label, viewModel: vm)
                        .presentationDragIndicator(.visible)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Labels")
        .onAppear {
            if viewModel == nil {
                let vm = LabelsViewModel(api: api, authSession: authSession)
                viewModel = vm
                Task { await vm.load() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            Task { await viewModel?.load() }
        }
    }
}

private struct LabelRow: View {
    let label: IssueLabel

    var body: some View {
        HStack(spacing: 12) {
            LabelSwatch(color: label.color)
            VStack(alignment: .leading, spacing: 4) {
                MarkdownText(label.name)
                    .font(.body.weight(.semibold))
                MarkdownText(label.color.lowercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct LabelSwatch: View {
    let color: String

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(hex: color) ?? .secondary)
            .frame(width: 26, height: 26)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.quaternary, lineWidth: 1)
            )
            .accessibilityLabel("Label color \(color)")
    }
}

private struct LabelFormSheet: View {
    let label: IssueLabel?
    let viewModel: LabelsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: String

    init(label: IssueLabel?, viewModel: LabelsViewModel) {
        self.label = label
        self.viewModel = viewModel
        _name = State(initialValue: label?.name ?? "")
        _color = State(initialValue: label?.color ?? LabelsViewModel.defaultColors[0])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("LabelNameField")
                    HStack(spacing: 12) {
                        LabelSwatch(color: color)
                        TextField("#ef4444", text: $color)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("LabelColorField")
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 38), spacing: 10)], spacing: 10) {
                        ForEach(LabelsViewModel.defaultColors, id: \.self) { option in
                            Button {
                                color = option
                            } label: {
                                LabelSwatch(color: option)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(color.caseInsensitiveCompare(option) == .orderedSame ? Color.accentColor : .clear, lineWidth: 3)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use color \(option)")
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Preview") {
                    HStack(spacing: 12) {
                        LabelSwatch(color: color)
                        MarkdownText(name.isEmpty ? "Label name" : name)
                            .font(.body.weight(.semibold))
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        MarkdownText(errorMessage).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(label == nil ? "New Label" : "Edit Label")
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
                    .accessibilityIdentifier("LabelSaveButton")
                }
            }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        viewModel.isValidColor(color) &&
        !viewModel.isMutating
    }

    private func submit() async {
        let saved: IssueLabel?
        if let label {
            saved = await viewModel.updateLabel(id: label.id, name: name, color: color)
        } else {
            saved = await viewModel.createLabel(name: name, color: color)
        }

        if saved != nil {
            dismiss()
        }
    }
}

#endif
