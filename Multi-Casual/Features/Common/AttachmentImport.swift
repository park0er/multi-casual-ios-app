import Foundation
import UniformTypeIdentifiers

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
}
