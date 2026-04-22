import XCTest
@testable import MultiCasual

final class PaginatedLoaderTests: XCTestCase {

    struct Item: Identifiable, Sendable, Decodable { let id: String }

    struct StubError: Error, Equatable {}

    @MainActor
    func test_loadNext_appendsItems() async throws {
        let loader = PaginatedLoader<Item>()
        try await loader.loadNext { _ in
            PageResponse(items: [Item(id: "a"), Item(id: "b")], hasMore: true, total: 10)
        }
        XCTAssertEqual(loader.items.count, 2)
        XCTAssertTrue(loader.hasMore)
    }

    @MainActor
    func test_loadNext_whenHasMoreFalse_stopsLoading() async throws {
        let loader = PaginatedLoader<Item>()
        try await loader.loadNext { _ in PageResponse(items: [Item(id: "a")], hasMore: false, total: 1) }
        try await loader.loadNext { _ in PageResponse(items: [Item(id: "b")], hasMore: false, total: 1) }
        XCTAssertEqual(loader.items.count, 1, "Should not fetch second page when hasMore=false")
    }

    @MainActor
    func test_reset_clearsState() async throws {
        let loader = PaginatedLoader<Item>()
        try await loader.loadNext { _ in PageResponse(items: [Item(id: "a")], hasMore: true, total: 5) }
        loader.reset()
        XCTAssertTrue(loader.items.isEmpty)
        XCTAssertTrue(loader.hasMore)
        XCTAssertFalse(loader.isLoading)
    }

    @MainActor
    func test_loadNext_passesCorrectOffset() async throws {
        var capturedOffsets: [Int] = []
        let loader = PaginatedLoader<Item>()
        try await loader.loadNext { offset in
            capturedOffsets.append(offset)
            return PageResponse(items: [Item(id: "a"), Item(id: "b")], hasMore: true, total: 10)
        }
        try await loader.loadNext { offset in
            capturedOffsets.append(offset)
            return PageResponse(items: [Item(id: "c")], hasMore: false, total: 10)
        }
        XCTAssertEqual(capturedOffsets, [0, 2], "Second page should use offset=2 (count of first page)")
    }

    @MainActor
    func test_loadNext_propagatesErrors() async {
        let loader = PaginatedLoader<Item>()
        do {
            try await loader.loadNext { _ in throw StubError() }
            XCTFail("Expected StubError to propagate")
        } catch let err as StubError {
            XCTAssertEqual(err, StubError())
        } catch {
            XCTFail("Wrong error: \(error)")
        }
        XCTAssertFalse(loader.isLoading, "isLoading should reset even when fetch throws")
        XCTAssertTrue(loader.items.isEmpty)
    }
}
