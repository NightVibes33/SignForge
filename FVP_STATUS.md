# FVP status

SignForge is implemented as a private iOS signing workstation with an optional localhost helper for operations that iOS public APIs do not expose directly.

## Implemented locally in the iOS app

- App Store Connect API credential capture and Keychain storage
- ES256 JWT generation for App Store Connect API keys
- App Store Connect request client for health check, certificate creation/revocation, bundle ID listing/creation/deletion, device registration, and provisioning profile creation/deletion
- RSA 2048 Keychain key generation
- PKCS#10 CSR DER/PEM generation signed by the local private key
- Apple certificate content storage for P12 export
- `.mobileprovision` plist extraction, profile parsing, and entitlements extraction
- artifact vault, audit log, validation engine, project dashboard, and entitlements diff screen
- Files import for provisioning profiles, IPAs, and P12 files
- Files export for CSR, `.p12`, CI manifests, IPA resign plans, and signed IPAs
- live screens for certificates, bundle IDs, devices, profiles, P12 export, IPA signing, diagnostics, and security status

## Implemented as optional helper bridge

- localhost JSON bridge from iOS app to helper
- helper endpoint for `.p12` export using OpenSSL
- helper endpoint for IPA resigning on macOS: unzip IPA, replace embedded profile, create temporary keychain, import P12, run `codesign`, and zip signed IPA
- helper unit tests for failure surfacing and environment-gated resign behavior

## Not pushed

The current FVP expansion is committed only in the local repo at `/root/SignForge`. It has not been pushed to GitHub after the previous green baseline.

## Remaining hardening before real personal use

- add explicit profile/certificate selection instead of using latest/first records in some flows
- improve older vault JSON migrations beyond Codable optional defaults
- run GitHub Actions after explicit push approval
