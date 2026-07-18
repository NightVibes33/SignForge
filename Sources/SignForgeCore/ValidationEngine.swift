import Foundation

struct ValidationFinding: Identifiable, Hashable {
    enum Severity: String { case ready = "Ready", warning = "Warning", blocked = "Blocked" }
    var id = UUID()
    var severity: Severity
    var title: String
    var detail: String
}

struct ValidationEngine {
    func findings(for workspace: ProjectWorkspace, state: SignForgeState) -> [ValidationFinding] {
        var findings: [ValidationFinding] = []
        let cert = state.certificates.first { $0.id == workspace.selectedCertificateID }
        let profile = state.profiles.first { $0.id == workspace.selectedProfileID }
        if cert == nil { findings.append(.init(severity: .blocked, title: "Missing certificate", detail: "Select an Apple-issued signing certificate.")) }
        if profile == nil { findings.append(.init(severity: .blocked, title: "Missing profile", detail: "Select a provisioning profile.")) }
        if let cert, cert.expiresAt < Date() { findings.append(.init(severity: .blocked, title: "Certificate expired", detail: cert.name)) }
        if let profile, profile.expiresAt < Date() { findings.append(.init(severity: .blocked, title: "Profile expired", detail: profile.name)) }
        if let profile, profile.bundleIdentifier != workspace.bundleIdentifier { findings.append(.init(severity: .blocked, title: "Bundle mismatch", detail: profile.bundleIdentifier)) }
        if let cert, let profile, !profile.certificateFingerprints.contains(cert.fingerprint) { findings.append(.init(severity: .warning, title: "Certificate not embedded", detail: "Regenerate the profile with this certificate.")) }
        if findings.isEmpty { findings.append(.init(severity: .ready, title: "Signing ready", detail: "Certificate, profile, and bundle ID align.")) }
        return findings
    }
}
