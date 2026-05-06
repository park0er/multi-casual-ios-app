import Foundation
import Observation

@Observable
@MainActor
public final class FeedbackViewModel {
    public var isSubmitting = false
    public var errorMessage: String?
    public var successMessage: String?
    public var lastFeedbackId: String?

    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api
        self.authSession = authSession
    }

    public func submit(message: String, url: String?) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before sending feedback."
            successMessage = nil
            return
        }

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            errorMessage = "Feedback message is required."
            successMessage = nil
            return
        }

        let trimmedURL = url?.trimmingCharacters(in: .whitespacesAndNewlines)
        let feedbackURL = trimmedURL?.isEmpty == false ? trimmedURL : nil
        guard !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        defer { isSubmitting = false }

        do {
            let response = try await api.createFeedback(
                message: trimmedMessage,
                url: feedbackURL,
                workspaceId: workspaceId
            )
            lastFeedbackId = response.id
            successMessage = "Feedback sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
