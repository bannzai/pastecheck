#!/bin/bash
# Archives the Release build of the app and exports it signed with the Developer ID Application
# certificate.
#
# The signing settings are given on the command line instead of in the project, so that only this
# path uses Developer ID: CI and simtunnel keep building with the project's ad-hoc signing
# (documents/PROJECT.md, the signing row of "Technology stack and infrastructure decisions").
#
# Both the archive and the export use manual signing, so neither an Apple Development certificate,
# a registered Mac, nor cloud signing is involved: the same commands run on a developer's Mac and on
# a CI runner whose keychain holds only the Developer ID certificate. No provisioning profile is
# used, because the app's only entitlement, com.apple.security.app-sandbox, is not restricted:
# "A Mac app that uses no restricted entitlements doesn't need a provisioning profile", and the
# unrestricted ones include those "used to enable and configure the App Sandbox"
# (https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles).
#
# The hardened runtime is turned on here because notarization requires it ("Enable the Hardened
# Runtime capability for your app", https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
#
# Idempotent: the previous archive and export are replaced.
set -euo pipefail
source "$(dirname "$0")/_developer_id_common.sh"

require_commands xcodebuild codesign security plutil jq
DEVELOPMENT_TEAM="$(developer_id_team)"
EXPORT_OPTIONS="${DISTRIBUTION_DIRECTORY}/ExportOptions.plist"

# Fails unless the app is signed by the team's Developer ID Application identity with the hardened
# runtime, keeps the App Sandbox, and does not carry com.apple.security.get-task-allow, which
# notarization rejects (https://developer.apple.com/documentation/security/resolving-common-notarization-issues).
verify_exported_app() {
  local signature entitlements
  codesign --verify --deep --strict --verbose=2 "${EXPORTED_APP}"
  signature="$(codesign --display --verbose=2 "${EXPORTED_APP}" 2>&1)"
  if ! grep -q "^Authority=Developer ID Application: .*(${DEVELOPMENT_TEAM})$" <<< "${signature}"; then
    echo "Error: ${EXPORTED_APP} is not signed with the Developer ID Application identity of ${DEVELOPMENT_TEAM}" >&2
    exit 1
  fi
  if ! grep -q '^CodeDirectory .*(runtime)' <<< "${signature}"; then
    echo "Error: ${EXPORTED_APP} is not signed with the hardened runtime" >&2
    exit 1
  fi
  entitlements="$(codesign --display --entitlements - --xml "${EXPORTED_APP}" 2> /dev/null | plutil -convert json -o - -)"
  if ! jq -e '.["com.apple.security.app-sandbox"] == true and (has("com.apple.security.get-task-allow") | not)' <<< "${entitlements}" > /dev/null; then
    echo "Error: ${EXPORTED_APP} must have com.apple.security.app-sandbox and must not have com.apple.security.get-task-allow" >&2
    echo "${entitlements}" >&2
    exit 1
  fi
  echo "Verified ${EXPORTED_APP}: Developer ID Application (${DEVELOPMENT_TEAM}), hardened runtime, App Sandbox, no get-task-allow"
}

rm -rf "${ARCHIVE_PATH}" "${EXPORT_DIRECTORY}"
mkdir -p "${DISTRIBUTION_DIRECTORY}"

xcodebuild -project PasteCheck.xcodeproj -scheme PasteCheck -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${DERIVED_DATA_DIRECTORY}" \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
  ENABLE_HARDENED_RUNTIME=YES \
  archive

# The export re-signs the app with a secure timestamp and strips get-task-allow.
jq -n --arg team "${DEVELOPMENT_TEAM}" \
  '{method: "developer-id", teamID: $team, signingStyle: "manual", signingCertificate: "Developer ID Application"}' \
  | plutil -convert xml1 -o "${EXPORT_OPTIONS}" -
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_DIRECTORY}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}"

verify_exported_app
