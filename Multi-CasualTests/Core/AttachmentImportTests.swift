import UniformTypeIdentifiers
import XCTest
@testable import MultiCasual

final class AttachmentImportTests: XCTestCase {
    func test_imagePayloadBuildsStableImageFilenameAndContentType() throws {
        let date = ISO8601DateFormatter().date(from: "2026-05-17T03:04:05Z")!

        let payload = try AttachmentImport.imagePayload(
            data: Data([0x89, 0x50, 0x4e, 0x47]),
            contentType: .png,
            filenamePrefix: "issue-image",
            date: date
        )

        XCTAssertEqual(payload.filename, "issue-image-20260517-030405.png")
        XCTAssertEqual(payload.contentType, "image/png")
        XCTAssertEqual(payload.data, Data([0x89, 0x50, 0x4e, 0x47]))
    }

    func test_imagePayloadFallsBackToJPEGForNonImageContentType() throws {
        let date = ISO8601DateFormatter().date(from: "2026-05-17T03:04:05Z")!

        let payload = try AttachmentImport.imagePayload(
            data: Data("not-empty".utf8),
            contentType: .plainText,
            filenamePrefix: "comment-image",
            date: date
        )

        XCTAssertEqual(payload.filename, "comment-image-20260517-030405.jpeg")
        XCTAssertEqual(payload.contentType, "image/jpeg")
    }

    func test_imagePayloadRejectsEmptyImageData() {
        XCTAssertThrowsError(
            try AttachmentImport.imagePayload(data: Data(), contentType: .png)
        ) { error in
            XCTAssertEqual(error.localizedDescription, "Attachment is empty.")
        }
    }

    func test_issueCreationAndCommentsExposePhotoPickers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let createSource = try String(
            contentsOf: root.appendingPathComponent("Multi-Casual/Features/Issues/IssueCreateSheet.swift")
        )
        let detailSource = try String(
            contentsOf: root.appendingPathComponent("Multi-Casual/Features/Issues/IssueDetailView.swift")
        )

        XCTAssertTrue(createSource.contains("PhotosPicker("))
        XCTAssertTrue(createSource.contains("IssueCreateAddImageButton"))
        XCTAssertTrue(detailSource.contains("IssueDetailAddCommentImageButton"))
        XCTAssertTrue(detailSource.contains("CommentReplyAddImageButton"))
    }
}
