import Foundation
import CryptoKit

// Currently only `generateRandomString` is wired up (used for the OAuth
// `state` CSRF value in LoginView). The verifier/challenge pair is kept
// for the day the backend switches to PKCE-based server-side exchange
// (no client_secret) — today it uses client_secret, so PKCE would break
// Google's token exchange and must stay off.
public struct PKCE: Sendable, Equatable {
    public let verifier: String
    public let challenge: String

    public init() {
        let verifier = Self.generateRandomString(byteLength: 64)
        self.verifier = verifier
        self.challenge = Self.deriveChallenge(from: verifier)
    }

    public init(verifier: String) {
        self.verifier = verifier
        self.challenge = Self.deriveChallenge(from: verifier)
    }

    public static func generateRandomString(byteLength: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            for i in bytes.indices { bytes[i] = UInt8.random(in: 0...255) }
        }
        return Data(bytes).base64URLEncodedString()
    }

    public static func deriveChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
