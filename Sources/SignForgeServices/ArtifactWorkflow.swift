import Foundation

struct ArtifactWorkflow {
    let crypto = SigningCrypto()
    let profileParser = MobileProvisionParser()

    func makeCSR(commonName: String, organization: String, country: String, key: SigningKey) -> (ArtifactRecord, ExportPackage) {
        let csr = (try? crypto.generateCSR(commonName: commonName, organization: organization, country: country, key: key)) ?? "CSR generation failed"
        let filename = commonName.replacingOccurrences(of: " ", with: "-") + ".csr"
        return (ArtifactRecord(name: filename, kind: .csr, detail: csr), ExportPackage(filename: filename, payload: .text(csr)))
    }

    func importMobileProvision(data: Data, filename: String) -> ProvisioningProfileRecord {
        profileParser.parse(data: data, fallbackName: filename)
    }

    func makeCIManifest(credential: AppleCredential, certificate: CertificateRecord?, profile: ProvisioningProfileRecord?) -> ExportPackage {
        var manifest: [String: String] = [
            "APP_STORE_CONNECT_ISSUER_ID": credential.issuerID,
            "APP_STORE_CONNECT_KEY_ID": credential.keyID,
            "APPLE_TEAM_ID": credential.teamID
        ]
        if let certificate { manifest["SIGNING_CERTIFICATE_SHA256"] = certificate.fingerprint }
        if let profile { manifest["PROVISIONING_PROFILE_UUID"] = profile.uuid }
        return ExportPackage(filename: "signforge-ci.env", payload: .manifest(manifest))
    }

    func makeIPAResignManifest(bundleIdentifier: String, profile: ProvisioningProfileRecord?, certificate: CertificateRecord?) -> ExportPackage {
        ExportPackage(filename: "ipa-resign-plan.json", payload: .manifest([
            "bundle_identifier": bundleIdentifier,
            "profile_uuid": profile?.uuid ?? "missing",
            "certificate_fingerprint": certificate?.fingerprint ?? "missing",
            "status": profile == nil || certificate == nil ? "blocked" : "ready"
        ]))
    }
}
