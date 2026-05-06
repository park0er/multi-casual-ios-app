import Foundation
import Observation

@Observable
@MainActor
public final class NotificationPreferencesViewModel {
    public var preferences = NotificationPreferences()
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
            errorMessage = "Pick a workspace before editing notification preferences."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await api.getNotificationPreferences(workspaceId: workspaceId)
            preferences = response.preferences
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func value(for group: NotificationPreferenceGroup) -> NotificationPreferenceValue {
        preferences.value(for: group)
    }

    public func set(_ group: NotificationPreferenceGroup, enabled: Bool) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before editing notification preferences."
            return
        }
        guard !isMutating else { return }

        var nextPreferences = preferences
        nextPreferences.set(group, to: enabled ? nil : .muted)

        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            let response = try await api.updateNotificationPreferences(nextPreferences, workspaceId: workspaceId)
            preferences = response.preferences
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
