# SignForge FVP

SignForge is a direct SideStore-based fork focused on iOS signing workflows.

## Included

- SideStore project, storyboard, tab bar, install, refresh, minimuxer, and AltSign codebase remain in-tree.
- SignForge product identity is set in `Build.xcconfig`.
- First-run UI is replaced with a SignForge signing workstation while keeping SideStore runtime foundations.
- File intake supports `Account.sideconf`, `.p12`/`.pfx`, `.mobileprovision`/`.provisionprofile`, and unsigned `.ipa` files.
- `Account.sideconf` uses SideStore's existing `ImportedAccount` shape, including certificate payload and certificate password fields.
- Mobile provisioning profiles are inspected locally for readable metadata.
- The fork preserves SideStore's AGPL-3.0 license.

## Verification Required Before Push

- Xcode/macOS 26 build of the SideStore fork target.
- Unsigned real-device IPA artifact packaging.
- Device install smoke test on an iOS 26 device or simulator-equivalent install validation where available.
- UI screenshot pass on compact and large iPhone sizes.
