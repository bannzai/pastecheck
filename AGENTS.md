# AGENTS.md

## 言語

- コードのコメント・リポジトリに入る文書 (README・`documents/`・`docs/`・rules) は日本語で書く。配信先が決まって OSS (Homebrew / GitHub Releases で配布するツール) として公開することになった時に英語へ切り替える (`documents/DIRECTION.md`「決めたこと」で確認する)
- ユーザーとの会話、issue・PR の本文、GitHub 上のコメントは日本語

## 要件と設計判断

- `documents/DIRECTION.md` が仮説・判定基準・必要な機能・決めたことの SSOT。ここに無い問いは agent が可逆な方を選んで同文書の「決めたこと」に記録する
- `documents/PROJECT.md` が要件・不変条件 (クリップボードの中身をアプリの外に出さない) の SSOT。検出ロジック・通知・権限に触れる前に読む
- 設計の決定は `documents/adr/` に残す

## 検証方法

ビルド・テスト・画面の動作確認・公開サイトの表示確認は、**このマシンではなく外部のマシンで行う** (このリポジトリは public なので GitHub-hosted の macOS runner が無料で使え、ローカルの Mac の負荷を避けるため)。ローカルで実行してよいのは `make test` (小さな SwiftPM パッケージのテスト) と `make -n` による Makefile の確認だけで、`xcodebuild build` / `xcodebuild test` / `make build-macos` / `make macos` はローカルで実行しない。

| コマンド | 内容 | 実行する場所 |
| --- | --- | --- |
| `make build-macos` | macOS アプリのビルド (`-derivedDataPath tmp/DerivedData`) | PR の CI (`.github/workflows/ci.yml`、`macos-26` runner)。push して `gh pr checks <PR番号> --watch` で結果を見る。失敗は `gh run view <run ID> --log-failed` でログを読む |
| `make test` | `PasteCheckCore` のユニットテスト (`swift test`)。検出ルールの純粋ロジックはここに置く | CI。ローカルでも可 (数秒で終わる) |
| `make macos` | Release ビルドを `/Applications/PasteCheck.app` に配置する | ユーザーが手元で普段使いする時だけ |

### 画面の確認 (simtunnel)

- アプリの画面と挙動は simtunnel で確認する: GitHub Actions の macOS runner のデスクトップでアプリを起動し、WebDriverAgentMac 経由でローカルから操作・スクリーンショット取得する。ローカルでアプリを起動するのは既定ではない。issue や手順書に `make macos` などローカル前提の記述があっても、それ自体はローカルで動かす理由にならない
- 先に branch を push する。セッションは `--ref` の branch の push 済み tip をビルドする (`--ref` 無しは `main`)
- 起動: `SIMTUNNEL_REPO=bannzai/pastecheck SIMTUNNEL_WORKFLOW=macos-app-session.yml ~/ghq/github.com/bannzai/simtunnel/local/simtunnel up <session> --ref <branch> --wait` (`.github/workflows/macos-app-session.yml` が動く)。操作と撮影は `/macos-simtunnel` skill の `scripts/macos-wda.sh` で行い、画面の状態は必ずスクリーンショットを Read して判断する
- セッション名は `pastecheck-<worktree>-mac` にする。tailnet のホスト名になるため、他リポジトリのセッションと衝突させない
- 終わったら `up` と同じ環境変数で `simtunnel down <session>` する (macOS runner は CI と共有)
- 前提: Secrets `TS_OIDC_CLIENT_ID` / `TS_OIDC_AUDIENCE` が登録されていること (`gh secret list -R bannzai/pastecheck`)。未登録の間はセッションが OIDC 認証で失敗する。登録はユーザー作業 (「ユーザー作業の一覧」issue)
- runner には署名 identity が無いため、プロジェクトは全 configuration で ad-hoc 署名 (`CODE_SIGN_IDENTITY = -`) にしている。配布用の署名は配信先が決まってから別に足す
- ローカルで起動してよいのは、WebDriverAgent の操作 (click・入力・スクリーンショット) では確認が成立しない場合 (例: Cmd+V の割り込みに Accessibility の許可が要り、runner では許可ダイアログに答えられない) と、`/ios-simulator` skill Phase 1 の運用上の条件 (未 push の変更、tailnet 未接続、runner の並列上限等) に当たる場合だけ。理由を完了報告に書く
- クリップボードに入れる検証用の値は `.claude/rules/clipboard-content-handling.md` に従い、明らかに偽の値にする

### 公開サイトの確認 (webtunnel)

- `docs/` (LP・プライバシーポリシー・利用規約・サポート) の表示は webtunnel で確認する: GitHub Actions の Linux runner で `docs/` を配信し、runner 上の Chromium にローカルの agent-browser から CDP 接続する。ローカルのブラウザを既定にしない
- 起動: `WEBTUNNEL_REPO=bannzai/pastecheck ~/ghq/github.com/bannzai/webtunnel/local/webtunnel up <session> --ref <branch> --wait` (`.github/workflows/browser-session.yml` が動く)。接続先の IP は `local/webtunnel cdp <session>`、操作は `/webtunnel` skill に従う。セッション名は `pastecheck-<worktree>-web`
- 公開後 (main にマージ後) の URL は https://bannzai.github.io/pastecheck/ で、公開 URL の確認は `/landing-page-builder` skill の `verify-lp.sh` と `curl` で行う

## Xcode プロジェクト

- `PasteCheck.xcodeproj` がプロジェクト構成の唯一の正。変更は Xcode の GUI か `project.pbxproj` の直接編集で行う
- `xcodegen generate` を実行しない。`project.yml` をリポジトリに置かない。機械検査は `~/.agents/skills/create-new-app/scripts/check-setup.sh` の `xcode-project-source` 項目

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
