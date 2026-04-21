import XCTest
@testable import MultiCasual

final class PKCETests: XCTestCase {
    // RFC 7636 Appendix B test vector.
    func test_deriveChallenge_matchesRFC7636Vector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let expected = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        XCTAssertEqual(PKCE.deriveChallenge(from: verifier), expected)
    }

    func test_generate_producesUniqueVerifiers() {
        let a = PKCE()
        let b = PKCE()
        XCTAssertNotEqual(a.verifier, b.verifier)
        XCTAssertNotEqual(a.challenge, b.challenge)
    }

    func test_verifier_isBase64URLSafe() {
        let pkce = PKCE()
        // base64url alphabet: A-Z a-z 0-9 - _ (no padding)
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        )
        XCTAssertTrue(pkce.verifier.unicodeScalars.allSatisfy { allowed.contains($0) })
        XCTAssertTrue(pkce.challenge.unicodeScalars.allSatisfy { allowed.contains($0) })
        XCTAssertFalse(pkce.verifier.contains("="))
        XCTAssertFalse(pkce.challenge.contains("="))
    }
}
