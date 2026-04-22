import Foundation

public struct PageResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let items: [T]
    public let hasMore: Bool
    public let total: Int?

    private static var knownKeys: Set<String> {
        ["issues", "items", "projects", "comments", "workspaces", "runs", "messages", "inbox"]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        hasMore = (try? container.decode(Bool.self, forKey: DynamicKey("has_more"))) ?? false
        total = try? container.decode(Int.self, forKey: DynamicKey("total"))

        // Try each known collection key. If none match, surface the mismatch
        // instead of silently returning an empty page.
        for key in Self.knownKeys {
            if let arr = try? container.decode([T].self, forKey: DynamicKey(key)) {
                items = arr
                return
            }
        }
        throw DecodingError.keyNotFound(
            DynamicKey("items"),
            .init(codingPath: container.codingPath,
                  debugDescription: "No known collection key found in PageResponse. Keys: \(container.allKeys.map(\.stringValue))")
        )
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
