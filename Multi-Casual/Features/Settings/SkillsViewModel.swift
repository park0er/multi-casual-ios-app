import Foundation
import Observation

@Observable
@MainActor
public final class SkillsViewModel {
    public var skills: [Skill] = []
    public var isLoading = false
    public var isMutating = false
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
            skills = try await api.listSkills().sorted(by: skillSort)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createSkill(name: String, description: String, content: String) async -> Skill? {
        await mutate {
            try await api.createSkill(name: name, description: description, content: content)
        }
    }

    public func updateSkill(id: String, name: String, description: String, content: String) async -> Skill? {
        await mutate {
            try await api.updateSkill(id: id, name: name, description: description, content: content)
        }
    }

    public func importSkill(url: String) async -> Skill? {
        await mutate {
            try await api.importSkill(url: url)
        }
    }

    public func deleteSkill(id: String) async {
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            try await api.deleteSkill(id: id)
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
