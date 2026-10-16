# Cask for the bannzai/homebrew-tap tap. The version and sha256 below are placeholders: the release
# workflow (.github/workflows/release.yml) attaches a copy with the released version and the DMG's
# checksum to each GitHub release. Publishing steps: documents/macos-distribution.md.
cask "pastecheck" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/bannzai/pastecheck/releases/download/v#{version}/PasteCheck-#{version}.dmg"
  name "PasteCheck"
  desc "Menu bar app that warns when copied text or images contain secrets"
  homepage "https://bannzai.github.io/pastecheck/"

  # MACOSX_DEPLOYMENT_TARGET of the macOS app.
  depends_on macos: :sequoia

  app "PasteCheck.app"

  # The app is sandboxed, so its settings and warning counts live in its container.
  zap trash: "~/Library/Containers/com.bannzai.PasteCheck"
end
