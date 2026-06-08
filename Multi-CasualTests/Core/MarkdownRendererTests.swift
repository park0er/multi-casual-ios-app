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

    func test_interactiveMarkdownResolvesMentionLabelsAndAutolinksIssueReferences() throws {
        let context = MarkdownRenderContext(
            mentionDisplayNamesByURL: [
                "mention://agent/a1": "Codex Worker",
                "mention://member/u1": "Parker Zhang",
            ],
            issueReferencePrefixes: ["PAR"]
        )

        let rendered = MarkdownRenderer.interactiveMarkdown(
            from: "Ping [@Agent](mention://agent/a1), [@member](mention://member/u1), see PAR-73.",
            context: context
        )

        XCTAssertEqual(
            rendered,
            "Ping [@Codex Worker](mention://agent/a1), [@Parker Zhang](mention://member/u1), see [PAR-73](multi-casual://issue-reference/PAR-73)."
        )
    }

    func test_interactiveMarkdownDoesNotAutolinkIssueReferencesInsideExistingLinksOrCode() throws {
        let context = MarkdownRenderContext(issueReferencePrefixes: ["PAR"])

        let rendered = MarkdownRenderer.interactiveMarkdown(
            from: """
            Keep [PAR-73](https://example.com) and `PAR-74` unchanged.

            ```
            PAR-75 stays plain in code.
            ```

            Link PAR-76.
            """,
            context: context
        )

        XCTAssertEqual(
            rendered,
            """
            Keep [PAR-73](https://example.com) and `PAR-74` unchanged.

            ```
            PAR-75 stays plain in code.
            ```

            Link [PAR-76](multi-casual://issue-reference/PAR-76).
            """
        )
    }

    func test_interactiveMarkdownEscapesMentionDisplayNamesForMarkdownLinks() throws {
        let context = MarkdownRenderContext(
            mentionDisplayNamesByURL: ["mention://agent/a1": #"David[TF]\Ops"#]
        )

        let rendered = MarkdownRenderer.interactiveMarkdown(
            from: "Ping [@old](mention://agent/a1)",
            context: context
        )

        XCTAssertEqual(rendered, #"Ping [@David\[TF\]\\Ops](mention://agent/a1)"#)
    }

    func test_containsMarkdownLinkDetectsInteractiveIssueReferenceLinks() throws {
        XCTAssertTrue(MarkdownRenderer.containsMarkdownLink(in: "[PAR-73](multi-casual://issue-reference/PAR-73)"))
        XCTAssertTrue(MarkdownRenderer.containsMarkdownLink(in: "Ping [@Codex](mention://agent/a1)"))
        XCTAssertFalse(MarkdownRenderer.containsMarkdownLink(in: "PAR-73 is plain text before autolinking"))
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

    func test_blocksParseHeadingsParagraphsAndLists() throws {
        let blocks = MarkdownRenderer.blocks(
            from: """
            # Release notes

            Ship **Markdown** everywhere.

            - Issues
            - Agents

            1. Edit
            2. Reassign
            """
        )

        XCTAssertEqual(blocks, [
            .heading(level: 1, text: "Release notes"),
            .paragraph("Ship **Markdown** everywhere."),
            .unorderedList(["Issues", "Agents"]),
            .orderedList(["Edit", "Reassign"]),
        ])
    }

    func test_blocksParseQuotesAndCodeFences() throws {
        let blocks = MarkdownRenderer.blocks(
            from: """
            > Keep workspace context.
            > Retry only after a visible error.

            ```
            workspace_id=w1
            ```
            """
        )

        XCTAssertEqual(blocks, [
            .quote("Keep workspace context.\nRetry only after a visible error."),
            .codeBlock("workspace_id=w1"),
        ])
    }

    func test_blocksParseLanguageTaggedCodeFences() throws {
        let blocks = MarkdownRenderer.blocks(
            from: """
            ```swift
            let title = "**Markdown**"
            ```
            """
        )

        XCTAssertEqual(blocks, [
            .codeBlock(#"let title = "**Markdown**""#),
        ])
    }

    func test_blocksParsePipeTables() throws {
        let blocks = MarkdownRenderer.blocks(
            from: """
            | Step | Status |
            | --- | --- |
            | Markdown comments | Missing |
            | Agent activity | Too noisy |
            """
        )

        XCTAssertEqual(blocks, [
            .table(
                headers: ["Step", "Status"],
                rows: [
                    ["Markdown comments", "Missing"],
                    ["Agent activity", "Too noisy"],
                ]
            ),
        ])
    }

    func test_tableCellDetailTitleUsesColumnAndRowWhenAvailable() throws {
        XCTAssertEqual(
            MarkdownRenderer.tableCellDetailTitle(columnHeader: "Status", columnIndex: 1, rowIndex: 0),
            "Status - Row 1"
        )
        XCTAssertEqual(
            MarkdownRenderer.tableCellDetailTitle(columnHeader: "", columnIndex: 0, rowIndex: 2),
            "Column 1 - Row 3"
        )
        XCTAssertEqual(
            MarkdownRenderer.tableCellDetailTitle(columnHeader: "Notes", columnIndex: 2, rowIndex: nil),
            "Notes"
        )
    }

    func test_blocksParseHorizontalRules() throws {
        let blocks = MarkdownRenderer.blocks(
            from: """
            Before

            ---

            After
            """
        )

        XCTAssertEqual(blocks, [
            .paragraph("Before"),
            .horizontalRule,
            .paragraph("After"),
        ])
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
