import Foundation

public struct AppEnvironment: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case official
        case xiaomi
    }

    public enum ConfigurationError: Error, Equatable {
        case invalidURL(String)
    }

    public let kind: Kind
    public let displayName: String
    public let apiBaseURL: URL
    public let appURL: URL
    public let webSocketURL: URL
    public let urlScheme: String
    public let keychainService: String
    public let allowedEmailDomainHint: String?

    public static let official = AppEnvironment(
        kind: .official,
        displayName: "Multica",
        apiBaseURL: URL(string: "https://api.multica.ai")!,
        appURL: URL(string: "https://app.multica.ai")!,
        webSocketURL: URL(string: "wss://api.multica.ai/ws")!,
        urlScheme: "ai.multica.app",
        keychainService: "ai.multica.app",
        allowedEmailDomainHint: nil
    )

    public static let xiaomi = AppEnvironment(
        kind: .xiaomi,
        displayName: "Multica Xiaomi",
        apiBaseURL: URL(string: "http://staging-multica.ad.xiaomi.srv")!,
        appURL: URL(string: "http://staging-multica.ad.xiaomi.srv")!,
        webSocketURL: URL(string: "ws://staging-multica.ad.xiaomi.srv/ws")!,
        urlScheme: "ai.multica.app.xiaomi",
        keychainService: "ai.multica.app.xiaomi",
        allowedEmailDomainHint: "@xiaomi.com"
    )

    public static var current: AppEnvironment {
        fallback(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    public static func fallback(infoDictionary: [String: Any]) -> AppEnvironment {
        (try? AppEnvironment(infoDictionary: infoDictionary)) ?? .official
    }

    public init(
        kind: Kind,
        displayName: String,
        apiBaseURL: URL,
        appURL: URL,
        webSocketURL: URL,
        urlScheme: String,
        keychainService: String,
        allowedEmailDomainHint: String?
    ) {
        self.kind = kind
        self.displayName = displayName
        self.apiBaseURL = apiBaseURL
        self.appURL = appURL
        self.webSocketURL = webSocketURL
        self.urlScheme = urlScheme
        self.keychainService = keychainService
        self.allowedEmailDomainHint = allowedEmailDomainHint
    }

    public init(infoDictionary: [String: Any]) throws {
        let kind = Kind(rawValue: Self.string("MULTICA_ENVIRONMENT", in: infoDictionary) ?? "") ?? .official
        let defaults: AppEnvironment = kind == .xiaomi ? .xiaomi : .official

        self.kind = kind
        displayName = Self.string("MULTICA_DISPLAY_NAME", in: infoDictionary) ?? defaults.displayName
        apiBaseURL = try Self.url("MULTICA_API_BASE_URL", in: infoDictionary) ?? defaults.apiBaseURL
        appURL = try Self.url("MULTICA_APP_URL", in: infoDictionary) ?? defaults.appURL
        webSocketURL = try Self.url("MULTICA_WS_URL", in: infoDictionary) ?? defaults.webSocketURL
        urlScheme = Self.string("MULTICA_URL_SCHEME", in: infoDictionary) ?? defaults.urlScheme
        keychainService = Self.string("MULTICA_KEYCHAIN_SERVICE", in: infoDictionary) ?? defaults.keychainService
        allowedEmailDomainHint = Self.string("MULTICA_ALLOWED_EMAIL_DOMAIN_HINT", in: infoDictionary) ?? defaults.allowedEmailDomainHint
    }

    private static func string(_ key: String, in dictionary: [String: Any]) -> String? {
        guard let value = dictionary[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func url(_ key: String, in dictionary: [String: Any]) throws -> URL? {
        guard let raw = string(key, in: dictionary) else { return nil }
        guard let url = URL(string: raw), url.scheme != nil, url.host != nil else {
            throw ConfigurationError.invalidURL(raw)
        }
        return url
    }
}
