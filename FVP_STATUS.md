# FVP status

SignForge is implemented as a private iOS signing workstation with an optional localhost helper for operations that iOS public APIs do not expose directly.

## Implemented locally in the iOS app

- App Store Connect API credential capture and Keychain storage
- ES256 JWT generation for App Store Connect API keys
- App Store Connect request client for health check, certificates, bundle IDs, devices, and profiles
- RSA 2048 Keychain key generation
- PKCS#10 CSR DER/PEM generation signed by the local private key
- `.mobileprovision` plist extraction and parsing
- artifact vault, audit log, validation engine, and project dashboard
- Files import for provisioning profiles
- Files export for CSR, CI manifests, and IPA resign plans
- live screens for certificates, bundle IDs, devices, profiles, P12 package planning, and IPA signing plans

## Implemented as optional helper bridge

- localhost JSON bridge from iOS app to helper
- helper endpoint for `.p12` export using OpenSSL
- helper endpoint scaffold for IPA resigning, requiring macOS `codesign`

## Not pushed

The current FVP expansion is committed only in the local repo at `/root/SignForge`. It has not been pushed to GitHub after the previous green baseline.

## Remaining hardening before real personal use

- wire the P12 screen to collect certificate PEM/private key PEM and call `SigningHelperClient.exportP12`
- complete macOS helper IPA resigning: unzip IPA, replace embedded profile, merge entitlements, import identity, run `codesign`, zip IPA
- add revocation/delete operations for Apple API assets
- add stronger migration for older vault JSON shapes
- run GitHub Actions after explicit push approval
