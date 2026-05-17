import XCTest
@testable import MultiCasual

final class WebSocketActorTests: XCTestCase {
    func test_decodeEventFrame_extractsNestedTaskMessagePayload() throws {
        let frame = Data("""
        {"type":"task:message","payload":{"task_id":"t1","issue_id":"i1","seq":3,"type":"text","content":"hello"},"actor_id":"a1"}
        """.utf8)

        let event = try XCTUnwrap(WebSocketActor.decodeEventFrame(data: frame))

        XCTAssertEqual(event.type, "task:message")
        XCTAssertEqual(event.taskId, "t1")

        let message = try JSONDecoder().decode(TaskMessage.self, from: event.payload)
        XCTAssertEqual(message.id, "t1:3")
        XCTAssertEqual(message.seq, 3)
        XCTAssertEqual(message.content, "hello")
    }

    func test_decodeEventFrame_ignoresAuthAckFrames() {
        let frame = Data(#"{"type":"auth_ack"}"#.utf8)

        XCTAssertNil(WebSocketActor.decodeEventFrame(data: frame))
    }

    func test_webSocketURLIncludesWorkspaceAndClientPlatform() throws {
        let url = try WebSocketActor.makeConnectionURL(
            baseURL: AppEnvironment.xiaomi.webSocketURL,
            workspaceId: "workspace-123"
        )

        XCTAssertEqual(url.scheme, "ws")
        XCTAssertEqual(url.host, "staging-multica.ad.xiaomi.srv")
        XCTAssertEqual(url.path, "/ws")
        XCTAssertTrue(url.absoluteString.contains("workspace_id=workspace-123"))
        XCTAssertTrue(url.absoluteString.contains("client_platform=ios"))
    }
}
