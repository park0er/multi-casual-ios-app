import Foundation
import Observation

@Observable
@MainActor
public final class LabelsViewModel {
    public static let defaultColors = [
        "#ef4444", "#f97316", "#eab308", "#22c55e",
        "#06b6d4", "#3b82f6", "#8b5cf6", "#ec4899",
        "#64748b",
    ]

    public var labels: [IssueLabel] = []
    public var isLoading = false
    public var isMutating = false
    public var errorMessage: String?

    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api
        self.authSession = authSession
    }

    public func load() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing labels."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            labels = try await api.listLabels(workspaceId: workspaceId).labels.sorted(by: labelSort)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createLabel(name: String, color: String) async -> IssueLabel? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing labels."
            return nil
        }
        guard let normalized = normalizedInput(name: name, color: color) else { return nil }
        return await mutate {
            try await api.createLabel(name: normalized.name, color: normalized.color, workspaceId: workspaceId)
        }
    }

    public func updateLabel(id: String, name: String, color: String) async -> IssueLabel? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing labels."
            return nil
        }
        guard let normalized = normalizedInput(name: name, color: color) else { return nil }
        return await mutate {
            try await api.updateLabel(id: id, name: normalized.name, color: normalized.color, workspaceId: workspaceId)
        }
    }

    public func deleteLabel(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing labels."
            return
        }
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            try await api.deleteLabel(id: id, workspaceId: workspaceId)
            labels.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func isValidColor(_ color: String) -> Bool {
        normalizedColor(color) != nil
    }

    private func normalizedInput(name: String, color: String) -> (name: String, color: String)? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter a label name."
            return nil
        }
        guard let normalizedColor = normalizedColor(color) else {
            errorMessage = "Enter a 6 digit hex color."
            return nil
        }
        return (trimmedName, normalizedColor)
    }

    private func normalizedColor(_ color: String) -> String? {
        let trimmed = color.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard raw.count == 6, raw.allSatisfy(\.isHexDigit) else { return nil }
        return "#\(raw.lowercased())"
    }

    private func mutate(_ operation: () async throws -> IssueLabel) async -> IssueLabel? {
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            let label = try await operation()
            upsert(label)
            return label
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func upsert(_ label: IssueLabel) {
        if let index = labels.firstIndex(where: { $0.id == label.id }) {
            labels[index] = label
        } else {
            labels.append(label)
        }
        labels.sort(by: labelSort)
    }

    private func labelSort(_ lhs: IssueLabel, _ rhs: IssueLabel) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
