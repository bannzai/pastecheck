---
status: building
decision_date:
cycle_days: 14
veto_wait_hours: 12
daily_issue_cap: 3
launched_at:
---

# 方向性: PasteCheck

## 仮説

AI チャット・Slack・GitHub にターミナルの出力やスクリーンショットを貼ることが多い開発者は、貼る前に目で確認するしかなく、API キーやトークンを貼ってしまう。クリップボードにコピーした瞬間に Mac の中で検査して警告すれば、貼る前に気づける。クリップボードを書き換えずに警告だけ出す (貼るかどうかの判断を利用者に残す) ことと、SecChain に保存した自分の秘密の実値がコピーされた時に形式に依らず確実に警告することが、既存の自動マスク型のツールとの違いになる。

## 判定基準

最初の配信先は GitHub Releases + Homebrew tap で、計測元はその行にする。Mac App Store 版を出した時に、App Store Connect の数値を取る skill かコマンドを用意した上でその行を足す (castle に取得手段がまだ無い)。

| 指標 | 計測元 (skill / コマンド) | 継続のしきい値 | 打ち切り条件 | 転換の条件 |
| --- | --- | --- | --- | --- |
| 累計ダウンロード数 (GitHub Releases) | `gh api repos/bannzai/pastecheck/releases --jq '[.[].assets[].download_count] \| add'` | 公開 4 週で 100 以上 | 公開 8 週で 100 未満が 2 回連続の判定日で続く | ダウンロードは伸びるが issue・star が 0 なら、配布経路 (Homebrew 公式 cask・App Store) の転換 |
| 自分の利用で有効だった警告の回数 (誤検出を除く) | アプリが端末内に日付ごとに保持する 2 つの件数、警告を出した回数と、通知の "Not a secret" で利用者が誤検出と記録した回数 (値は日付と件数だけで中身は持たない。読むコマンドは未確認: サンドボックス有効のアプリの `UserDefaults` はコンテナ `~/Library/Containers/com.bannzai.PasteCheck/Data/Library/Preferences/com.bannzai.PasteCheck.plist` に書かれる想定で、`defaults read` でそのパスを読めるかを実装する子 issue https://github.com/bannzai/pastecheck/issues/7 で確かめてこの行を直す) を判定日に読み、判定の期間 (直前の判定日から今日まで) の日付の分を足して、有効 = 警告 − 誤検出で求める | 2 週間で 1 回以上 | 4 週間 0 回 (自分でも使わない) | 誤検出が有効な警告の 3 倍以上なら検出ルールの転換 (形式の絞り込み。SecChain の実値との照合は MVP に入ったため、転換では既定を照合だけに寄せる) |
| GitHub の star と他者の issue (利用者の反応) | `gh api repos/bannzai/pastecheck --jq .stargazers_count`、`gh issue list -R bannzai/pastecheck --search '-author:bannzai' --json number --jq length` | 公開 8 週で star 10 以上または他者の issue 1 件以上 | 公開 12 週で star 0 かつ他者の issue 0 | 無し |

## 必要な機能

MVP (作るかの判断で bannzai が「両方 (警告だけ型を土台に、実値照合を MVP に含める)」と決めた一覧。要件の本文は `PROJECT.md`「機能」):

- [ ] クリップボードの変更検知とテキストのパターン検査 (AWS・GitHub・OpenAI・Slack のキー、JWT、PEM 秘密鍵、カード番号、`.env` 形式)
- [ ] 検出時の通知 (種類と位置だけ。値は出さない)。警告を出した回数と、通知の "Not a secret" で記録した誤検出の回数の、日付ごとの端末内での保持 (判定基準の計測元とメニューの「今日の警告」)
- [ ] SecChain に保存した秘密の実値との照合 (形式に依らず、自分の秘密そのものがコピーされた時だけ確実に警告する。値を PasteCheck 側に持たない照合の経路は子 issue で設計し、SecChain 側の対応が要る場合はそれを前提にする)
- [ ] 画像の OCR 検査 (Vision)
- [ ] メニューバーの設定 (一時停止・種類ごとのオン・オフ・ログイン時の自動起動) と、初回起動時の案内 (クリップボードのアクセス許可・通知の許可・SecChain の連携)
- [ ] お問い合わせ・プライバシーポリシー・利用規約への導線
- [ ] アプリアイコン
- [ ] 配布: Developer ID 署名・公証・GitHub Releases の DMG と自前の Homebrew tap (bannzai/homebrew-tap) の cask。release workflow は公開に進む判断が出るまで `workflow_dispatch` だけで動かす
- [ ] 文書・コードのコメント・UI 文言を英語にする (OSS として公開するため)

候補 (MVP に入れない。入れるかは判定日か触れる版の判断で決める):

- Cmd+V への割り込み (貼り付けの一時停止・確認ダイアログ)。Accessibility の許可が要り App Sandbox 内で動く一次情報が無いため、入れるなら Releases 版だけの機能にする
- Mac App Store 版 (Releases 版の公開後。サンドボックス内で成立する機能だけを載せる)
- 日本語のローカライズ (UI 文言は英語を既定にする)
- オンデバイス言語モデル (Foundation Models) による文脈の判定
- クリップボードの自動マスク (オプトイン)

## デザインの方向

(見た目と体験の方向の判断で決める。モックは `documents/design/mock-2026-10-11/`)

## 決めたこと

| 日付 | 場面 | 決めたこと | 決めた人 |
| --- | --- | --- | --- |
| 2026-10-10 | 立ち上げ | 文書・コメントの言語は、配信先が決まるまで日本語 (OSS として公開することになったら英語に切り替える) | agent |
| 2026-10-10 | 立ち上げ | 立ち上げ時の署名は全 configuration で ad-hoc にし、配布用の署名は配信先が決まってから足す | agent |
| 2026-10-10 | 立ち上げ | 動作確認はこのマシンではなく GitHub Actions の macOS runner (CI)・simtunnel (画面)・webtunnel (公開サイト) で行う | bannzai (立ち上げの依頼文) |
| 2026-10-10 | 立ち上げ | 公開サイトと法務文書は、最初の公開版の設計 (PROJECT.md) に基づく内容を「開発中」と明記して先に公開し、公開時に実装と照らして更新する | agent |
| 2026-10-11 | 作るかの判断 | 作る (「できるなら作ろう」) | bannzai |
| 2026-10-11 | 作るかの判断 | 採用する案は両方: クリップボードを書き換えずに警告だけ出す設計を土台にし、SecChain に保存した秘密の実値との照合も MVP に含める | bannzai |
| 2026-10-11 | 作るかの判断 | 配信先は両方: 先に Developer ID 署名 + 公証で GitHub Releases と自前の Homebrew tap から配り、Mac App Store 版は後から出す。App Sandbox 内で成立しない機能は Releases 版だけの機能にする | bannzai |
| 2026-10-11 | 作るかの判断 | 作り手の目的は「自分が使いたい」と「ポートフォリオ」として扱う (返答が「よろしく」で目的の指定が無く、評価レポートの目的別の判定でこの 2 つが「条件付きで作る」に当たるため)。収益は目的にしないため、MVP に課金を入れず、特定商取引法に基づく表記は対象外にする | agent |
| 2026-10-11 | 作るかの判断 | Developer ID + Homebrew tap で配る開発者向けツールは OSS に当たるため、リポジトリに入る文書 (`docs/` の紹介ページ・法務文書を含む)・コードのコメント・UI 文言を英語に切り替える。会話・issue・PR・GitHub のコメントは日本語のまま。日本語のローカライズは公開後の候補にする | agent |
| 2026-10-11 | 作るかの判断 | MVP は App Sandbox を有効のまま作る (Mac App Store 版と同じコードにするため)。SecChain との照合は、SecChain の秘密の値を PasteCheck に持たない経路 (SecChain 側に照合の機能を足し、一致した名前だけを受け取る) で行い、Keychain のアクセスグループの共有で値を読む案は採らない。経路の都合で Releases 版だけサンドボックスを外す判断が要る時は、照合の子 issue でこの表に追記する | agent |
| 2026-10-11 | 作るかの判断 | ロードマップの弾の分け方: 土台 (検出ルールとクリップボードの監視・通知、英語への切り替え) → 土台に依存する機能 (OCR、メニューバーの設定と初回起動の案内、アプリアイコン、SecChain との照合) → 配布 (署名・公証・Releases・tap) | agent |
| 2026-10-11 | 作るかの判断 | 警告の通知に「クリップボードを空にする」操作を置く。利用者が明示的に押した時だけ書き換えるため、不変条件 2 (既定で書き換えない) に反しない。自動では空にしない | agent |

## agent に任せること

- 検出ルールの具体的な正規表現と、誤検出を減らすための除外条件
- 通知の実装方式 (UserNotifications か自前のウィンドウか)
- 設定の保存形式と項目名
- メニューの文言と並び
- SecChain との照合の経路のうち、SecChain 側に足す照合の機能の形 (CLI のサブコマンドか XPC か。Keychain の共有で値を読む案は採らないと決めた) と、その設計
- Homebrew tap の cask の書き方と release workflow の構成 (SecChain の `release.yml`・`documents/macos-distribution.md` を雛形にする)
