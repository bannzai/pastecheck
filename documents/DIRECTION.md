---
status: evaluating
decision_date:
cycle_days: 14
veto_wait_hours: 12
daily_issue_cap: 3
launched_at:
---

# 方向性: PasteCheck

## 仮説

AI チャット・Slack・GitHub にターミナルの出力やスクリーンショットを貼ることが多い開発者は、貼る前に目で確認するしかなく、API キーやトークンを貼ってしまう。クリップボードにコピーした瞬間に Mac の中で検査して警告すれば、貼る前に気づける。クリップボードを書き換えずに警告だけ出す (貼るかどうかの判断を利用者に残す) ことが、既存の自動マスク型のツールとの違いになる。

## 判定基準

配信先 (Mac App Store か GitHub Releases + Homebrew tap か) が決まったら、計測元をその配信先の行だけに絞る。

| 指標 | 計測元 (skill / コマンド) | 継続のしきい値 | 打ち切り条件 | 転換の条件 |
| --- | --- | --- | --- | --- |
| 累計ダウンロード数 (GitHub Releases 配信の場合) | `gh api repos/bannzai/pastecheck/releases --jq '[.[].assets[].download_count] \| add'` | 公開 4 週で 100 以上 | 公開 8 週で 100 未満が 2 回連続の判定日で続く | ダウンロードは伸びるが issue・star が 0 なら、配布経路 (Homebrew 公式 cask・App Store) の転換 |
| 自分の利用で有効だった警告の回数 (誤検出を除く) | アプリが端末内に保持する検出回数 (`defaults read com.bannzai.PasteCheck`。値は件数だけで中身は持たない) を判定日に読む | 2 週間で 1 回以上 | 4 週間 0 回 (自分でも使わない) | 誤検出が有効な警告の 3 倍以上なら検出ルールの転換 (形式の絞り込み・実値の照合) |
| GitHub の star と他者の issue (利用者の反応) | `gh api repos/bannzai/pastecheck --jq .stargazers_count`、`gh issue list -R bannzai/pastecheck --search '-author:bannzai' --json number --jq length` | 公開 8 週で star 10 以上または他者の issue 1 件以上 | 公開 12 週で star 0 かつ他者の issue 0 | 無し |

配信先が Mac App Store になった場合、ダウンロード数の行は App Store Connect の数値を取る skill かコマンドを用意した上で書き換える (castle に取得手段がまだ無いため、この時点では GitHub Releases の行だけを置く)。

## 必要な機能

MVP (構想の判断で bannzai が過不足を決める一覧。要件の本文は `PROJECT.md`「機能」):

- [ ] クリップボードの変更検知とテキストのパターン検査 (AWS・GitHub・OpenAI・Slack のキー、JWT、PEM 秘密鍵、カード番号、`.env` 形式)
- [ ] 検出時の通知 (種類と位置だけ。値は出さない)
- [ ] 画像の OCR 検査 (Vision)
- [ ] メニューバーの設定 (一時停止・種類ごとのオン・オフ・ログイン時の自動起動)
- [ ] お問い合わせ・プライバシーポリシー・利用規約への導線
- [ ] 配布 (配信先が決まってから: 署名・公証・Releases または App Store 提出)

候補 (MVP に入れない。入れるかは構想の判断で決める):

- Cmd+V への割り込み (貼り付けの一時停止・確認ダイアログ)
- オンデバイス言語モデル (Foundation Models) による文脈の判定
- クリップボードの自動マスク (オプトイン)
- SecChain (同じ作者の秘密管理アプリ) に保存した実値との照合 (形式に依らず、自分の秘密そのものがコピーされた時だけ確実に警告する)

## デザインの方向

(見た目と体験の方向の判断で決める)

## 決めたこと

| 日付 | 場面 | 決めたこと | 決めた人 |
| --- | --- | --- | --- |
| 2026-10-10 | 立ち上げ | 文書・コメントの言語は、配信先が決まるまで日本語 (OSS として公開することになったら英語に切り替える) | agent |
| 2026-10-10 | 立ち上げ | 立ち上げ時の署名は全 configuration で ad-hoc にし、配布用の署名は配信先が決まってから足す | agent |
| 2026-10-10 | 立ち上げ | 動作確認はこのマシンではなく GitHub Actions の macOS runner (CI)・simtunnel (画面)・webtunnel (公開サイト) で行う | bannzai (立ち上げの依頼文) |
| 2026-10-10 | 立ち上げ | 公開サイトと法務文書は、最初の公開版の設計 (PROJECT.md) に基づく内容を「開発中」と明記して先に公開し、公開時に実装と照らして更新する | agent |

## agent に任せること

- 検出ルールの具体的な正規表現と、誤検出を減らすための除外条件
- 通知の実装方式 (UserNotifications か自前のウィンドウか)
- 設定の保存形式と項目名
- メニューの文言と並び
