# macOS distribution

PasteCheck is distributed outside the Mac App Store first: it is signed with a Developer ID certificate, notarized, published as a DMG on GitHub Releases, and installed through a Homebrew cask in https://github.com/bannzai/homebrew-tap . The decision is in [DIRECTION.md](DIRECTION.md) ("decisions", 2026-10-11) and the distribution row of [PROJECT.md](PROJECT.md) "Technology stack and infrastructure decisions". There is no automatic update (no Sparkle); a new version is installed with `brew upgrade` or a new DMG.

```text
make dmg
├── scripts/macos/export_developer_id.sh   Release archive, Developer ID export, signature checks
└── scripts/macos/notarize_and_dmg.sh      DMG, notarization, stapling, Gatekeeper checks
      │
      ▼
tmp/distribution/PasteCheck-<version>.dmg
      │  started by hand: .github/workflows/release.yml runs make dmg on a GitHub runner for the tag v<version>
      ▼
GitHub release with PasteCheck-<version>.dmg and pastecheck.rb (Casks/pastecheck.rb with the version and checksum filled in)
      │  pastecheck.rb copied to bannzai/homebrew-tap
      ▼
brew install --cask bannzai/tap/pastecheck
```

Why each script signs the way it does is explained in the comments at the top of the script. Developer ID signing is used only on this path: CI and simtunnel build with the project's ad-hoc signing, and `make dmg` passes the Developer ID settings on the `xcodebuild` command line.

## Prerequisites

1. A Developer ID Application certificate of the team, with its private key, in the keychain of the Mac that builds. Apple lists "Required role: Account Holder" for creating one (https://developer.apple.com/help/account/create-certificates/create-developer-id-certificates); create it at https://developer.apple.com/account/resources/certificates/add . Check with:

   ```sh
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

   The project sets no team, so the scripts sign with the team of that identity. When the keychain holds Developer ID Application identities of more than one team, set `DEVELOPMENT_TEAM` to the one to use.

2. An App Store Connect team API key (https://appstoreconnect.apple.com/access/integrations/api), exported as environment variables. It authenticates `notarytool`:

   | Variable | Value |
   | --- | --- |
   | `ASC_API_KEY_ID` | Key ID |
   | `ASC_API_KEY_ISSUER_ID` | Issuer ID |
   | `ASC_API_KEY_P8_BASE64` | The downloaded `AuthKey_<Key ID>.p8`, base64-encoded (`base64 -i AuthKey_<Key ID>.p8`) |

No provisioning profile is needed. The app's only entitlement is the App Sandbox, and Apple's TN3125 says "A Mac app that uses no restricted entitlements doesn't need a provisioning profile", listing the entitlements "used to enable and configure the App Sandbox" among the unrestricted ones (https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles).

## Building a DMG

```sh
make dmg
```

The result is `tmp/distribution/PasteCheck-<version>.dmg`, where the version is `MARKETING_VERSION` of the app. The export is checked to be signed by the team's Developer ID Application identity with the hardened runtime, to keep the App Sandbox, and not to carry `com.apple.security.get-task-allow`. Notarization requires the first two ("Use a “Developer ID” application ... certificate", "Enable the Hardened Runtime capability", https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and rejects the last (https://developer.apple.com/documentation/security/resolving-common-notarization-issues). The last steps print the Gatekeeper checks it passed and the DMG's SHA-256:

```sh
spctl --assess --type open --context context:primary-signature --verbose=2 tmp/distribution/PasteCheck-<version>.dmg
xcrun stapler validate tmp/distribution/PasteCheck-<version>.dmg
spctl --assess --type execute --verbose=2 tmp/distribution/export/PasteCheck.app
```

Only the DMG is submitted to the notary service and gets a stapled ticket. Apple: "The notary service generates a ticket for the top-level file that you specify, as well as for each nested file", and for software whose ticket is not stapled "Gatekeeper finds the ticket online" (https://developer.apple.com/documentation/security/customizing-the-notarization-workflow). The app inside the read-only DMG cannot have a ticket stapled to it.

`make dmg` uploads the DMG to Apple's notary service.

To see what someone who downloads the DMG sees, mark it as downloaded and open it. Gatekeeper must open it without a warning:

```sh
xattr -w com.apple.quarantine "0083;$(printf %x "$(date +%s)");Safari;" tmp/distribution/PasteCheck-<version>.dmg
open tmp/distribution/PasteCheck-<version>.dmg
```

## Releasing

### Repository secrets

`.github/workflows/release.yml` reads these secrets, and its first step fails with the names of any that are missing:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_APPLICATION_P12_BASE64` | The Developer ID Application certificate and its private key exported as a `.p12` file, base64-encoded |
| `DEVELOPER_ID_APPLICATION_P12_PASSWORD` | The password chosen when exporting the `.p12` file |
| `ASC_API_KEY_ID` | Same as the environment variable |
| `ASC_API_KEY_ISSUER_ID` | Same as the environment variable |
| `ASC_API_KEY_P8_BASE64` | Same as the environment variable |

Export the `.p12` file from Keychain Access: in the login keychain, open My Certificates, select "Developer ID Application: … (<team ID>)", and choose File > Export Items, so that only that identity is exported. Then register the secrets without printing their values, and delete the exported file:

```sh
base64 -i DeveloperIDApplication.p12 | gh secret set DEVELOPER_ID_APPLICATION_P12_BASE64 -R bannzai/pastecheck
gh secret set DEVELOPER_ID_APPLICATION_P12_PASSWORD -R bannzai/pastecheck  # prompts for the value
test -n "$ASC_API_KEY_ID" && printf '%s' "$ASC_API_KEY_ID" | gh secret set ASC_API_KEY_ID -R bannzai/pastecheck
test -n "$ASC_API_KEY_ISSUER_ID" && printf '%s' "$ASC_API_KEY_ISSUER_ID" | gh secret set ASC_API_KEY_ISSUER_ID -R bannzai/pastecheck
test -n "$ASC_API_KEY_P8_BASE64" && printf '%s' "$ASC_API_KEY_P8_BASE64" | gh secret set ASC_API_KEY_P8_BASE64 -R bannzai/pastecheck
gh secret list -R bannzai/pastecheck
```

### Publishing a version

The workflow runs only when started by hand (`workflow_dispatch`). A trigger on tag pushes is added once bannzai decides to go public after trying a released build.

1. Set the version in `MARKETING_VERSION` of the project and merge it into `main`.
2. Push a tag named after the version. `gh release create --verify-tag` needs the tag on GitHub, and the workflow builds the tagged commit.

   ```sh
   git tag v<version>
   git push origin v<version>
   ```

3. Start the workflow. It fails before building when the version is not of the form `1.2.3`, a secret is missing, the tag does not exist, or the tag's `MARKETING_VERSION` differs from the version.

   ```sh
   gh workflow run release.yml -R bannzai/pastecheck -f version=<version>
   gh run list -R bannzai/pastecheck --workflow release.yml --limit 3
   gh run watch -R bannzai/pastecheck <run ID from the list>
   ```

4. The workflow runs `make dmg` and publishes the release with `PasteCheck-<version>.dmg` and `pastecheck.rb`. Once the DMG is published, running it again for the same version fails before building: a rebuilt DMG has a different checksum and would break the cask already in the tap, so release a new version instead. A run that failed before uploading the DMG can be run again.

### Updating the Homebrew tap

The cask lives in https://github.com/bannzai/homebrew-tap . `Casks/pastecheck.rb` in this repository is its source; the copy attached to each release has the real version and checksum. In a checkout of the tap:

```sh
gh release download v<version> -R bannzai/pastecheck -p pastecheck.rb -D Casks --clobber
git add Casks/pastecheck.rb
git commit -m "pastecheck <version>"
git push
```

The tap's audit workflow (`.github/workflows/audit.yml`) runs `brew audit` for each cask it names; add `bannzai/tap/pastecheck` to it when the cask is first added.

People install the app with:

```sh
brew install --cask bannzai/tap/pastecheck
```

Installing with the fully qualified name trusts this cask only: "Installing a fully qualified formula or cask name trusts only that item" (https://docs.brew.sh/Tap-Trust).

## Troubleshooting

- **Notarization is not accepted.** `notarize_and_dmg.sh` prints the notary log, which names every rejected file and the reason.
- **`codesign` cannot find the identity on a CI runner.** Check that `DEVELOPER_ID_APPLICATION_P12_BASE64` contains the private key: a `.p12` exported from the certificate alone does not.
- **The scripts report identities of more than one team.** Set `DEVELOPMENT_TEAM` to the team ID to sign with.
