import XCTest
@testable import MultiCasual

final class AppEnvironmentTests: XCTestCase {
    func test_officialDefaultsUseOfficialMultiCasualService() throws {
        let env = AppEnvironment.official

        XCTAssertEqual(env.kind, .official)
        XCTAssertEqual(env.displayName, "Multi-Casual")
        XCTAssertEqual(env.apiBaseURL.absoluteString, "https://api.multica.ai")
        XCTAssertEqual(env.appURL.absoluteString, "https://app.multica.ai")
        XCTAssertEqual(env.webSocketURL.absoluteString, "wss://api.multica.ai/ws")
        XCTAssertEqual(env.urlScheme, "ai.multi-casual.app")
        XCTAssertEqual(env.keychainService, "ai.multi-casual.app")
        XCTAssertNil(env.allowedEmailDomainHint)
    }

    func test_xiaomiDefaultsUseSelfHostedService() throws {
        let env = AppEnvironment.xiaomi

        XCTAssertEqual(env.kind, .xiaomi)
        XCTAssertEqual(env.displayName, "Multi-Casual Xiaomi")
        XCTAssertEqual(env.apiBaseURL.absoluteString, "http://staging-multica.ad.xiaomi.srv")
        XCTAssertEqual(env.appURL.absoluteString, "http://staging-multica.ad.xiaomi.srv")
        XCTAssertEqual(env.webSocketURL.absoluteString, "ws://staging-multica.ad.xiaomi.srv/ws")
        XCTAssertEqual(env.urlScheme, "ai.multi-casual.app.xiaomi")
        XCTAssertEqual(env.keychainService, "ai.multi-casual.app.xiaomi")
        XCTAssertEqual(env.allowedEmailDomainHint, "@xiaomi.com")
    }

    func test_environmentCanBeBuiltFromInfoDictionary() throws {
        let env = try AppEnvironment(
            infoDictionary: [
                "MULTI_CASUAL_ENVIRONMENT": "xiaomi",
                "MULTI_CASUAL_DISPLAY_NAME": "Multi-Casual Xiaomi",
                "MULTI_CASUAL_API_BASE_URL": "http://staging-multica.ad.xiaomi.srv",
                "MULTI_CASUAL_APP_URL": "http://staging-multica.ad.xiaomi.srv",
                "MULTI_CASUAL_WS_URL": "ws://staging-multica.ad.xiaomi.srv/ws",
                "MULTI_CASUAL_URL_SCHEME": "ai.multi-casual.app.xiaomi",
                "MULTI_CASUAL_KEYCHAIN_SERVICE": "ai.multi-casual.app.xiaomi",
                "MULTI_CASUAL_ALLOWED_EMAIL_DOMAIN_HINT": "@xiaomi.com",
            ]
        )

        XCTAssertEqual(env.kind, .xiaomi)
        XCTAssertEqual(env.apiBaseURL.host, "staging-multica.ad.xiaomi.srv")
        XCTAssertEqual(env.webSocketURL.scheme, "ws")
    }

    func test_invalidURLFallsBackToOfficialInsteadOfCrashing() {
        let env = AppEnvironment.fallback(
            infoDictionary: [
                "MULTI_CASUAL_ENVIRONMENT": "xiaomi",
                "MULTI_CASUAL_API_BASE_URL": "not a url",
            ]
        )

        XCTAssertEqual(env, .official)
    }
}
