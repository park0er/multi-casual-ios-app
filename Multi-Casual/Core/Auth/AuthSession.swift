import Foundation

// @Observable and @MainActor require Swift concurrency + Observation framework.
// On macOS (swift test), these are available. On iOS they're native.
// We use a class with manual observation for macOS compatibility.

#if canImport(Observation)
import Observation

@Observable
@MainActor
public final class AuthSession {
    public var currentUser: User?
    public var currentWorkspace: Workspace?
    public var isLoading = true

    public var isAuthenticated: Bool { currentUser != nil }

    private let keychain: KeychainStore

    public init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    // nonisolated so APIClient can fetch the bearer token off the main actor
    // on every request path. Keychain access is thread-safe (SecItemCopyMatching).
    nonisolated public func token() -> String? {
        try? keychain.load()
    }

    public func login(user: User, workspace: Workspace?, token: String) throws {
        try keychain.save(token)
        currentUser = user
        currentWorkspace = workspace
        isLoading = false
    }

    public func logout() {
        try? keychain.delete()
        currentUser = nil
        currentWorkspace = nil
    }

    public func restore(using api: APIClient, preferredWorkspaceId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        guard (try? keychain.load()) != nil else { return }
        do {
            let user = try await api.getMe()
            let workspaces = try await api.listWorkspaces()
            currentUser = user
            currentWorkspace = Self.preferredWorkspace(from: workspaces, preferredId: preferredWorkspaceId)
        } catch {
            try? keychain.delete()
        }
    }
}
#else
// Fallback for environments without Observation framework
@MainActor
public final class AuthSession {
    public var currentUser: User?
    public var currentWorkspace: Workspace?
    public var isLoading = true
    public var isAuthenticated: Bool { currentUser != nil }

    private let keychain: KeychainStore

    public init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    nonisolated public func token() -> String? { try? keychain.load() }

    public func login(user: User, workspace: Workspace?, token: String) throws {
        try keychain.save(token)
        currentUser = user
        currentWorkspace = workspace
        isLoading = false
    }

    public func logout() {
        try? keychain.delete()
        currentUser = nil
        currentWorkspace = nil
    }

    public func restore(using api: APIClient, preferredWorkspaceId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        guard (try? keychain.load()) != nil else { return }
        do {
            let user = try await api.getMe()
            let workspaces = try await api.listWorkspaces()
            currentUser = user
            currentWorkspace = Self.preferredWorkspace(from: workspaces, preferredId: preferredWorkspaceId)
        } catch {
            try? keychain.delete()
        }
    }
}
#endif

public extension AuthSession {
    static func preferredWorkspace(from workspaces: [Workspace], preferredId: String?) -> Workspace? {
        if let preferredId, let workspace = workspaces.first(where: { $0.id == preferredId }) {
            return workspace
        }
        return workspaces.first
    }

    #if DEBUG
    @MainActor
    func installDebugToken(_ token: String?) throws {
        guard let token, !token.isEmpty else { return }
        try keychain.save(token)
    }
    #endif
}
