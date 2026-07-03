#!/usr/bin/env bash
# 443 を Cloudflare の IP レンジのみに絞る nft set を更新する(cron 週1)
set -euo pipefail
V4=$(curl -fsS https://www.cloudflare.com/ips-v4)
V6=$(curl -fsS https://www.cloudflare.com/ips-v6)
nft flush set inet filter cf4 2>/dev/null || true
nft flush set inet filter cf6 2>/dev/null || true
for ip in $V4; do nft add element inet filter cf4 "{ $ip }"; done
for ip in $V6; do nft add element inet filter cf6 "{ $ip }"; done
echo "updated: $(echo "$V4" | wc -l) v4 / $(echo "$V6" | wc -l) v6 ranges"
