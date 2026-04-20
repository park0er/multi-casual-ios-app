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

    public func token() -> String? {
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

    public func restore(using api: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        guard (try? keychain.load()) != nil else { return }
        do {
            let user = try await api.getMe()
            let workspaces = try await api.listWorkspaces()
            currentUser = user
            currentWorkspace = workspaces.first
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

    public func token() -> String? { try? keychain.load() }

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

    public func restore(using api: APIClient) async {
        isLoading = true
        defer { isLoading = false }
        guard (try? keychain.load()) != nil else { return }
        do {
            let user = try await api.getMe()
            let workspaces = try await api.listWorkspaces()
            currentUser = user
            currentWorkspace = workspaces.first
        } catch {
            try? keychain.delete()
        }
    }
}
#endif
