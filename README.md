# SignForge

SignForge is a local-first iOS workstation for Apple signing assets. It is designed for private/internal distribution, not App Store review.

## Scope

- Apple Developer API credential management
- private key and CSR workflow
- certificate inventory and .p12 export planning
- bundle ID, device, and provisioning profile management
- .mobileprovision parsing and validation
- artifact vault and project workspaces
- IPA resigning workflow surface
- CI signing package helpers

The project does not create fake Apple certificates or bypass Apple issuance. Apple-issued certificates and profiles still require a valid Apple Developer Program account.

## Build

This repo uses XcodeGen.

```sh
xcodegen generate
xcodebuild -scheme SignForge -destination 'platform=iOS Simulator,name=iPhone 17' build
```

The GitHub Actions workflow generates the project on macOS and runs a simulator build.

## FVP architecture

The iOS app owns the local developer workflow: credentials, Keychain keys, CSR generation, Apple API calls, profile parsing, validation, artifact history, and export manifests. Pure public iOS APIs do not provide a complete PKCS#12 export or IPA `codesign` toolchain, so the repo also includes an optional localhost helper in `Tools/signforge-helper` for those operations.
