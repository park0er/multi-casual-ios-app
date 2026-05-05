import XCTest
@testable import MultiCasual

@MainActor
final class IssueListViewModelTests: XCTestCase {
    func test_loadNext_withoutWorkspaceSurfacesActionableError() async throws {
        let vm = IssueListViewModel(api: makeClient(), authSession: AuthSession(userDefaults: makeUserDefaults()))

        await vm.loadNext()

        XCTAssertEqual(vm.lastError?.localizedDescription, "Pick a workspace before opening Issues.")
    }

    private func makeClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { req in
            XCTFail("Unexpected request: \(req.url?.absoluteString ?? "")")
            return (
                HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }
        return APIClient(session: URLSession(configuration: config), token: "test-token")
    }

    private func makeUserDefaults() -> UserDefaults {
        UserDefaults(suiteName: "IssueListViewModelTests.\(UUID().uuidString)")!
    }
}
