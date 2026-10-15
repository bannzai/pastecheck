# App icon and menu bar icon

The app icon and the menu bar icon for https://github.com/bannzai/pastecheck/issues/11 .

## How the app icon is made

No image generation model is used. The icon is a hand-written SVG with flat fills only, rendered to PNG with `rsvg-convert`:

```sh
bash documents/design/app-icon/render.sh
```

The script writes the 10 PNGs listed in `PasteCheck/Assets.xcassets/AppIcon.appiconset/Contents.json` (16, 32, 128, 256 and 512 points at 1x and 2x, so 16 to 1024 pixels). To change the icon, edit the SVG and run the script again; to switch to another candidate, change `source_svg` in the script.

A hand-written SVG was chosen over a generated raster because the 16-pixel size has to stay legible (each shape can be sized for it), and flat SVG shapes cannot pick up the textures listed below.

## Constraints the candidates follow

- One accent color, `#1f6fd6`, from the look decided for the mockups (https://github.com/bannzai/pastecheck/issues/5 : macOS standard look, no brand decoration, one accent color). The other colors are a dark navy (`#16365f`), a light gray (`#eef1f5`), a gray for text lines (`#b9c6d8`) and white.
- Not used: metal, glass or neon textures, glossy 3D, gradients, faces or characters, pastel backgrounds, and a genre symbol with an element added (for example "clipboard + shield").
- The motif comes from what PasteCheck does: it tells where a secret is (line and column) and never shows the value.
- Shape: the artwork sits in a rounded square of 824 x 824 pixels with a corner radius of 185.4, centered on the 1024 x 1024 canvas with 100 transparent pixels on each side. Source of these numbers: an Apple Developer Forums answer, https://developer.apple.com/forums/thread/670578 ("The icon itself should be 824 x 824 with a corner radius of 185.4"). They were not checked against Apple's own production templates. The SVG uses a circular corner radius, not Apple's continuous corner curve.
- Unverified: how macOS 26 displays this icon. macOS 26 puts icons it does not consider the right shape inside a gray rounded square. One forum user reports that the trigger is the alpha of the edge pixels ("alpha ≤ 252 → forced squircle frame + scaled-down inset", https://developer.apple.com/forums/thread/797971 , tested with `.icns` files on macOS 26.4.1), which would also apply to this icon's transparent margin. The Dock, Finder and menu bar appearance on a real Mac is checked in https://github.com/bannzai/pastecheck/issues/2 .

## Candidates

| File | Idea |
| --- | --- |
| `candidates/a-marked-line.svg` (chosen) | A copied sheet of text where one line is only outlined: PasteCheck points at where the secret is without showing it |
| `candidates/b-clipboard-bracket.svg` | A clipboard with brackets around one empty line: look at this line before pasting |
| `candidates/c-paste-caret.svg` | The text cursor where the paste would land, with the next word only outlined |

Candidate A was chosen because its marked line is still visible at 16 pixels, it uses the accent color as the background so it stands out in the Dock, and it carries the "where, not what" idea. Candidate B's clipboard is close to "a genre symbol with an element added", and candidate C's cursor reads as a text editor rather than the clipboard.

## Menu bar icon

The menu bar shows SF Symbols, which macOS renders as template images (they follow the menu bar's light and dark appearance). One symbol per monitoring state:

| State | SF Symbol |
| --- | --- |
| Watching the clipboard | `checkmark.shield` |
| Paused | `shield.slash` |
| Clipboard access needed | `exclamationmark.shield` |

`PasteCheck/PasteCheckApp.swift` picks the symbol from `ClipboardMonitor.AccessState`. The paused state is added together with the pause setting in https://github.com/bannzai/pastecheck/issues/10 , which uses `shield.slash`. The three names are available on the deployment target macOS 15.0: `/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist` (read on macOS 27.0 on 2026-10-16) lists each of them under the year "2019", which its `year_to_release` table maps to macOS 10.15.
