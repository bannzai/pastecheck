# Design

This directory holds the mockups an agent made for the "direction of look and experience" decision (https://github.com/bannzai/pastecheck/issues/5), and any design received from bannzai.

## Layout

- `mock-<date>/` holds one set of mockups.
  - `canvas.json` and `*.dc.html` are the files of the Claude Design canvas. They need the Claude Design canvas runtime and cannot be displayed on their own.
  - `index.html` shows every board stacked vertically. Open it directly in a browser. It loads no external resources.

## Source of truth

The files in this repository are the source. A canvas URL stops opening when the account is switched, so do not rely on it.

`index.html` is kept in sync by hand: when a `*.dc.html` file changes, apply the same change to `index.html` (there is no generator script). A new round of mockups goes in a new `mock-<date>/` directory instead of editing an old one.
