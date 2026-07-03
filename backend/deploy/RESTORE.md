# リストア手順(目標復旧時間: 半日)

1. 新マシンに PostgreSQL 16 / PocketBase / Caddy を導入
2. `python scripts/initdb.py` は使わず、バックアップから復元する:
   ```bash
   createdb seed
   rclone copy r2:seed-backup/db/seed-YYYYMMDD.dump /tmp/
   pg_restore -d seed /tmp/seed-YYYYMMDD.dump
   rclone sync r2:seed-backup/images /srv/seed/images
   rclone sync r2:seed-backup/pocketbase /srv/pocketbase/pb_data
   ```
3. /etc/seed/api.env・Caddyfile・systemd unit を配置して起動
4. DNS はそのまま(固定IPが変わる場合のみ A レコード変更)
5. smoke test(下記)を通す

# 本番 smoke test(docs/08 Phase 7)

登録 → メール確認 → 出品 → 問い合わせ(カート→申込み→メッセージ)→
承諾 → 完了 → 相互評価 の通し。加えて:
- GET /api/v1/categories が 200(Cloudflare Health Check の監視対象)
- QR: /api/v1/qr/v/<品種ID>.png が画像を返す
- メール: 申込み受信・承諾の通知が届く(Stalwart 経由)

# PocketBase の SMTP(Stalwart)設定

1. 管理UI(SSHトンネル: ssh -L 8090:localhost:8090)→ Settings → Mail
2. SMTP server: メール機のLAN IP、port 587、from: app@example.jp
3. users コレクションでメール確認必須を ON
4. テスト送信で DKIM/SPF が通ることを確認
