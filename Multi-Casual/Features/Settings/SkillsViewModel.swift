import Foundation
import Observation

@Observable
@MainActor
public final class SkillsViewModel {
    public var skills: [Skill] = []
    public var isLoading = false
    public var isMutating = false
    public var isLoadingSkillDetail = false
    public var errorMessage: String?
    public var skillDetailError: String?

    private let api: APIClient
    private let authSession: AuthSession

    public init(api: APIClient, authSession: AuthSession) {
        self.api = api
        self.authSession = authSession
    }

    public func load() async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing skills."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            skills = try await api.listSkills(workspaceId: workspaceId).sorted(by: skillSort)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createSkill(name: String, description: String, content: String) async -> Skill? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing skills."
            return nil
        }
        return await mutate {
            try await api.createSkill(name: name, description: description, content: content, workspaceId: workspaceId)
        }
    }

    public func updateSkill(id: String, name: String, description: String, content: String) async -> Skill? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing skills."
            return nil
        }
        return await mutate {
            try await api.updateSkill(id: id, name: name, description: description, content: content, workspaceId: workspaceId)
        }
    }

    public func importSkill(url: String) async -> Skill? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing skills."
            return nil
        }
        return await mutate {
            try await api.importSkill(url: url, workspaceId: workspaceId)
        }
    }

    public func loadSkillDetail(id: String) async -> Skill? {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            skillDetailError = "Pick a workspace before viewing skill details."
            return nil
        }
        guard !isLoadingSkillDetail else {
            return skills.first { $0.id == id }
        }

        isLoadingSkillDetail = true
        skillDetailError = nil
        defer { isLoadingSkillDetail = false }

        do {
            let skill = try await api.getSkill(id: id, workspaceId: workspaceId)
            upsert(skill)
            return skill
        } catch {
            skillDetailError = error.localizedDescription
            return nil
        }
    }

    public func deleteSkill(id: String) async {
        guard let workspaceId = authSession.currentWorkspace?.id else {
            errorMessage = "Pick a workspace before managing skills."
            return
        }
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            try await api.deleteSkill(id: id, workspaceId: workspaceId)
            skills.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mutate(_ operation: () async throws -> Skill) async -> Skill? {
        guard !isMutating else { return nil }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            let skill = try await operation()
            upsert(skill)
            return skill
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func upsert(_ skill: Skill) {
        if let index = skills.firstIndex(where: { $0.id == skill.id }) {
            skills[index] = skill
        } else {
            skills.append(skill)
        }
        skills.sort(by: skillSort)
    }

    private func skillSort(_ lhs: Skill, _ rhs: Skill) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
