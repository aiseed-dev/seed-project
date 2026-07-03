# CLAUDE.md — backend(AGPL-3.0)

実装前に README → docs/01 → 該当仕様の順に読む。仕様に無い判断は
推測せず選択肢を提示して確認。schema.sql と SQLAlchemy モデルが
ずれたら schema.sql が正。

## 命名規約
手で打つ名前は短く、アンダースコアを使わない(複数語はハイフン)。
Python モジュールは小文字で短く。ドキュメントは NN_name.md。

## 構成
app/{main.py, core/(設定・DB・PocketBaseトークン検証),
models/, schemas/, routers/(listings, cart, requests, varieties,
crops, editor, shop, qr), services/(mail, 品種提案, 台帳xlsx, QR)}
tests/ alembic/ db/schema.sql deploy/

## Python 規約
- Python 3.12+ / FastAPI / SQLAlchemy 2.0(Mapped[])/ Pydantic v2
- ruff format+lint、型ヒント必須(Any 原則禁止)
- pytest + httpx.AsyncClient。ルーター単位で正常系・認可・
  バリデーションを最低限
- DB アクセスは必要ならサービス層へ。過剰な抽象化はしない
  (リポジトリパターン等は導入しない)
- メールは services/mail.py に集約(localhost の Stalwart へ SMTP。
  環境変数で外部リレー切替)
- 帳票は xlsx(openpyxl)直接生成。QR は segno
- 画像はローカルディスク(/srv/seed/images/、開発時 ./data/images/)。
  DB にはパスのみ
- 認証: PocketBase トークンを Bearer で受けミドルウェアで検証
  (docs/03)。閲覧系は認証不要

## ライセンスヘッダ
新規ソースの1行目に SPDX: AGPL-3.0-only。
外部コントリビュートは CLA 同意なしにマージしない(LICENSING.md)。

## 実装の進め方
docs/08 のフェーズ順(kit はキットのリポジトリで先行)。フェーズを
飛ばさない。各フェーズ完了時にテストが通ってからコミット。
コミットは小さく、日本語で「何を・なぜ」。

## してはいけないこと
- 決済機能・エスクロー機能の実装(作らないことが仕様)
- 在庫の保持・減算の実装(在庫の正は店側。店側在庫API参照。docs/03)
- 登録品種チェックの緩和・スキップ
- PocketBase への業務データ保存(身元のみ)
- docs/ にないエンドポイントの追加実装
- /admin/* /staff/* の公開APIの実装(admin は DB直結の別リポジトリ)
