import Foundation

enum ArtifactPayload: Codable, Hashable {
    case text(String)
    case base64(String)
    case manifest([String: String])

    var exportText: String {
        switch self {
        case .text(let value): return value
        case .base64(let value): return value
        case .manifest(let values):
            return values.keys.sorted().map { "\($0)=\(values[$0] ?? "")" }.joined(separator: "\n")
        }
    }
}

struct ExportPackage: Codable, Hashable {
    var filename: String
    var payload: ArtifactPayload
}
