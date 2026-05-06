import XCTest
@testable import MultiCasual

final class MarkdownRendererTests: XCTestCase {
    func test_attributedStringParsesInlineMarkdown() throws {
        let attributed = MarkdownRenderer.attributedString(from: "Hello **bold** and *em* with [link](https://multica.ai).")

        XCTAssertEqual(String(attributed.characters), "Hello bold and em with link.")
        XCTAssertTrue(attributed.containsInlineIntent(.stronglyEmphasized, for: "bold"))
        XCTAssertTrue(attributed.containsInlineIntent(.emphasized, for: "em"))
        XCTAssertEqual(attributed.link(for: "link")?.absoluteString, "https://multica.ai")
    }

    func test_attributedStringPreservesUserNewlinesAndListMarkers() throws {
        let source = "First paragraph\n\n- one\n- two"

        let attributed = MarkdownRenderer.attributedString(from: source)

        XCTAssertEqual(String(attributed.characters), "First paragraph\n\n- one\n- two")
    }

    func test_attributedStringKeepsPlainTextAsPlainText() throws {
        let source = "No markdown here."

        let attributed = MarkdownRenderer.attributedString(from: source)

        XCTAssertEqual(String(attributed.characters), source)
        XCTAssertNil(attributed.inlineIntent(for: source))
    }
}

private extension AttributedString {
    func containsInlineIntent(_ intent: InlinePresentationIntent, for text: String) -> Bool {
        inlineIntent(for: text)?.contains(intent) == true
    }

    func inlineIntent(for text: String) -> InlinePresentationIntent? {
        guard let range = range(of: text) else { return nil }
        for run in runs where run.range.overlaps(range) {
            return run.inlinePresentationIntent
        }
        return nil
    }

    func link(for text: String) -> URL? {
        guard let range = range(of: text) else { return nil }
        for run in runs where run.range.overlaps(range) {
            return run.link
        }
        return nil
    }
}
