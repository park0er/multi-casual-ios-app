import XCTest
@testable import MultiCasual

@MainActor
final class AppLanguageSettingsTests: XCTestCase {
    func test_languageSettingsPersistSelectedChineseLanguage() {
        let defaults = UserDefaults(suiteName: "AppLanguageSettingsTests.\(UUID().uuidString)")!
        let settings = AppLanguageSettings(userDefaults: defaults)

        settings.language = .zhHans

        XCTAssertEqual(defaults.string(forKey: AppLanguageSettings.defaultsKey), "zh-Hans")
        XCTAssertEqual(AppLanguageSettings(userDefaults: defaults).language, .zhHans)
    }

    func test_chineseLanguageLocalizesCoreIssueDetailLabels() {
        XCTAssertEqual(AppStrings.localized("Comments", language: .zhHans), "评论")
        XCTAssertEqual(AppStrings.localized("Latest Progress", language: .zhHans), "最新进度")
        XCTAssertEqual(AppStrings.localized("Agent Work Details", language: .zhHans), "Agent 工作详情")
        XCTAssertEqual(AppStrings.localized("My Issues", language: .zhHans), "我的 Issues")
    }

    func test_zhHansLocalizableStringsCoverSwiftUILiterals() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let stringsURL = root.appendingPathComponent("Multi-Casual/Resources/zh-Hans.lproj/Localizable.strings")
        let translations = try XCTUnwrap(NSDictionary(contentsOf: stringsURL) as? [String: String])
        let keys = try swiftUILiteralKeys(in: root)
        let missing = keys.filter { translations[$0]?.isEmpty != false }

        XCTAssertEqual(missing, [], "Missing zh-Hans translations for SwiftUI literals.")
    }

    private func swiftUILiteralKeys(in root: URL) throws -> [String] {
        let sourceDirs = [
            root.appendingPathComponent("MultiCasual"),
            root.appendingPathComponent("Multi-CasualHost"),
        ]
        let regex = try NSRegularExpression(
            pattern: #"\b(?:Text|Label|Button|ContentUnavailableView|navigationTitle|Picker|Section|alert)\("((?:\\.|[^"])*)""#
        )
        var keys = Set<String>()

        for sourceDir in sourceDirs {
            guard let enumerator = FileManager.default.enumerator(
                at: sourceDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                if fileURL.path.hasSuffix("Multi-Casual/Features/Common/MarkdownText.swift") {
                    continue
                }
                let source = try String(contentsOf: fileURL)
                let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
                for match in regex.matches(in: source, range: nsRange) {
                    guard let range = Range(match.range(at: 1), in: source) else { continue }
                    keys.insert(String(source[range]))
                }
            }
        }

        return keys.sorted()
    }
}
