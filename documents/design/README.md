# Design

This directory holds the mockups an agent made for the "direction of look and experience" decision (https://github.com/bannzai/pastecheck/issues/5), and any design received from bannzai.

## Layout

- `mock-<date>/` holds one set of mockups.
  - `canvas.json` and `*.dc.html` are the files of the Claude Design canvas. They need the Claude Design canvas runtime and cannot be displayed on their own.
  - `index.html` shows every board stacked vertically. Open it directly in a browser. It loads no external resources.
- `app-icon/` holds the app icon candidates, the script that renders the chosen one into the asset catalog, and the menu bar symbols (see `app-icon/README.md`).

Mockups are proposals and may show details the requirements do not define yet (for example the "12 secrets linked" count in the menu, which would need SecChain to expose a count). `documents/PROJECT.md` is the source for what gets built; a mockup detail not covered there is decided in the implementing issue.

The SecChain parts of `mock-2026-10-11/` (the SecChain warning, the SecChain step of the first-launch window, and the SecChain rows of the menu) are no longer built, because SecChain matching was removed (`documents/DIRECTION.md` "決めたこと", 2026-10-27). The mockups themselves are kept unchanged as the record.

## Source of truth

The files in this repository are the source. A canvas URL stops opening when the account is switched, so do not rely on it.

`index.html` is kept in sync by hand: when a `*.dc.html` file changes, apply the same change to `index.html` (there is no generator script). A new round of mockups goes in a new `mock-<date>/` directory instead of editing an old one.
