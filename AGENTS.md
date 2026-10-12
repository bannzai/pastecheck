# AGENTS.md

## Language

- Code comments, documents that go into the repository (README, `documents/`, `docs/`, rules), and UI text are written in English (because this is a developer tool published under the MIT license (`LICENSE`). Decision: `documents/DIRECTION.md` "decisions" 2026-10-11). Existing Japanese documents and comments are fixed all at once in the child issue for switching to English (https://github.com/bannzai/pastecheck/issues/8). Until then, write new files in English, write additions to existing Japanese files in that file's language (Japanese), and do not mix Japanese and English within one file
- Conversations with the user, issue and PR bodies, and comments on GitHub are in Japanese

## Requirements and design decisions

- `documents/DIRECTION.md` is the source of truth for the hypothesis, decision criteria, required features, and decisions made. For questions not covered there, the agent picks the reversible option and records it in that document's "decisions" table
- `documents/PROJECT.md` is the source of truth for the requirements and invariants (never let clipboard contents leave the app). Read it before touching the detection logic, notifications, or permissions
- Record design decisions in `documents/adr/`

## Verification

Builds, tests, checking app screens, and checking the public site are done **on external machines, not on this machine** (this repository is public, so GitHub-hosted macOS runners are free, and it avoids load on the local Mac). The only things allowed to run locally are `make test` (the tests of a small SwiftPM package) and checking the Makefile with `make -n`; do not run `xcodebuild build` / `xcodebuild test` / `make build-macos` / `make macos` locally.

| Command | What it does | Where it runs |
| --- | --- | --- |
| `make build-macos` | Builds the macOS app (`-derivedDataPath tmp/DerivedData`) | The PR's CI (`.github/workflows/ci.yml`, `macos-26` runner). Push and watch the result with `gh pr checks <PR number> --watch`. For failures, read the log with `gh run view <run ID> --log-failed` |
| `make test` | Unit tests of `PasteCheckCore` (`swift test`). The pure logic of the detection rules lives here | CI. Also fine locally (finishes in seconds) |
| `make macos` | Installs a Release build to `/Applications/PasteCheck.app` | Only when the user uses it day to day on their own machine |
| `make macos-debug` | Overwrites the same location with a Debug build (only when using operations that exist only in Debug. Afterwards, go back with `make macos`) | Same as above |

### Checking screens (simtunnel)

- Check the app's screens and behavior with simtunnel: launch the app on the desktop of a GitHub Actions macOS runner, and operate it and take screenshots from the local machine via WebDriverAgentMac. Launching the app locally is not the default. Even if an issue or a procedure has local-oriented steps such as `make macos`, that alone is not a reason to run locally
- Push the branch first. The session builds the pushed tip of the `--ref` branch (`main` without `--ref`)
- Start: `SIMTUNNEL_REPO=bannzai/pastecheck SIMTUNNEL_WORKFLOW=macos-app-session.yml ~/ghq/github.com/bannzai/simtunnel/local/simtunnel up <session> --ref <branch> --wait` (runs `.github/workflows/macos-app-session.yml`). Operate and capture with `scripts/macos-wda.sh` of the `/macos-simtunnel` skill, and always judge the screen state by Reading the screenshot
- Name the session `pastecheck-<worktree>-mac`. It becomes the tailnet hostname, so do not collide with sessions of other repositories
- When done, run `simtunnel down <session>` with the same environment variables as `up` (the macOS runners are shared with CI)
- Prerequisite: the Secrets `TS_OIDC_CLIENT_ID` / `TS_OIDC_AUDIENCE` are registered (`gh secret list -R bannzai/pastecheck`). While they are not registered, sessions fail at OIDC authentication. Registering them is user work (the "list of user tasks" issue)
- The runners have no signing identity, so the project uses ad-hoc signing (`CODE_SIGN_IDENTITY = -`) in every configuration. Developer ID signing for distribution is used only in the release workflow (the signing row of `documents/PROJECT.md` "Technology stack and infrastructure decisions")
- Launching locally is allowed only when the check cannot be done with WebDriverAgent operations (click, input, screenshot) (for example, intercepting Cmd+V needs the Accessibility permission, and on a runner the permission dialog cannot be answered), and when the operational conditions of the `/ios-simulator` skill Phase 1 apply (unpushed changes, not connected to the tailnet, the runner concurrency limit, and so on). Write the reason in the completion report
- Values put on the clipboard for verification follow `.claude/rules/clipboard-content-handling.md` and must be obviously fake

### Checking the public site (webtunnel)

- Check how `docs/` (introduction page, privacy policy, terms of use, support) is displayed with webtunnel: serve `docs/` on a GitHub Actions Linux runner and connect to the runner's Chromium over CDP from the local agent-browser. Do not default to a local browser
- Start: `WEBTUNNEL_REPO=bannzai/pastecheck ~/ghq/github.com/bannzai/webtunnel/local/webtunnel up <session> --ref <branch> --wait` (runs `.github/workflows/browser-session.yml`). Get the IP to connect to with `local/webtunnel cdp <session>`, and operate it according to the `/webtunnel` skill. Name the session `pastecheck-<worktree>-web`
- webtunnel can show only `index.html` (a static file). The legal pages (`privacy.md` and so on) are turned into HTML by GitHub Pages' Jekyll, so they are 404 on the runner's `http.server`. Check the legal pages at the public URL after merging into main
- The public URL (after merging into main) is https://bannzai.github.io/pastecheck/ , and check the public URL with `verify-lp.sh` of the `/landing-page-builder` skill and `curl`

## Xcode project

- `PasteCheck.xcodeproj` is the only source of truth for the project configuration. Change it through the Xcode GUI or by editing `project.pbxproj` directly
- Do not run `xcodegen generate`. Do not put `project.yml` in the repository. The machine check is the `xcode-project-source` item of `~/.agents/skills/create-new-app/scripts/check-setup.sh`

<!-- ai-review-config begin -->
<!--
このブロックは自動生成です。直接編集せず、テンプレートを更新してから再生成してください。
内容は AI コードレビュー時の挙動指示であり、コードベース自体への規約ではありません。
-->

## レビュー時の応答スタイル

- 応答は日本語で行う

## レビュー範囲外

以下は自動レビューで指摘しない (別の検出経路があるため):

- コンパイルエラー・型エラー (ローカル/CI のビルドで検出される)
- Lint/フォーマット違反 (リンター・フォーマッターで検出される)
<!-- ai-review-config end -->
