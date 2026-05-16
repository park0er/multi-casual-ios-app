#if canImport(SwiftUI)
import SwiftUI

public enum AvatarURLResolver {
    public static func url(from rawValue: String?, baseURL: URL = AppEnvironment.current.apiBaseURL) -> URL? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let absoluteURL = URL(string: trimmed), absoluteURL.scheme != nil {
            return absoluteURL
        }
        if trimmed.hasPrefix("//"), let scheme = baseURL.scheme {
            return URL(string: "\(scheme):\(trimmed)")
        }
        return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
    }
}

public struct AvatarView: View {
    public enum Kind {
        case user
        case agent
    }

    private let name: String
    private let avatarUrl: String?
    private let kind: Kind
    private let size: CGFloat

    public init(name: String, avatarUrl: String?, kind: Kind = .user, size: CGFloat) {
        self.name = name
        self.avatarUrl = avatarUrl
        self.kind = kind
        self.size = size
    }

    public var body: some View {
        Group {
            if let url = AvatarURLResolver.url(from: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: max(8, size * 0.26), style: .continuous))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: max(8, size * 0.26), style: .continuous)
                .fill(kind == .agent ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.14))
            if let initials {
                Text(initials)
                    .font(.system(size: max(11, size * 0.38), weight: .semibold))
                    .foregroundStyle(kind == .agent ? Color.accentColor : Color.secondary)
            } else {
                Image(systemName: kind == .agent ? "bolt.fill" : "person.fill")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(kind == .agent ? Color.accentColor : Color.secondary)
            }
        }
    }

    private var initials: String? {
        let parts = name
            .split(whereSeparator: { $0.isWhitespace || $0 == "@" || $0 == "." })
            .prefix(2)
            .compactMap(\.first)
        guard !parts.isEmpty else { return nil }
        return String(parts).uppercased()
    }
}
#endif
