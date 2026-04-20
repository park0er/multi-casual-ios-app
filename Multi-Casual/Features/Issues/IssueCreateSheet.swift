#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct IssueCreateSheet: View {
    @Environment(AuthSession.self) private var authSession
    @Environment(\.dismiss) private var dismiss
    let onCreated: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(onCreated: @escaping () -> Void) { self.onCreated = onCreated }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Title") { TextField("Issue title", text: $title) }
                Section("Description (optional)") {
                    TextEditor(text: $description).frame(minHeight: 120)
                }
                if let error = errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle("New Issue").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await submit() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
        }
    }

    private func submit() async {
        guard let wsId = authSession.currentWorkspace?.id else { return }
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do {
            _ = try await APIClient(authSession: authSession).createIssue(
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.isEmpty ? nil : description,
                workspaceId: wsId
            )
            onCreated()
        } catch { errorMessage = "Failed to create issue. Please try again." }
    }
}
#endif
