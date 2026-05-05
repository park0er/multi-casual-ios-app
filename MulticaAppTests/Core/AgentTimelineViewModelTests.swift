import XCTest
@testable import MultiCasual

@MainActor
final class AgentTimelineViewModelTests: XCTestCase {
    func test_loadHistory_surfacesEndpointError() async throws {
        let client = makeClient { req in
            XCTAssertEqual(req.url?.path, "/api/tasks/t1/messages")
            XCTAssertTrue(req.url?.absoluteString.contains("workspace_id=w1") ?? false)
            return Self.response(for: req, body: Data(#"{"error":"messages unavailable"}"#.utf8), status: 500)
        }
        let vm = AgentTimelineViewModel(taskId: "t1", workspaceId: "w1", api: client)

        await vm.loadHistory()

        XCTAssertTrue(vm.timeline.isEmpty)
        XCTAssertEqual(vm.errorMessage, "messages unavailable")
        XCTAssertFalse(vm.isLoading)
    }

    func test_applyRealtimeMessageReplacesExistingSeqAndKeepsTimelineOrdered() async throws {
        let client = makeClient { req in
            let json = """
            [
              {"task_id":"t1","seq":1,"type":"text","content":"old"},
              {"task_id":"t1","seq":3,"type":"error","content":"failed"}
            ]
            """.data(using: .utf8)!
            return Self.response(for: req, body: json)
        }
        let vm = AgentTimelineViewModel(taskId: "t1", api: client)

        await vm.loadHistory()
        vm.applyRealtimeMessage(TaskMessage(
            id: "t1:1",
            seq: 1,
            type: .text,
            tool: nil,
            content: "new",
            input: nil,
            output: nil
        ))
        vm.applyRealtimeMessage(TaskMessage(
            id: "t1:2",
            seq: 2,
            type: .thinking,
            tool: nil,
            content: "middle",
            input: nil,
            output: nil
        ))

        XCTAssertEqual(vm.timeline.map(\.id), [1, 2, 3])
        XCTAssertEqual(vm.timeline.map(\.summary), ["new", "middle", "failed"])
    }

    func test_applyRealtimePayloadSurfacesDecodeErrors() async throws {
        let client = makeClient { req in
            Self.response(for: req, body: Data("[]".utf8))
        }
        let vm = AgentTimelineViewModel(taskId: "t1", api: client)

        vm.applyRealtimePayload(Data(#"{"task_id":"t1","type":"text","content":"missing seq"}"#.utf8))

        XCTAssertTrue(vm.timeline.isEmpty)
        XCTAssertNotNil(vm.errorMessage)
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = handler
        return APIClient(session: URLSession(configuration: config), token: "test-token")
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
