#if canImport(SwiftUI)
import SwiftUI

public enum MarkdownRenderer {
    public static func attributedString(from markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        do {
            return try AttributedString(markdown: markdown, options: options)
        } catch {
            return AttributedString(markdown)
        }
    }
}

public struct MarkdownText: View {
    private let markdown: String

    public init(_ markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        Text(MarkdownRenderer.attributedString(from: markdown))
    }
}

public struct MarkdownLabeledContent: View {
    private let label: String
    private let value: String

    public init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            MarkdownText(label)
            Spacer(minLength: 12)
            MarkdownText(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

public struct MarkdownIconLabel: View {
    private let title: String
    private let systemImage: String

    public init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        Label {
            MarkdownText(title)
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

public extension View {
    @ViewBuilder
    func markdownNavigationTitle(_ title: String) -> some View {
        #if os(iOS)
        self.navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .markdownNavigationPrincipalTitle(title)
        #else
        self.navigationTitle("")
            .markdownNavigationPrincipalTitle(title)
        #endif
    }

    private func markdownNavigationPrincipalTitle(_ title: String) -> some View {
        toolbar {
            ToolbarItem(placement: .principal) {
                MarkdownText(title)
                    .font(.headline)
                    .lineLimit(1)
            }
        }
    }
}
#endif
