import Foundation
import Observation

@Observable
@MainActor
public final class PinToggleViewModel {
    public let itemType: PinnedItemType
    public let itemId: String
    public var isPinned = false
    public var isLoading = false
    public var errorMessage: String?

    private let api: APIClient
    private let authSession: AuthSession

    public init(itemType: PinnedItemType, itemId: String, api: APIClient, authSession: AuthSession) {
        self.itemType = itemType
        self.itemId = itemId
        self.api = api
        self.authSession = authSession
    }

    public func load() async {
        guard let workspaceSlug = authSession.currentWorkspace?.slug else {
            errorMessage = "Pick a workspace before loading pins."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let pins = try await api.listPins(workspaceSlug: workspaceSlug)
            isPinned = pins.contains { $0.itemType == itemType && $0.itemId == itemId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func toggle() async {
        guard !isLoading else { return }
        guard let workspaceSlug = authSession.currentWorkspace?.slug else {
            errorMessage = "Pick a workspace before changing pins."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if isPinned {
                try await api.deletePin(itemType: itemType, itemId: itemId, workspaceSlug: workspaceSlug)
                isPinned = false
            } else {
                _ = try await api.createPin(itemType: itemType, itemId: itemId, workspaceSlug: workspaceSlug)
                isPinned = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
