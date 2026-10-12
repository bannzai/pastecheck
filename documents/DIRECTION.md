---
status: building
decision_date:
cycle_days: 14
veto_wait_hours: 12
daily_issue_cap: 3
launched_at:
---

# Direction: PasteCheck

<!-- The section headings (## 仮説, ## 判定基準, ## 必要な機能, ## デザインの方向, ## 決めたこと, ## agent に任せること) stay in Japanese: castle's product-loop scripts find sections by these exact headings (decide.sh matches "## 判定基準"). See the 2026-10-12 row of the decisions table. -->

## 仮説

Developers who often paste terminal output or screenshots into AI chats, Slack, or GitHub have no way to check them other than by eye before pasting, and end up pasting API keys or tokens. If the clipboard is inspected inside the Mac the moment something is copied and a warning is shown, they can notice before pasting. What sets it apart from existing auto-masking tools is that it only warns without rewriting the clipboard (leaving the decision to paste to the user), and that it reliably warns, regardless of format, when the actual value of one of the user's own secrets stored in SecChain is copied.

## 判定基準

The first distribution channel is GitHub Releases + a Homebrew tap, and the measurement sources are those rows. When a Mac App Store version ships, add its row after preparing a skill or command that fetches the App Store Connect numbers (castle has no way to fetch them yet).

| Metric | Measurement source (skill / command) | Threshold to continue | Condition to stop | Condition to pivot |
| --- | --- | --- | --- | --- |
| Cumulative downloads (GitHub Releases) | `gh api repos/bannzai/pastecheck/releases --jq '[.[].assets[].download_count] \| add'` | 100 or more within 4 weeks of launch | Under 100 at 8 weeks after launch, on 2 consecutive decision dates | If downloads grow but issues and stars stay at 0, pivot the distribution channel (official Homebrew cask, App Store) |
| Number of useful warnings in my own use (excluding false positives) | Two counts the app keeps per date on the device: the number of warnings shown, and the number of times the user marked a warning as a false positive with "Not a secret" in the notification (the values are only dates and counts, with no content. The keys are `warningCountsByDay` and `falsePositiveCountsByDay`, each a dictionary from a date `yyyy-MM-dd` to a count, defined in `PasteCheck/WarningCountStore.swift`. Read them with `defaults read ~/Library/Containers/com.bannzai.PasteCheck/Data/Library/Preferences/com.bannzai.PasteCheck.plist warningCountsByDay` and the same path with `falsePositiveCountsByDay`. Evidence: `man defaults` says "Domains may also be specified as a path to an arbitrary plist file" and gives a TextEdit container plist path as an example. On 2026-10-12, passing the container plist path of another sandboxed app to `defaults read` on this Mac resolved it as that plist's domain without a permission error (asking for a missing key returned "Could not find key ... in domain"). Whether PasteCheck's own plist can be read is unverified, because the file does not exist until the app has shown a warning). Read them on the decision date, add up the dates in the decision period (from the previous decision date to today), and compute useful = warnings − false positives | 1 or more in 2 weeks | 0 for 4 weeks (I don't use it myself either) | If there is at least 1 false positive and false positives are 3 or more times the useful warnings, pivot the detection rules (narrow the formats. Matching against actual SecChain values is in the MVP, so the pivot makes matching alone the default) |
| GitHub stars and issues from others (user reaction) | `gh api repos/bannzai/pastecheck --jq .stargazers_count`, `gh issue list -R bannzai/pastecheck --search '-author:bannzai' --json number --jq length` | 10 or more stars, or 1 or more issues from others, within 8 weeks of launch | 0 stars and 0 issues from others at 12 weeks after launch | None |

## 必要な機能

The MVP (the list bannzai settled in the build decision as "both (build on the warn-only design and include actual-value matching in the MVP)". The requirements text is in `PROJECT.md` "Features"):

- [x] Detecting clipboard changes and checking text against patterns (AWS, GitHub, OpenAI, and Slack keys, JWT, PEM private keys, card numbers, `.env` format)
- [x] A notification on detection (type and position only, no value). Keeping per-date counts on the device of the warnings shown and of the false positives recorded with "Not a secret" in the notification (the measurement source of the decision criteria and the menu's "Today's warnings")
- [ ] Matching against the actual values of secrets stored in SecChain (warns reliably, regardless of format, only when one of your own secrets is copied. The matching path that keeps values out of PasteCheck is designed in a child issue, and if SecChain needs changes, those are a prerequisite)
- [x] OCR inspection of images (Vision)
- [ ] Menu bar settings (pause, on/off per type, launch at login) and first-launch guidance (clipboard access permission, notification permission, SecChain integration)
- [ ] Links to contact, the privacy policy, and the terms of use
- [ ] App icon
- [ ] Distribution: Developer ID signing, notarization, a DMG on GitHub Releases, and a cask in my own Homebrew tap (bannzai/homebrew-tap). The release workflow runs only via `workflow_dispatch` until the decision to launch is made
- [ ] Switch documents, code comments, and UI text to English (to publish as OSS)

Candidates (not in the MVP. Whether to add them is decided on a decision date or in the playable-build decision):

- Intercepting Cmd+V (pausing the paste, a confirmation dialog). It needs the Accessibility permission and there is no primary source showing it works inside the App Sandbox, so if added it becomes a Releases-only feature
- A Mac App Store version (after the Releases version ships. It carries only the features that work inside the sandbox)
- Japanese localization (UI text defaults to English)
- Context-based judgment with an on-device language model (Foundation Models)
- Automatic masking of the clipboard (opt-in)

## デザインの方向

(Decided in the decision on the direction of look and experience. The mockups are in `documents/design/mock-2026-10-11/`)

## 決めたこと

| Date | Occasion | Decision | Decided by |
| --- | --- | --- | --- |
| 2026-10-10 | Launch | Documents and comments are in Japanese until the distribution channel is decided (switch to English if it is published as OSS) | agent |
| 2026-10-10 | Launch | At launch, signing is ad-hoc in every configuration; signing for distribution is added after the distribution channel is decided | agent |
| 2026-10-10 | Launch | Verification is done not on this machine but on GitHub Actions macOS runners (CI), simtunnel (screens), and webtunnel (the public site) | bannzai (the launch request) |
| 2026-10-10 | Launch | The public site and legal documents are published first with content based on the design of the first public version (PROJECT.md), clearly marked "in development", and updated against the implementation at launch | agent |
| 2026-10-11 | Build decision | Build it ("let's build it if we can") | bannzai |
| 2026-10-11 | Build decision | Adopt both proposals: build on the design that only warns without rewriting the clipboard, and include matching against the actual values of secrets stored in SecChain in the MVP | bannzai |
| 2026-10-11 | Build decision | Both distribution channels: first distribute from GitHub Releases and my own Homebrew tap with Developer ID signing + notarization, and ship a Mac App Store version later. Features that do not work inside the App Sandbox become Releases-only features | bannzai |
| 2026-10-11 | Build decision | Treat the maker's goals as "I want to use it myself" and "portfolio" (the reply was "よろしく" ("go ahead") with no goal specified, and in the evaluation report's per-goal verdicts these two were "build with conditions"). Revenue is not a goal, so the MVP has no payments, and the notation based on the Act on Specified Commercial Transactions is out of scope | agent |
| 2026-10-11 | Build decision | A developer tool distributed through Developer ID + a Homebrew tap counts as OSS, so switch the documents that go into the repository (including the `docs/` introduction page and legal documents), code comments, and UI text to English. Conversations, issues, PRs, and GitHub comments stay in Japanese. Japanese localization becomes a post-launch candidate | agent |
| 2026-10-11 | Build decision | To publish as OSS, the license is MIT (`LICENSE`, the same as SecChain by the same author). A distribution channel alone does not grant permission to use, modify, or redistribute, so it is called OSS only once the license file is in place | agent |
| 2026-10-11 | Build decision | Build the MVP with the App Sandbox kept enabled (to share code with the Mac App Store version). Matching with SecChain uses a path that keeps SecChain's secret values out of PasteCheck (add a matching feature to SecChain and receive only the matched names), and the idea of reading values by sharing a Keychain access group is not adopted. If the path requires removing the sandbox from the Releases version only, the matching child issue appends that decision to this table | agent |
| 2026-10-11 | Build decision | How the roadmap is split into rounds: foundation (detection rules and clipboard monitoring/notifications, switching to English) → features that depend on the foundation (OCR, menu bar settings and first-launch guidance, app icon, matching with SecChain) → distribution (signing, notarization, Releases, tap) | agent |
| 2026-10-11 | Build decision | Allow exactly one exception to invariant 1 (never let clipboard contents leave the app): pass text to SecChain's matching feature on the same Mac, only for matching, via standard input or XPC rather than arguments, after checking the signature (Team ID and bundle ID), and receive only the names of matched secrets (`PROJECT.md` invariant 1 and `.claude/rules/clipboard-content-handling.md`) | agent (as the only path that realizes bannzai's decision to include SecChain actual-value matching in the MVP) |
| 2026-10-11 | Build decision | Put a "Clear clipboard" action in the warning notification. It rewrites the clipboard only when the user explicitly presses it, so it does not violate invariant 2 (no rewriting by default). It never clears automatically | agent |
| 2026-10-12 | Switching to English | Strings that tools match keep their Japanese text: the section headings of this document (castle's product-loop `decide.sh` finds the decision criteria table by the exact heading `## 判定基準`), the `## 人間が確認` heading in `.github/pull_request_template.md` (PR bodies are written in Japanese per `AGENTS.md` "Language", and `human-verification-check.yml` and the auto-merge scripts match this heading), and the generated `ai-review-config` block in `AGENTS.md` (regenerated from a template, not edited by hand) | agent |
| 2026-10-12 | Clipboard monitoring (#7) | When the clipboard access behavior (macOS 15.4 and later) is `.ask` or `.alwaysDeny`, do not read the clipboard, and show in the menu bar icon and menu that access is needed. If Apple's documentation holds (https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum , on `default`: "Once programmatic pasteboard access triggers the first pasteboard access alert, the state automatically changes to `.ask`"), inspection stops until the user always allows access in System Settings. Not showing the confirmation alert on every change took priority (to revert, change the check in `PasteCheck/ClipboardMonitor.swift`) | agent |
| 2026-10-12 | Image OCR (#9) | When the clipboard holds both text and an image, inspect only the text, and run OCR only when there is no text. One copy then gives at most one warning instead of two for the same key. The cost is that an image copied together with some text is not OCR'd. Which apps put both on the clipboard, and whether a screenshot comes with no text, is unverified (to revert, change `inspectIfChanged()` in `PasteCheck/ClipboardMonitor.swift`) | agent |
| 2026-10-12 | Image OCR (#9) | The "Text inside images (OCR)" switch is the `UserDefaults` key `detectsTextInImages`, on when unset (OCR is an MVP feature, and the switch is for turning it off). The menu row that changes it is left to the menu bar settings issue (#10) | agent |

## agent に任せること

- The concrete regular expressions of the detection rules, and the exclusion conditions that reduce false positives
- How notifications are implemented (UserNotifications or a custom window)
- The storage format and key names of settings
- The wording and order of the menu
- In the SecChain matching path, the shape of the matching feature added to SecChain (a CLI subcommand or XPC. Reading values by sharing the Keychain was decided against) and its design
- How to write the Homebrew tap cask and how to structure the release workflow (use SecChain's `release.yml` and `documents/macos-distribution.md` as templates)
