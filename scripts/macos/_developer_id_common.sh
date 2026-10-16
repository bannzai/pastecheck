#!/bin/bash
# Definitions shared by the Developer ID distribution scripts in this directory. The scripts source
# this file; it is not run on its own. The procedure is described in documents/macos-distribution.md.

# Paths below are relative to the repository root, so the scripts work from any directory.
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

# Every intermediate and final product stays under tmp/, which Git ignores.
DISTRIBUTION_DIRECTORY="tmp/distribution"
ARCHIVE_PATH="${DISTRIBUTION_DIRECTORY}/PasteCheck.xcarchive"
EXPORT_DIRECTORY="${DISTRIBUTION_DIRECTORY}/export"
EXPORTED_APP="${EXPORT_DIRECTORY}/PasteCheck.app"
# Same derived data directory as the Makefile.
DERIVED_DATA_DIRECTORY="tmp/DerivedData"

# Exits before any work starts when a command the calling script needs is missing.
require_commands() {
  local command_name
  for command_name in "$@"; do
    if ! command -v "${command_name}" > /dev/null 2>&1; then
      echo "Error: ${command_name} is required" >&2
      exit 2
    fi
  done
}

# Exits when the App Store Connect API key is incomplete. The key authenticates notarytool. The
# values are never printed.
require_asc_api_key() {
  local variable_name
  for variable_name in ASC_API_KEY_ID ASC_API_KEY_ISSUER_ID ASC_API_KEY_P8_BASE64; do
    if [ -z "${!variable_name:-}" ]; then
      echo "Error: ${variable_name} is not set (see documents/macos-distribution.md)" >&2
      exit 2
    fi
  done
}

# Decodes the API private key into a directory that only the current user can read and that is
# removed when the script exits. notarytool reads the key from a file, and a key left in the working
# tree could be picked up by any tool that reads the repository.
# Sets ASC_API_KEY_DIRECTORY and ASC_API_KEY_PATH.
write_asc_api_key_file() {
  ASC_API_KEY_DIRECTORY="$(mktemp -d)"
  trap 'rm -rf "${ASC_API_KEY_DIRECTORY}"' EXIT
  ASC_API_KEY_PATH="${ASC_API_KEY_DIRECTORY}/AuthKey_${ASC_API_KEY_ID}.p8"
  (umask 077 && printf '%s' "${ASC_API_KEY_P8_BASE64}" | base64 --decode > "${ASC_API_KEY_PATH}")
}

# Prints the team that signs the distribution build. The project sets no DEVELOPMENT_TEAM, because
# CI and simtunnel sign ad hoc, so the team is DEVELOPMENT_TEAM from the environment when it is set,
# and otherwise the team of the only Developer ID Application identity in the keychain search list
# (on the release runner, the temporary keychain that holds the imported certificate).
developer_id_team() {
  if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
    printf '%s' "${DEVELOPMENT_TEAM}"
    return 0
  fi
  local teams team_count
  teams="$(security find-identity -v -p codesigning \
    | sed -n 's/.*"Developer ID Application: .*(\([A-Z0-9]*\))"$/\1/p' \
    | sort -u)" || return 1
  team_count="$(grep -c . <<< "${teams}" || true)"
  if [ "${team_count}" -ne 1 ]; then
    echo "Error: found Developer ID Application identities of ${team_count} teams in the keychain search list; set DEVELOPMENT_TEAM to choose one (see documents/macos-distribution.md)" >&2
    return 1
  fi
  printf '%s' "${teams}"
}
