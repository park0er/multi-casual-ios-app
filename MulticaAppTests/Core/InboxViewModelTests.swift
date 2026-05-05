import XCTest
@testable import MultiCasual

@MainActor
final class InboxViewModelTests: XCTestCase {
    func test_markRead_updatesItemAndUnreadCount() async throws {
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/inbox":
                return Self.response(for: req, body: Self.inboxItemJSON(read: false, archived: false))
            case "/api/inbox/n1/read":
                return Self.response(for: req, body: Self.singleInboxItemJSON(read: true, archived: false))
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = InboxViewModel(api: client)

        await vm.loadNext()
        await vm.markRead(id: "n1")

        XCTAssertEqual(vm.loader.items.first?.read, true)
        XCTAssertEqual(vm.unreadCount, 0)
        XCTAssertNil(vm.lastError)
    }

    func test_archive_removesItemAndRecomputesUnreadCount() async throws {
        let client = makeClient { req in
            switch req.url?.path {
            case "/api/inbox":
                return Self.response(for: req, body: Self.inboxItemJSON(read: false, archived: false))
            case "/api/inbox/n1/archive":
                return Self.response(for: req, body: Self.singleInboxItemJSON(read: false, archived: true))
            default:
                XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
                return Self.response(for: req, body: Data("{}".utf8), status: 404)
            }
        }
        let vm = InboxViewModel(api: client)

        await vm.loadNext()
        await vm.archive(id: "n1")

        XCTAssertTrue(vm.loader.items.isEmpty)
        XCTAssertEqual(vm.unreadCount, 0)
        XCTAssertNil(vm.lastError)
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = handler
        return APIClient(session: URLSession(configuration: config), token: "test-token")
    }

    private static func inboxItemJSON(read: Bool, archived: Bool) -> Data {
        Data("[\(String(data: singleInboxItemJSON(read: read, archived: archived), encoding: .utf8)!)]".utf8)
    }

    private static func singleInboxItemJSON(read: Bool, archived: Bool) -> Data {
        """
        {"id":"n1","workspace_id":"w1","recipient_type":"member","recipient_id":"u1",
         "actor_type":null,"actor_id":null,"type":"new_comment","severity":"attention",
         "issue_id":"i1","title":"PAR-73 updated","body":null,"issue_status":"todo",
         "read":\(read),"archived":\(archived),"created_at":"2026-01-01T00:00:00Z",
         "details":{"identifier":"PAR-73"}}
        """.data(using: .utf8)!
    }

    private static func response(
        for request: URLRequest,
        body: Data,
        status: Int = 200
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            body
        )
    }
}
