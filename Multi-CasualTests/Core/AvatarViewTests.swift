import XCTest
@testable import MultiCasual

final class AvatarViewTests: XCTestCase {
    func test_avatarURLResolverKeepsAbsoluteURLs() throws {
        let url = try XCTUnwrap(AvatarURLResolver.url(from: "https://cdn.example/avatar.png"))

        XCTAssertEqual(url.absoluteString, "https://cdn.example/avatar.png")
    }

    func test_avatarURLResolverBuildsRelativeURLsAgainstAPIBase() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://api.multica.ai"))
        let url = try XCTUnwrap(AvatarURLResolver.url(from: "/uploads/avatar.png", baseURL: baseURL))

        XCTAssertEqual(url.absoluteString, "https://api.multica.ai/uploads/avatar.png")
    }

    func test_avatarURLResolverSupportsProtocolRelativeURLs() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://api.multica.ai"))
        let url = try XCTUnwrap(AvatarURLResolver.url(from: "//cdn.example/avatar.png", baseURL: baseURL))

        XCTAssertEqual(url.absoluteString, "https://cdn.example/avatar.png")
    }

    func test_avatarURLResolverIgnoresBlankURLs() {
        XCTAssertNil(AvatarURLResolver.url(from: "   "))
        XCTAssertNil(AvatarURLResolver.url(from: nil))
    }
}
