import XCTest

final class MarkdownCoverageTests: XCTestCase {
    func test_dynamicUserAndBackendTextUsesMarkdownRendering() throws {
        let sourceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let forbiddenPatterns: [(path: String, pattern: String)] = [
            (
                "Multi-Casual/Features/Auth/OTPView.swift",
                #"            Text("We sent a code to **"#
            ),
            (
                "Multi-Casual/Features/Issues/IssueCreateSheet.swift",
                "                        LabeledContent(assignee.subtitle"
            ),
            (
                "Multi-Casual/Features/Settings/AgentsView.swift",
                #"                        LabeledContent("Runtime", value: agent?.runtimeId"#
            )
        ]

        for forbidden in forbiddenPatterns {
            let fileURL = sourceRoot.appendingPathComponent(forbidden.path)
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertFalse(
                source.contains(forbidden.pattern),
                "\(forbidden.path) still renders dynamic text without Markdown support."
            )
        }
    }
}
