import Foundation

public struct PageResponse<T: Decodable & Sendable>: Decodable, Sendable {
    public let items: [T]
    public let hasMore: Bool
    public let total: Int?

    private static var knownKeys: Set<String> {
        ["issues", "items", "projects", "comments", "workspaces", "runs", "messages", "inbox", "resources"]
    }

    public init(from decoder: Decoder) throws {
        if let array = try? [T](from: decoder) {
            items = array
            hasMore = false
            total = array.count
            return
        }

        let container = try decoder.container(keyedBy: DynamicKey.self)
        hasMore = (try? container.decode(Bool.self, forKey: DynamicKey("has_more"))) ?? false
        total = try? container.decode(Int.self, forKey: DynamicKey("total"))

        // Decode the collection under the key the server actually returned.
        // If the collection exists but an element shape changed, preserve that
        // nested decoding error instead of misreporting a missing `items` key.
        for key in Self.knownKeys {
            let dynamicKey = DynamicKey(key)
            if container.contains(dynamicKey) {
                items = try container.decode([T].self, forKey: dynamicKey)
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

    public func inferringHasMore(fromOffset offset: Int) -> PageResponse<T> {
        guard let total else { return self }
        let inferredHasMore = offset + items.count < total
        guard inferredHasMore != hasMore else { return self }
        return PageResponse(items: items, hasMore: inferredHasMore, total: total)
    }
}

public struct DynamicKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?
    public init(_ string: String) { self.stringValue = string }
    public init?(stringValue: String) { self.stringValue = stringValue }
    public init?(intValue: Int) { return nil }
}
