#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

struct GrowingComposerTextField: View {
    let placeholder: String
    @Binding var text: String
    var isExpanded = false
    var collapsedLines = 1
    var minLines = 3
    var maxLines = 8
    var background: Color = Color.secondary.opacity(0.10)
    var accessibilityIdentifier: String?

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(activeLineRange)
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, isExpanded ? 10 : 7)
            .background(background, in: RoundedRectangle(cornerRadius: isExpanded ? 18 : 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: isExpanded ? 18 : 16, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.16))
            }
            .animation(.snappy(duration: 0.18), value: isExpanded)
            .accessibilityIdentifier(accessibilityIdentifier ?? "GrowingComposerTextField")
    }

    private var activeLineRange: ClosedRange<Int> {
        isExpanded ? minLines...maxLines : collapsedLines...collapsedLines
    }
}
#endif
