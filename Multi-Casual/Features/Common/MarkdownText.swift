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
#endif
