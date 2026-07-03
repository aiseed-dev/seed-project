# 08 デプロイ・運用

前提: 自宅(固定IP)、Cloudflare で DNS 管理、
Stalwart 稼働済み(DKIM/SPF/DMARC/PTR 設定済み)。

## 2台構成(役割分離)

- **メール専用機**: Stalwart のみ。省電力機(ミニPC等)で常時稼働。
  ルータのポート転送で 25/465/587/993 をこの機へ。MX はこの機を指す
- **アプリ機**: FastAPI・PostgreSQL・PocketBase(・OnlyOffice)。
  443 のみ受ける。計画停止・深夜メンテ可。停止時間帯はアプリ内で事前告知
- アプリ機からのメール送信は宅内LAN経由でメール機の Stalwart へ SMTP

## アプリ機停止時の受け皿

- Flutter Web(seed/shop/aiseed)は **Cloudflare Pages 配信を基本**とする
  (アプリ機からの同居配信はしない)。停止中も画面自体は表示される
- カタログ・品種・辞典・品目は R2 の静的JSONから読むため停止中も閲覧可
- API 不応答時は各Widgetの error 状態で「メンテナンス中」を表示
  (docs/04 の3状態パターン)
- Cloudflare 側に Always Online / カスタムエラーページを設定

## Cloudflare 設定

1. A レコード `seed.example.jp` → 固定IP(プロキシON=オレンジ雲)
2. SSL/TLS モード: **Full (Strict)**
3. Origin CA 証明書を発行(15年)→ サーバーに配置
4. Cache Rules: `/images/*` を Cache Everything, Edge TTL 1ヶ月
   (画像はファイル名にハッシュを含めるため無効化不要)
5. `/api/*` は Bypass cache

## Caddy(deploy/Caddyfile)

```
seed.example.jp {
    tls /etc/caddy/origin.pem /etc/caddy/origin-key.pem

    handle /api/* {
        reverse_proxy localhost:8000
    }
    handle /auth/* {
        uri strip_prefix /auth
        reverse_proxy localhost:8090
    }
    handle /images/* {
        root * /srv/seed
        file_server
        header Cache-Control "public, max-age=31536000, immutable"
    }
    handle {
        # 利用者アプリを Pages でなく同居配信する場合はここに root
        respond 404
    }
}
```

## ファイアウォール(nftables)

443 は Cloudflare の IP レンジのみ許可。メール系ポート(25/465/587/993)は
従来通り。`deploy/update-cf-ips.sh` が
https://www.cloudflare.com/ips-v4 と ips-v6 を取得して nft set を更新
(cron 週1)。

## systemd

- `seed-api.service` … uvicorn app.main:app(WorkingDirectory=backend、
  EnvironmentFile=/etc/seed/api.env、Restart=always)
- `pocketbase.service` … pocketbase serve --http=127.0.0.1:8090
- 短時間ダウン許容のため、デプロイは `git pull && systemctl restart seed-api`
  で良い(Blue-Green 不要)

## PocketBase 設定

- Settings → Mail: SMTP=localhost:587, from=app@example.jp(Stalwart 経由)
- users コレクション: メール確認必須をON
- Admin UI は Caddy で公開しない(サーバー内から SSH トンネルで操作)

## バックアップ(deploy/backup.sh, cron 毎晩3時)

```bash
#!/usr/bin/env bash
set -euo pipefail
STAMP=$(date +%Y%m%d)
pg_dump -Fc seed > /srv/backup/seed-$STAMP.dump
rclone copy /srv/backup/seed-$STAMP.dump r2:seed-backup/db/
rclone sync /srv/seed/images r2:seed-backup/images/
# PocketBase(認証データ)
rclone copy /srv/pocketbase/pb_data r2:seed-backup/pocketbase/ --exclude "*.log"
find /srv/backup -mtime +14 -delete
```

リストア: 新マシンに PostgreSQL/PocketBase を入れ、
`pg_restore -d seed dump` + images/pb_data を rclone で戻す → DNS はそのまま
(固定IPが変わる場合のみ A レコード変更)。目標復旧時間: 半日。

## 監視(最小限)

- Cloudflare の Health Check(無料枠)で /api/v1/categories を5分間隔監視、
  ダウン時メール通知
- ディスク使用量: 週1で df を自分宛メール(cron 一行)

## 販売店テナント追加時(セールス成立後)

1. `tanenomori.seed.example.jp` の A レコード追加(または店舗ドメインの CNAME)
2. Caddyfile にホスト追加(内容は同一 upstream)
3. admin アプリで店舗作成 → スタッフのユーザーを紐付け → 認証バッジON
4. OnlyOffice / メールの事務基盤は既存 Stalwart に店舗用ドメインを追加登録
