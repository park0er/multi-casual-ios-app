import Foundation
import UniformTypeIdentifiers

public enum AttachmentImportError: LocalizedError, Sendable {
    case emptyData
    case unreadableImage

    public var errorDescription: String? {
        switch self {
        case .emptyData:
            "Attachment is empty."
        case .unreadableImage:
            "Unable to load selected image."
        }
    }
}

public struct AttachmentPayload: Sendable {
    public let filename: String
    public let data: Data
    public let contentType: String

    public init(filename: String, data: Data, contentType: String) {
        self.filename = filename
        self.data = data
        self.contentType = contentType
    }
}

public enum AttachmentImport {
    public static func payload(from url: URL) throws -> AttachmentPayload {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let filename = url.lastPathComponent.isEmpty ? "attachment" : url.lastPathComponent
        let contentType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        return AttachmentPayload(filename: filename, data: data, contentType: contentType)
    }

    public static func imagePayload(
        data: Data,
        contentType: UTType?,
        filenamePrefix: String = "image",
        date: Date = Date()
    ) throws -> AttachmentPayload {
        guard !data.isEmpty else {
            throw AttachmentImportError.emptyData
        }

        let resolvedType = contentType?.conforms(to: .image) == true ? contentType : .jpeg
        let fileExtension = resolvedType?.preferredFilenameExtension ?? "jpg"
        let mimeType = resolvedType?.preferredMIMEType ?? "image/jpeg"
        let filename = "\(filenamePrefix)-\(imageFilenameTimestamp(from: date)).\(fileExtension)"
        return AttachmentPayload(filename: filename, data: data, contentType: mimeType)
    }

    private static func imageFilenameTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
