import XCTest
@testable import MultiCasual

final class AppEnvironmentTests: XCTestCase {
    func test_officialDefaultsUseOfficialMulticaService() throws {
        let env = AppEnvironment.official

        XCTAssertEqual(env.kind, .official)
        XCTAssertEqual(env.displayName, "Multica")
        XCTAssertEqual(env.apiBaseURL.absoluteString, "https://api.multica.ai")
        XCTAssertEqual(env.appURL.absoluteString, "https://app.multica.ai")
        XCTAssertEqual(env.webSocketURL.absoluteString, "wss://api.multica.ai/ws")
        XCTAssertEqual(env.urlScheme, "ai.multica.app")
        XCTAssertEqual(env.keychainService, "ai.multica.app")
        XCTAssertNil(env.allowedEmailDomainHint)
    }

    func test_xiaomiDefaultsUseSelfHostedService() throws {
        let env = AppEnvironment.xiaomi

        XCTAssertEqual(env.kind, .xiaomi)
        XCTAssertEqual(env.displayName, "Multica Xiaomi")
        XCTAssertEqual(env.apiBaseURL.absoluteString, "http://staging-multica.ad.xiaomi.srv")
        XCTAssertEqual(env.appURL.absoluteString, "http://staging-multica.ad.xiaomi.srv")
        XCTAssertEqual(env.webSocketURL.absoluteString, "ws://staging-multica.ad.xiaomi.srv/ws")
        XCTAssertEqual(env.urlScheme, "ai.multica.app.xiaomi")
        XCTAssertEqual(env.keychainService, "ai.multica.app.xiaomi")
        XCTAssertEqual(env.allowedEmailDomainHint, "@xiaomi.com")
    }

    func test_environmentCanBeBuiltFromInfoDictionary() throws {
        let env = try AppEnvironment(
            infoDictionary: [
                "MULTICA_ENVIRONMENT": "xiaomi",
                "MULTICA_DISPLAY_NAME": "Multica Xiaomi",
                "MULTICA_API_BASE_URL": "http://staging-multica.ad.xiaomi.srv",
                "MULTICA_APP_URL": "http://staging-multica.ad.xiaomi.srv",
                "MULTICA_WS_URL": "ws://staging-multica.ad.xiaomi.srv/ws",
                "MULTICA_URL_SCHEME": "ai.multica.app.xiaomi",
                "MULTICA_KEYCHAIN_SERVICE": "ai.multica.app.xiaomi",
                "MULTICA_ALLOWED_EMAIL_DOMAIN_HINT": "@xiaomi.com",
            ]
        )

        XCTAssertEqual(env.kind, .xiaomi)
        XCTAssertEqual(env.apiBaseURL.host, "staging-multica.ad.xiaomi.srv")
        XCTAssertEqual(env.webSocketURL.scheme, "ws")
    }

    func test_invalidURLFallsBackToOfficialInsteadOfCrashing() {
        let env = AppEnvironment.fallback(
            infoDictionary: [
                "MULTICA_ENVIRONMENT": "xiaomi",
                "MULTICA_API_BASE_URL": "not a url",
            ]
        )

        XCTAssertEqual(env, .official)
    }
}
