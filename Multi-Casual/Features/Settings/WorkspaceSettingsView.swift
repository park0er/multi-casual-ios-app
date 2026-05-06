#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct WorkspaceSettingsView: View {
    @Environment(APIClient.self) private var api
    @Environment(AuthSession.self) private var authSession
    @State private var viewModel: WorkspaceSettingsViewModel?

    public init() {}

    public var body: some View {
        Group {
            if let vm = viewModel {
                Form {
                    Section("Identity") {
                        TextField("Name", text: Bindable(vm).name)
                            .accessibilityIdentifier("WorkspaceNameField")
                        LabeledContent("Slug") {
                            MarkdownText(authSession.currentWorkspace?.slug ?? "")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Description") {
                        TextEditor(text: Bindable(vm).description)
                            .frame(minHeight: 90)
                            .accessibilityIdentifier("WorkspaceDescriptionField")
                    }

                    Section("Context") {
                        TextEditor(text: Bindable(vm).context)
                            .frame(minHeight: 150)
                            .accessibilityIdentifier("WorkspaceContextField")
                    }

                    Section("GitHub Repos") {
                        TextEditor(text: Bindable(vm).repoText)
                            .frame(minHeight: 120)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("WorkspaceReposField")
                        MarkdownText("One repository URL per line.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage = vm.errorMessage {
                        Section {
                            ErrorRetryView(message: errorMessage) {
                                Task { await vm.load() }
                            }
                        }
                    }
                }
                .disabled(vm.isLoading)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await vm.save() }
                        } label: {
                            if vm.isSaving {
                                ProgressView()
                            } else {
                                Text("Save")
                            }
                        }
                        .disabled(vm.isSaving || vm.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .refreshable { await vm.load() }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Workspace")
        .onAppear {
            if viewModel == nil {
                let vm = WorkspaceSettingsViewModel(api: api, authSession: authSession)
                viewModel = vm
                Task { await vm.load() }
            }
        }
        .onChange(of: authSession.currentWorkspace?.id) { _, _ in
            Task { await viewModel?.load() }
        }
    }
}
#endif
