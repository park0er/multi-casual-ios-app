#if canImport(SwiftUI)
import SwiftUI

public enum MarkdownRenderer {
    public enum Block: Equatable {
        case paragraph(String)
        case heading(level: Int, text: String)
        case unorderedList([String])
        case orderedList([String])
        case quote(String)
        case codeBlock(String)
        case table(headers: [String], rows: [[String]])
        case horizontalRule
    }

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

    public static func blocks(from markdown: String) -> [Block] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        var parser = BlockParser(lines: normalized.components(separatedBy: "\n"))
        let blocks = parser.parse()
        return blocks.isEmpty ? [.paragraph("")] : blocks
    }

    public static func tableCellDetailTitle(columnHeader: String, columnIndex: Int, rowIndex: Int?) -> String {
        let trimmedHeader = columnHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        let columnTitle = trimmedHeader.isEmpty ? "Column \(columnIndex + 1)" : trimmedHeader
        if let rowIndex {
            return "\(columnTitle) - Row \(rowIndex + 1)"
        }
        return columnTitle
    }
}

public struct MarkdownText: View {
    private let markdown: String
    @Environment(\.appLanguage) private var appLanguage

    public init(_ markdown: String) {
        self.markdown = markdown
    }

    public var body: some View {
        let localizedMarkdown = AppStrings.localized(markdown, language: appLanguage)
        let blocks = MarkdownRenderer.blocks(from: localizedMarkdown)
        if blocks.count == 1, case .paragraph(let text) = blocks[0] {
            Text(MarkdownRenderer.attributedString(from: text))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    MarkdownBlockView(block: block)
                }
            }
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownRenderer.Block
    @State private var selectedTableCell: MarkdownTableCellDetail?

    var body: some View {
        switch block {
        case .paragraph(let text):
            Text(MarkdownRenderer.attributedString(from: text))
        case .heading(let level, let text):
            Text(MarkdownRenderer.attributedString(from: text))
                .font(font(forHeadingLevel: level))
        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•")
                        Text(MarkdownRenderer.attributedString(from: item))
                    }
                }
            }
        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(index + 1).")
                            .monospacedDigit()
                        Text(MarkdownRenderer.attributedString(from: item))
                    }
                }
            }
        case .quote(let text):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 3)
                Text(MarkdownRenderer.attributedString(from: text))
                    .foregroundStyle(.secondary)
            }
        case .codeBlock(let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        case .table(let headers, let rows):
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    MarkdownTableRow(
                        cells: headers,
                        headers: headers,
                        rowIndex: nil,
                        isHeader: true
                    ) { detail in
                        selectedTableCell = detail
                    }
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                        MarkdownTableRow(
                            cells: row,
                            headers: headers,
                            rowIndex: rowIndex,
                            isHeader: false
                        ) { detail in
                            selectedTableCell = detail
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                }
            }
            .sheet(item: $selectedTableCell) { detail in
                MarkdownTableCellDetailSheet(detail: detail)
                    .presentationDragIndicator(.visible)
            }
        case .horizontalRule:
            Divider()
                .padding(.vertical, 4)
        }
    }

    private func font(forHeadingLevel level: Int) -> Font {
        switch level {
        case 1:
            .title3.weight(.semibold)
        case 2:
            .headline.weight(.semibold)
        default:
            .subheadline.weight(.semibold)
        }
    }
}

private struct MarkdownTableRow: View {
    let cells: [String]
    let headers: [String]
    let rowIndex: Int?
    let isHeader: Bool
    let onSelect: (MarkdownTableCellDetail) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { columnIndex, cell in
                Button {
                    onSelect(
                        MarkdownTableCellDetail(
                            title: MarkdownRenderer.tableCellDetailTitle(
                                columnHeader: headers.indices.contains(columnIndex) ? headers[columnIndex] : "",
                                columnIndex: columnIndex,
                                rowIndex: rowIndex
                            ),
                            content: cell
                        )
                    )
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Text(MarkdownRenderer.attributedString(from: cell))
                            .font(isHeader ? .caption.weight(.semibold) : .caption)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(minWidth: 120, maxWidth: 220, minHeight: 34, alignment: .topLeading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(isHeader ? Color.secondary.opacity(0.12) : Color.clear)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.16))
                            .frame(width: 1)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.16))
                            .frame(height: 1)
                    }
            }
        }
    }
}

private struct MarkdownTableCellDetail: Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

private struct MarkdownTableCellDetailSheet: View {
    let detail: MarkdownTableCellDetail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                MarkdownText(detail.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(detail.title)
            .markdownTableCellNavigationTitleMode()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func markdownTableCellNavigationTitleMode() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

private struct BlockParser {
    var lines: [String]
    private var index = 0
    private var blocks: [MarkdownRenderer.Block] = []
    private var paragraphLines: [String] = []

    init(lines: [String]) {
        self.lines = lines
    }

    mutating func parse() -> [MarkdownRenderer.Block] {
        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flushParagraph()
                index += 1
            } else if let fence = codeFenceMarker(in: line) {
                flushParagraph()
                parseCodeBlock(openingFence: fence)
            } else if let heading = heading(in: line) {
                flushParagraph()
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
            } else if isHorizontalRule(line) {
                flushParagraph()
                blocks.append(.horizontalRule)
                index += 1
            } else if isTableStart(at: index) {
                flushParagraph()
                parseTable()
            } else if isQuoteLine(line) {
                flushParagraph()
                parseQuote()
            } else if unorderedListItem(in: line) != nil {
                flushParagraph()
                parseUnorderedList()
            } else if orderedListItem(in: line) != nil {
                flushParagraph()
                parseOrderedList()
            } else {
                paragraphLines.append(line)
                index += 1
            }
        }

        flushParagraph()
        return blocks
    }

    private mutating func flushParagraph() {
        guard !paragraphLines.isEmpty else { return }
        blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
        paragraphLines.removeAll()
    }

    private mutating func parseCodeBlock(openingFence: String) {
        index += 1
        var codeLines: [String] = []
        while index < lines.count {
            let line = lines[index]
            if codeFenceMarker(in: line) == openingFence {
                index += 1
                break
            }
            codeLines.append(line)
            index += 1
        }
        blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
    }

    private mutating func parseQuote() {
        var quoteLines: [String] = []
        while index < lines.count, isQuoteLine(lines[index]) {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            quoteLines.append(content)
            index += 1
        }
        blocks.append(.quote(quoteLines.joined(separator: "\n")))
    }

    private mutating func parseUnorderedList() {
        var items: [String] = []
        while index < lines.count, let item = unorderedListItem(in: lines[index]) {
            items.append(item)
            index += 1
        }
        blocks.append(.unorderedList(items))
    }

    private mutating func parseOrderedList() {
        var items: [String] = []
        while index < lines.count, let item = orderedListItem(in: lines[index]) {
            items.append(item)
            index += 1
        }
        blocks.append(.orderedList(items))
    }

    private mutating func parseTable() {
        let headers = tableCells(in: lines[index])
        index += 2

        var rows: [[String]] = []
        while index < lines.count {
            let line = lines[index]
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { break }
            let cells = tableCells(in: line)
            guard cells.count >= 2 else { break }
            rows.append(normalizedTableRow(cells, columnCount: headers.count))
            index += 1
        }
        blocks.append(.table(headers: headers, rows: rows))
    }

    private func codeFenceMarker(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") {
            return "```"
        }
        if trimmed.hasPrefix("~~~") {
            return "~~~"
        }
        return nil
    }

    private func heading(in line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let hashes = trimmed.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes),
              trimmed.dropFirst(hashes).first == " "
        else {
            return nil
        }
        return (hashes, String(trimmed.dropFirst(hashes + 1)))
    }

    private func isQuoteLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let compact = line.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let marker = compact.first else { return false }
        guard marker == "-" || marker == "*" || marker == "_" else { return false }
        return compact.allSatisfy { $0 == marker }
    }

    private func unorderedListItem(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > 2 else { return nil }
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            return String(trimmed.dropFirst(2))
        }
        return nil
    }

    private func orderedListItem(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let number = trimmed[..<dotIndex]
        guard !number.isEmpty,
              number.allSatisfy(\.isNumber),
              trimmed.index(after: dotIndex) < trimmed.endIndex,
              trimmed[trimmed.index(after: dotIndex)] == " "
        else {
            return nil
        }
        return String(trimmed[trimmed.index(dotIndex, offsetBy: 2)...])
    }

    private func isTableStart(at index: Int) -> Bool {
        guard index + 1 < lines.count else { return false }
        let headers = tableCells(in: lines[index])
        guard headers.count >= 2 else { return false }
        return isTableDelimiter(lines[index + 1], columnCount: headers.count)
    }

    private func tableCells(in line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }
        return trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func isTableDelimiter(_ line: String, columnCount: Int) -> Bool {
        let cells = tableCells(in: line)
        guard cells.count == columnCount else { return false }
        return cells.allSatisfy { cell in
            let compact = cell.replacingOccurrences(of: " ", with: "")
            return compact.contains("-") && compact.allSatisfy { $0 == "-" || $0 == ":" }
        }
    }

    private func normalizedTableRow(_ cells: [String], columnCount: Int) -> [String] {
        if cells.count == columnCount {
            return cells
        }
        if cells.count > columnCount {
            return Array(cells.prefix(columnCount))
        }
        return cells + Array(repeating: "", count: columnCount - cells.count)
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
