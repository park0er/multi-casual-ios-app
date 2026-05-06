import Foundation
import Observation

@Observable
@MainActor
public final class PersonalAccessTokensViewModel {
    public var tokens: [PersonalAccessToken] = []
    public var newToken: String?
    public var isLoading = false
    public var isCreating = false
    public var revokingTokenId: String?
    public var errorMessage: String?

    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            tokens = try await api.listPersonalAccessTokens()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createToken(name: String, expiresInDays: Int?) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Token name is required."
            return
        }
        guard !isCreating else { return }

        isCreating = true
        errorMessage = nil
        defer { isCreating = false }

        do {
            let created = try await api.createPersonalAccessToken(name: trimmedName, expiresInDays: expiresInDays)
            newToken = created.token
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func revokeToken(id: String) async {
        guard revokingTokenId == nil else { return }
        revokingTokenId = id
        errorMessage = nil
        defer { revokingTokenId = nil }

        do {
            try await api.revokePersonalAccessToken(id: id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func clearNewToken() {
        newToken = nil
    }
}
