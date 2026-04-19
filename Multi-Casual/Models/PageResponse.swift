import Foundation

public struct PageResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let items: [T]
    public let hasMore: Bool
    public let total: Int?

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        hasMore = (try? container.decode(Bool.self, forKey: DynamicKey("has_more"))) ?? false
        total = try? container.decode(Int.self, forKey: DynamicKey("total"))

        if let issues = try? container.decode([T].self, forKey: DynamicKey("issues")) {
            items = issues
        } else if let itemsArr = try? container.decode([T].self, forKey: DynamicKey("items")) {
            self.items = itemsArr
        } else if let projects = try? container.decode([T].self, forKey: DynamicKey("projects")) {
            items = projects
        } else if let comments = try? container.decode([T].self, forKey: DynamicKey("comments")) {
            items = comments
        } else {
            items = []
        }
    }

    // Test-only initialiser (no JSON decoding needed)
    public init(items: [T], hasMore: Bool, total: Int?) {
        self.items = items
        self.hasMore = hasMore
        self.total = total
    }
}

public struct DynamicKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?
    public init(_ string: String) { self.stringValue = string }
    public init?(stringValue: String) { self.stringValue = stringValue }
    public init?(intValue: Int) { return nil }
}
