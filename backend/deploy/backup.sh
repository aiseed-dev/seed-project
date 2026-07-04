#!/usr/bin/env bash
# docs/09: 毎晩3時に cron で実行。リストア手順は RESTORE.md
set -euo pipefail
STAMP=$(date +%Y%m%d)
pg_dump -Fc seed > /srv/backup/seed-$STAMP.dump
rclone copy /srv/backup/seed-$STAMP.dump r2:seed-backup/db/
rclone sync /srv/seed/images r2:seed-backup/images/
# PocketBase(認証データ)
rclone copy /srv/pocketbase/pb_data r2:seed-backup/pocketbase/ --exclude "*.log"
find /srv/backup -mtime +14 -delete
