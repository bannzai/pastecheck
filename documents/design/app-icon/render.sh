#!/bin/bash
# Renders the chosen app icon SVG into the 10 PNGs of PasteCheck/Assets.xcassets/AppIcon.appiconset.
# Run from the repository root: bash documents/design/app-icon/render.sh
# Needs rsvg-convert (brew install librsvg). Overwrites the PNGs, so running it again gives the same files.
set -euo pipefail

source_svg="documents/design/app-icon/candidates/a-marked-line.svg"
appiconset="PasteCheck/Assets.xcassets/AppIcon.appiconset"

# One file per entry of Contents.json, named after its point size and scale.
for points in 16 32 128 256 512; do
  rsvg-convert --width "$points" --height "$points" "$source_svg" \
    --output "$appiconset/icon_${points}x${points}.png"
  rsvg-convert --width $((points * 2)) --height $((points * 2)) "$source_svg" \
    --output "$appiconset/icon_${points}x${points}@2x.png"
done
