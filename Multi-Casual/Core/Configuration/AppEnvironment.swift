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
        displayName: "Multi-Casual",
        apiBaseURL: URL(string: "https://api.multi-casual.ai")!,
        appURL: URL(string: "https://app.multi-casual.ai")!,
        webSocketURL: URL(string: "wss://api.multi-casual.ai/ws")!,
        urlScheme: "ai.multi-casual.app",
        keychainService: "ai.multi-casual.app",
        allowedEmailDomainHint: nil
    )

    public static let xiaomi = AppEnvironment(
        kind: .xiaomi,
        displayName: "Multi-Casual Xiaomi",
        apiBaseURL: URL(string: "http://staging-multica.ad.xiaomi.srv")!,
        appURL: URL(string: "http://staging-multica.ad.xiaomi.srv")!,
        webSocketURL: URL(string: "ws://staging-multica.ad.xiaomi.srv/ws")!,
        urlScheme: "ai.multi-casual.app.xiaomi",
        keychainService: "ai.multi-casual.app.xiaomi",
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
        let kind = Kind(rawValue: Self.string("MULTI_CASUAL_ENVIRONMENT", in: infoDictionary) ?? "") ?? .official
        let defaults: AppEnvironment = kind == .xiaomi ? .xiaomi : .official

        self.kind = kind
        displayName = Self.string("MULTI_CASUAL_DISPLAY_NAME", in: infoDictionary) ?? defaults.displayName
        apiBaseURL = try Self.url("MULTI_CASUAL_API_BASE_URL", in: infoDictionary) ?? defaults.apiBaseURL
        appURL = try Self.url("MULTI_CASUAL_APP_URL", in: infoDictionary) ?? defaults.appURL
        webSocketURL = try Self.url("MULTI_CASUAL_WS_URL", in: infoDictionary) ?? defaults.webSocketURL
        urlScheme = Self.string("MULTI_CASUAL_URL_SCHEME", in: infoDictionary) ?? defaults.urlScheme
        keychainService = Self.string("MULTI_CASUAL_KEYCHAIN_SERVICE", in: infoDictionary) ?? defaults.keychainService
        allowedEmailDomainHint = Self.string("MULTI_CASUAL_ALLOWED_EMAIL_DOMAIN_HINT", in: infoDictionary) ?? defaults.allowedEmailDomainHint
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
