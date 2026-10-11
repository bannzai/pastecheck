# Design

This directory holds the mockups an agent made at the "direction of look and experience" decision (gate 2 of the create-new-app skill), and any design received from bannzai.

## Layout

- `mock-<date>/` holds one set of mockups.
  - `canvas.json` and `*.dc.html` are the files of the Claude Design canvas. They need the Claude Design canvas runtime and cannot be displayed on their own.
  - `index.html` shows every board stacked vertically. Open it directly in a browser. It loads no external resources.

## Source of truth

The files in this repository are the source. A canvas URL stops opening when the account is switched, so do not rely on it.

When a `*.dc.html` file changes, regenerate `index.html` so the two stay in sync.
