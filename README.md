# 種の交換アプリ(seed-project)

固定種・在来種の種苗を個人間・店舗で交換・販売できるコミュニティアプリ群。
出品が伝統野菜辞典を育てる構造を持ち、**種苗法対応**(登録品種の出品ブロック・
指定種苗の表示義務)を最大の特徴とする。仕様書一式は `docs/reps/` にある。

## 構成(モノレポ)

| パス | 内容 | ライセンス |
|---|---|---|
| `kit/` | ステップ1軽量キット(カタログHTML+注文Excel+請求書+PDF取込+在庫API) | MIT |
| `backend/` | FastAPI + PostgreSQL + PocketBase 認証。仕様書の正 | AGPL-3.0-only |
| `packages/core/` | Dart 共有パッケージ(APIクライアント・Session・配色・共通Widget) | MIT |
| `apps/seed/` | 交換用アプリ(Flutter: 個人の交換・販売・譲渡) | AGPL-3.0-only(+ストア配布許可) |
| `apps/shop/` | 販売用アプリ(Flutter: 店舗の出品管理・申込み対応) | AGPL-3.0-only(+ストア配布許可) |
| `admin/` | 運営管理(Flet・DB直結。公開APIに管理系は無い) | MIT |
| `docs/` | 仕様書(reps/)・規約草案 | — |
| `vegitage-data/` | 伝統野菜・伝統料理の調査原稿(辞典の種データ。取込: `backend/scripts/vegimport.py`) | CC BY 4.0 |

辞典コンテンツ(ユーザー投稿)は CC BY-SA 4.0。詳細は
`backend/LICENSING.md`。

## クイックスタート

```bash
# バックエンド(要 PostgreSQL 16 + pg_trgm)
cd backend
pip install -e ".[dev]"
docker compose up -d          # PostgreSQL + PocketBase(開発用)
python scripts/initdb.py      # schema.sql 適用
python scripts/seeddata.py    # デモデータ(伝統野菜30品種・出品50件)
uvicorn app.main:app --reload # http://localhost:8000/docs

# テスト
pytest                        # 本物の PostgreSQL に対して実行

# Flutter アプリ(交換用)
cd apps/seed
flutter pub get && flutter run -d chrome
# 接続先は --dart-define=API_BASE=… / PB_BASE=… で変更

# 運営管理(DB直結)
cd admin && flet run --web --port 8550

# 軽量キット(ステップ1)
cd kit && python ledger.py 台帳.xlsx --sample
```

## コントリビュート

- AGPL 部分(backend / apps)への **プルリクエストを歓迎します**。
  貢献は同じライセンスで受け入れます(inbound=outbound。CLA 不要)
- 交換用・販売用アプリの LICENSE には、App Store 等の配布規約との衝突を
  避けるための**ストア配布の追加許可**(AGPLv3 第7条)を付す予定です
  (文面は専門家レビュー中)
- 実装ルールは各ディレクトリの `CLAUDE.md` を参照(命名・してはいけないこと)

## 運用

- デプロイ: `backend/deploy/`(Caddy + systemd + nftables + rclone バックアップ)
- 定期ジョブ: `backend/scripts/jobs.py`(申込み期限切れ・未読メール通知)
- 静的配信: `backend/scripts/catalogjson.py`(品目・品種・辞典・店舗カタログ)
