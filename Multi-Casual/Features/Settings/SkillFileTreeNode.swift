import Foundation

public struct SkillFileTreeNode: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let path: String
    public let file: SkillFile?
    public let children: [SkillFileTreeNode]

    public var isDirectory: Bool { file == nil }

    public static func build(from files: [SkillFile]) -> [SkillFileTreeNode] {
        let root = SkillFileTreeBuilderNode(name: "", path: "")

        for file in files where !file.path.isEmpty {
            root.insert(file)
        }

        return root.sortedChildren()
    }
}

private final class SkillFileTreeBuilderNode {
    let name: String
    let path: String
    var file: SkillFile?
    var children: [String: SkillFileTreeBuilderNode] = [:]

    init(name: String, path: String, file: SkillFile? = nil) {
        self.name = name
        self.path = path
        self.file = file
    }

    func insert(_ file: SkillFile) {
        let parts = file.path.split(separator: "/").map(String.init)
        guard !parts.isEmpty else { return }
        insert(file, parts: parts, index: 0)
    }

    private func insert(_ file: SkillFile, parts: [String], index: Int) {
        let part = parts[index]
        let childPath = path.isEmpty ? part : "\(path)/\(part)"

        if index == parts.count - 1 {
            children[part] = SkillFileTreeBuilderNode(name: part, path: childPath, file: file)
            return
        }

        let child = children[part] ?? SkillFileTreeBuilderNode(name: part, path: childPath)
        children[part] = child
        child.insert(file, parts: parts, index: index + 1)
    }

    func sortedChildren() -> [SkillFileTreeNode] {
        children.values
            .sorted { lhs, rhs in
                if lhs.file == nil, rhs.file != nil { return true }
                if lhs.file != nil, rhs.file == nil { return false }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map { child in
                SkillFileTreeNode(
                    id: child.file?.id ?? "dir:\(child.path)",
                    name: child.name,
                    path: child.path,
                    file: child.file,
                    children: child.sortedChildren()
                )
            }
    }
}
