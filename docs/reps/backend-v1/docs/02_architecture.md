# 02 アーキテクチャ

## 全体図

物理は2台構成。**メール専用機は常時稼働、アプリ機は計画停止可**。

```
インターネット
   │
   ├ Cloudflare Pages … Flutter Web 配信(アプリ機停止中も画面は出る)
   ├ Cloudflare R2   … 静的カタログJSON(品目・品種・辞典・店舗カタログ。
   │                    在庫は含めない)。アプリ機停止中も閲覧可
   │
Cloudflare (DNS + プロキシ / Full Strict / エッジキャッシュ)
   │ 443 は Cloudflare IP レンジのみ許可(→アプリ機)
   │ メール(25/465/587/993)は Cloudflare を通さず
   │ 家庭用ルータのポート転送で振り分け(→メール専用機)
   ▼
自宅(固定IP・4年運用実績あり)
├ メール専用機(省電力機・常時稼働)
│   └ Stalwart … メール送受信のみ。攻撃面をこの1台に隔離
└ アプリ機(計画停止可・深夜メンテ可)
├ Caddy            … リバースプロキシ + Origin CA 証明書
│   ├ /api/*      → FastAPI (localhost:8000)
│   ├ /auth/*     → PocketBase (localhost:8090)
│   └ /images/*   → ローカルディスク file_server
├ FastAPI          … 業務 API(3アプリ共通)
├ PostgreSQL       … shared / exchange / dictionary スキーマ
├ PocketBase       … 認証のみ(登録・ログイン・メール確認)
├ Stalwart         … メール送受信(DKIM/SPF/DMARC 設定済み前提)
├ OnlyOffice       … 販売店向け事務基盤(アプリとは疎結合)
└ rclone (cron)    … 毎晩 DB dump + 画像を R2/B2 へ

Flutter Web(利用者・販売店)… Cloudflare Pages で配信
iOS / Android      … ストア配布
管理アプリ          … デスクトップ配布(運営者のみ)
```

## 確定済みの決定と理由

| 決定 | 理由 |
|---|---|
| Cloudflare Tunnel を使わず直接 HTTPS | メール運用で固定IPは公開済み。隠す意味がなく、依存部品が減る |
| SSL は Full (Strict) + Origin CA 証明書 | 15年有効・更新不要 |
| 443 を Cloudflare IP レンジに限定 | プロキシ迂回攻撃の遮断。nftables + cron で IP リスト更新 |
| PostgreSQL(SQLite でなく) | 3アプリで品種マスタ共有・不特定多数の書込み |
| PocketBase は身元のみ | 業務データと認証の分離。3アプリで門番を共有 |
| メールは Stalwart 直接送信 | 固定IP 4年運用でレピュテーション確立済み。
  送信関数は抽象化し外部リレーへ切替可能にしておく(保険) |
| 画像はローカル + エッジキャッシュ | 自宅回線の上りを守る。Cache Rules で /images/* をキャッシュ |
| メールは専用機に分離・常時稼働 | メール配送は止められない(相手の再送に依存し、エラー・遅延が相手に見える)。アプリ機は自由に停止・メンテできるようにする |
| 読み取り専用データは Cloudflare 静的配信 | カタログ・品種・辞典・品目を R2 の静的JSONで配信。アプリ機停止中も閲覧が成立。在庫は含めない(必ず店側在庫API経由) |
| aiseed は在庫を持たない | 在庫の正は店側。店側在庫API(標準HTTP+JSON)から取得して表示のみ。二重管理によるずれを構造的に排除 |
| アプリ機停止時の見せ方 | Flutter Web は Pages 配信なので画面は出る。API不応答時は各Widgetの error 状態で「メンテナンス中(◯時〜◯時)」を表示。Cloudflare の Always Online / カスタムエラーページも設定 |
| 事後審査方式 | 小規模運営で回る運用。辞典編集のみ事前承認 |

## 環境変数(backend/.env)

```
DATABASE_URL=postgresql+psycopg://seed:***@localhost/seed
POCKETBASE_URL=http://localhost:8090
IMAGE_ROOT=/srv/seed/images
MAIL_MODE=stalwart            # stalwart | relay
SMTP_HOST=localhost
SMTP_PORT=587
SMTP_USER=app@example.jp
SMTP_PASS=***
RELAY_API_KEY=                # MAIL_MODE=relay 時のみ
PUBLIC_BASE_URL=https://seed.example.jp
```

## ドメイン設計(例)

- `seed.example.jp` … 利用者アプリ(Web)+ API + 画像
- `shop.seed.example.jp` … 販売店アプリ(Web)
- 店舗へのセールス時: 店舗ごとのサブドメイン(`tanenomori.seed.example.jp`)
  または店舗保有ドメインの CNAME も可能(Cloudflare for SaaS は使わず、
  Caddy のバーチャルホストで対応)
