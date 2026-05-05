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
    public var workspaces: [Workspace] = []
    public var isLoading = true

    public var isAuthenticated: Bool { currentUser != nil }
    public var preferredWorkspaceId: String? {
        userDefaults.string(forKey: Self.selectedWorkspaceDefaultsKey)
    }

    private let keychain: KeychainStore
    private let userDefaults: UserDefaults

    static let selectedWorkspaceDefaultsKey = "selected_workspace_id"

    public init(keychain: KeychainStore = KeychainStore(), userDefaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.userDefaults = userDefaults
    }

    // nonisolated so APIClient can fetch the bearer token off the main actor
    // on every request path. Keychain access is thread-safe (SecItemCopyMatching).
    nonisolated public func token() -> String? {
        try? keychain.load()
    }

    public func login(user: User, workspace: Workspace?, token: String) throws {
        try login(user: user, workspaces: workspace.map { [$0] } ?? [], token: token)
    }

    public func login(user: User, workspaces: [Workspace], token: String) throws {
        try keychain.save(token)
        currentUser = user
        self.workspaces = workspaces
        if let workspace = Self.preferredWorkspace(from: workspaces, preferredId: preferredWorkspaceId) {
            setWorkspace(workspace)
        } else {
            currentWorkspace = nil
            userDefaults.removeObject(forKey: Self.selectedWorkspaceDefaultsKey)
        }
        isLoading = false
    }

    public func logout() {
        try? keychain.delete()
        userDefaults.removeObject(forKey: Self.selectedWorkspaceDefaultsKey)
        currentUser = nil
        currentWorkspace = nil
        workspaces = []
    }

    public func restore(using api: APIClient, preferredWorkspaceId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        guard (try? keychain.load()) != nil else { return }
        do {
            let user = try await api.getMe()
            let fetchedWorkspaces = try await api.listWorkspaces()
            currentUser = user
            workspaces = fetchedWorkspaces
            currentWorkspace = Self.preferredWorkspace(
                from: fetchedWorkspaces,
                preferredId: preferredWorkspaceId ?? self.preferredWorkspaceId
            )
            if let currentWorkspace {
                setWorkspace(currentWorkspace)
            }
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
    public var workspaces: [Workspace] = []
    public var isLoading = true
    public var isAuthenticated: Bool { currentUser != nil }
    public var preferredWorkspaceId: String? {
        userDefaults.string(forKey: Self.selectedWorkspaceDefaultsKey)
    }

    private let keychain: KeychainStore
    private let userDefaults: UserDefaults

    static let selectedWorkspaceDefaultsKey = "selected_workspace_id"

    public init(keychain: KeychainStore = KeychainStore(), userDefaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.userDefaults = userDefaults
    }

    nonisolated public func token() -> String? { try? keychain.load() }

    public func login(user: User, workspace: Workspace?, token: String) throws {
        try login(user: user, workspaces: workspace.map { [$0] } ?? [], token: token)
    }

    public func login(user: User, workspaces: [Workspace], token: String) throws {
        try keychain.save(token)
        currentUser = user
        self.workspaces = workspaces
        if let workspace = Self.preferredWorkspace(from: workspaces, preferredId: preferredWorkspaceId) {
            setWorkspace(workspace)
        } else {
            currentWorkspace = nil
            userDefaults.removeObject(forKey: Self.selectedWorkspaceDefaultsKey)
        }
        isLoading = false
    }

    public func logout() {
        try? keychain.delete()
        userDefaults.removeObject(forKey: Self.selectedWorkspaceDefaultsKey)
        currentUser = nil
        currentWorkspace = nil
        workspaces = []
    }

    public func restore(using api: APIClient, preferredWorkspaceId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        guard (try? keychain.load()) != nil else { return }
        do {
            let user = try await api.getMe()
            let fetchedWorkspaces = try await api.listWorkspaces()
            currentUser = user
            workspaces = fetchedWorkspaces
            currentWorkspace = Self.preferredWorkspace(
                from: fetchedWorkspaces,
                preferredId: preferredWorkspaceId ?? self.preferredWorkspaceId
            )
            if let currentWorkspace {
                setWorkspace(currentWorkspace)
            }
        } catch {
            try? keychain.delete()
        }
    }
}
#endif

public extension AuthSession {
    func setWorkspace(_ workspace: Workspace) {
        currentWorkspace = workspace
        userDefaults.set(workspace.id, forKey: Self.selectedWorkspaceDefaultsKey)
    }

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
