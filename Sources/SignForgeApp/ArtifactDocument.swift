import SwiftUI
import UniformTypeIdentifiers

struct ArtifactDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .json, .data] }
    var text: String

    init(text: String = "") { self.text = text }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents, let value = String(data: data, encoding: .utf8) {
            text = value
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
