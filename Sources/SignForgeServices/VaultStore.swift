import Foundation
import Observation

@Observable
final class VaultStore {
    private let url: URL
    var state: SignForgeState

    init(url: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("signforge-vault.json")) {
        self.url = url
        if let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder.signForge.decode(SignForgeState.self, from: data) {
            state = decoded
        } else {
            state = .preview
        }
    }

    func save() {
        guard let data = try? JSONEncoder.signForge.encode(state) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    func addArtifact(_ artifact: ArtifactRecord) {
        state.artifacts.insert(artifact, at: 0)
        state.audit.insert(AuditEvent(message: "Created artifact: \(artifact.name)"), at: 0)
        save()
    }
}

extension JSONEncoder {
    static var signForge: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var signForge: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
