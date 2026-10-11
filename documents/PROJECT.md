# PasteCheck 要件

macOS のメニューバーに常駐し、クリップボードにコピーしたテキスト・画像に機密情報 (API キー・アクセストークン・秘密鍵・クレジットカード番号など) らしき文字列が含まれていたら、貼り付ける前に警告するアプリ。起票元の思いつきは https://github.com/bannzai/IdeaMemo/issues/358 。

判断の根拠 (仮説・判定基準・決めたこと) は `DIRECTION.md` が SSOT で、本文書は要件と不変条件だけを持つ。作るかどうかの評価レポート (需要・競合・マネタイズ・実現性) は、このリポジトリの「作るかの判断」の issue (https://github.com/bannzai/pastecheck/issues/1) に記録してある。

## 対象ユーザーと場面

- 対象: 開発者。AI チャット・Slack・GitHub の issue などにターミナルの出力・設定ファイル・スクリーンショットを貼ることが多い人
- 場面: ターミナルの出力やログをまるごとコピーした時に環境変数のトークンが混じっていた。設定ファイルの一部を共有する時に秘密鍵の行まで選択していた。エラー画面のスクリーンショットにアクセスキーが写り込んでいた
- 今の代替手段: 貼る前に目で確認する。同じ機能の無料 OSS (secretlint/secure-clipboard) をインストールする。企業向け DLP (ブラウザへの貼り付けを制御) は個人には向かない

## 不変条件

1. **クリップボードの中身をアプリの外に出さない**: 検査はすべて端末内で行う。クリップボードの内容 (テキスト・画像・検出した値) をファイル・ログ・`UserDefaults`・ネットワークに書き出さない。唯一の例外は、同じ Mac 上の SecChain の照合の機能に、照合のためだけにテキストを渡すこと (SecChain は値をメモリの中だけで扱い、出力は一致した秘密の名前だけ)。警告に表示するのは検出の種類・位置 (行・桁・文字数)・一致した SecChain の秘密の名前・コピー元のアプリ名だけで、検出した値そのものは表示しない。SecChain との照合でも、SecChain の秘密の値を PasteCheck 側のメモリ・ファイル・ログ・設定に持たない。コードを書く時・動作確認をする時の適用の仕方は `.claude/rules/clipboard-content-handling.md`
2. **クリップボードを書き換えない (既定)**: 既存ツールの多くはコピー時に値をマスクへ置き換えるが、PasteCheck は警告だけを出し、貼り付けるかどうかの判断は利用者に残す。利用者が警告の中で明示的に「クリップボードを空にする」を押した時だけ書き換える。自動の置き換えや貼り付けのブロックは、入れるとしてもオプトインの設定にする
3. **サーバー・アカウント・計測を持たない**: 提供者が利用者の情報を受け取る経路を作らない (プライバシーポリシー `docs/privacy.md` がこの前提で書かれている)

## 機能

MVP の範囲 (「必要な機能」の一覧と過不足の判断は `DIRECTION.md`):

- クリップボードの変更を検知し、テキストをパターン (正規表現) で検査する。対象の形式: AWS アクセスキー、GitHub トークン (`ghp_` / `github_pat_`)、OpenAI (`sk-`)、Slack (`xox`)、JWT、PEM 形式の秘密鍵、クレジットカード番号 (Luhn 検査)、`.env` 形式の `KEY=値` (値が長いランダム文字列)
- SecChain (同じ作者の秘密管理アプリ https://github.com/bannzai/SecChain ) に保存した秘密の実値がクリップボードに入った時に、形式に依らず警告する。警告に出すのは SecChain 上の秘密の名前だけで値は出さない。経路は、SecChain 側に照合の機能を足して PasteCheck がテキストを渡し一致した名前だけを受け取る形 (CLI のサブコマンドか XPC) にし、Keychain のアクセスグループの共有で PasteCheck が値を読む案は採らない。どちらの形にするかと SecChain 側の変更は、実装する子 issue で設計する
- 検出したら macOS の通知 (または自前の小さなウィンドウ) で、検出の種類と位置、コピー元のアプリ名 (`NSWorkspace.shared.frontmostApplication` の名前。取れなければ出さない) を知らせる。通知には「空にする」(利用者の明示的な操作でクリップボードを空にする) を置く
- 画像をコピーした時は Vision の OCR で文字を取り出し、同じ検査をする
- メニューバーから検査の一時停止・検出の種類ごとのオン・オフ・ログイン時の自動起動を設定する
- 初回起動時に、クリップボードのアクセス許可・通知の許可・SecChain の連携を案内する。クリップボードのアクセス許可は、macOS 15.4 以降が最初のプログラムからの読み取りで確認を出すこと (出典: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum 「The default behavior for the General pasteboard is to ask upon programmatic access」) を前提に、その確認で許可を選ぶ案内と System Settings の Privacy & Security での設定の案内を置く。確認ダイアログの文言と選択肢 (「常に許可」の有無) は Apple の文書で確認できていない (未確認) ため、実装時に実機で確認して文言を合わせる
- メニューバーから「お問い合わせ」(`bannzai.app@gmail.com` 宛のメールを開く) とプライバシーポリシー・利用規約 (`docs/`) へ到達できる
- 警告を出した回数と、通知の "Not a secret" で利用者が誤検出と記録した回数を、日付ごとの件数として端末内に保持する (中身・値・位置は持たない)。メニューの「今日の警告」と、`DIRECTION.md`「判定基準」の期間ごとの有効な警告の回数 (警告 − 誤検出) はこの日付ごとの件数から求める

MVP に入れないもの (入れる時は `DIRECTION.md`「決めたこと」で判断する):

- Cmd+V への割り込み (貼り付けのブロック)。貼り付けを止めるには能動的な `CGEventTap` (`.defaultTap`) が要り、WWDC19「Advances in macOS Security」( https://developer.apple.com/videos/play/wwdc2019/701/ ) はこれに Accessibility の許可が要ると説明している。App Sandbox の文書 ( https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox ) はアクセシビリティ API の使用を制限事項に挙げており、サンドボックス内 (Mac App Store 配布) で能動的な tap が動くことを示す一次情報は見つかっていない (未確認)。聞くだけの `.listenOnly` は Input Monitoring の許可で、サンドボックス内でも使える (Apple DTS の回答 https://developer.apple.com/forums/thread/707680 )。入れるなら Releases 版だけの機能にする
- オンデバイスの言語モデル (Foundation Models) による判定。正規表現で拾えない「文脈から機密と分かる文章」の判定に使えるが、対応 OS とデバイスが限られる
- クリップボードの自動の書き換え (マスク)。不変条件 2
- Mac App Store 版 (Releases 版の公開後に、サンドボックス内で成立する機能だけで出す)
- 日本語のローカライズ (UI 文言は英語を既定にする)

## 技術スタック・インフラの決定

| 項目 | 決定 | 理由 |
| --- | --- | --- |
| アプリ | SwiftUI の `MenuBarExtra` + ローカル SwiftPM パッケージ `PasteCheckCore` (純粋ロジック) | 検出ルールを UI から分離してユニットテストの対象にする (`.claude/rules/swift-coding-conventions.md`) |
| 対応 OS | macOS 15.0 以上 | 2026 年 10 月時点で 2 世代前。`NSPasteboard` のアクセス制御 (15.4 以降。出典: https://developer.apple.com/documentation/appkit/nspasteboard/accessbehavior-swift.enum 「The default behavior for the General pasteboard is to ask upon programmatic access」。この制御が既定で有効になった macOS の版は、Apple の文書で確認できていない (未確認)) を前提に、許可ダイアログが出た時に「常に許可」へ案内する導入画面を設計に入れる。`detectedPatterns(for:)` (中身を読まずに判定できる API) の検出対象はメール・電話番号・URL・金額など 11 種類で、API キー・トークン・秘密鍵・カード番号は無い ( https://developer.apple.com/documentation/appkit/nspasteboard-detection-patterns ) ため、検査には中身の読み取りが要る |
| DB・ストレージ | 無し。設定と検出回数は `UserDefaults` だけ | 不変条件 1・3 |
| バックエンド・認証 | 無し | 不変条件 3 |
| Analytics・クラッシュ収集 | 無し | 不変条件 3。公開後の判定に使う指標は配信先の数値 (`DIRECTION.md`「判定基準」) |
| 公開サイト・法務ドキュメント | GitHub Pages (`docs/`、main の `/docs` から配信) | create-new-app skill の既定 |
| 配信先 | 先に Developer ID 署名 + 公証の DMG を GitHub Releases と自前の Homebrew tap (bannzai/homebrew-tap) から配る。Mac App Store 版は後から。雛形は SecChain の `release.yml` と `documents/macos-distribution.md` | 作るかの判断で bannzai が「両方」と決めた (`DIRECTION.md`「決めたこと」2026-10-11)。Cmd+V への割り込みなど App Sandbox 内で成立しない機能を Releases 版に載せられる |
| 署名 | CI・simtunnel は全 configuration で ad-hoc (`CODE_SIGN_IDENTITY = -`)。配布用の Developer ID 署名は release workflow だけで使う (証明書と App Store Connect API key は GitHub Secrets) | CI と simtunnel の runner に署名 identity が無い |
| App Sandbox | 有効のまま | Mac App Store 版と同じコードにするため。SecChain との照合は SecChain 側の照合の機能に文字列を渡して一致した名前だけを受け取る経路にし、Keychain のアクセスグループの共有で値を読まない (SecChain の設計判断 8: 他のプロセスに値を持たせない) |
| 言語 | リポジトリに入る文書・コードのコメント・UI 文言は英語。会話・issue・PR・GitHub のコメントは日本語 | Developer ID + Homebrew tap で配る開発者向けツールは、他者の利用・貢献を前提にした OSS に当たり、英語でないと利用者と貢献者に届かない |
| 動作確認 | GitHub Actions の macOS runner (CI) と simtunnel (画面)、webtunnel (公開サイト)。手順は `AGENTS.md`「検証方法」 | このマシンの負荷を避ける |
