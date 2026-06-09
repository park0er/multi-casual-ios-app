#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

struct GrowingComposerTextField: View {
    let placeholder: String
    @Binding var text: String
    var minLines = 3
    var maxLines = 8
    var background: Color = Color.secondary.opacity(0.10)
    var accessibilityIdentifier: String?

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(minLines...maxLines)
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.16))
            }
            .accessibilityIdentifier(accessibilityIdentifier ?? "GrowingComposerTextField")
    }
}
#endif
