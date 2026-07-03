# CLAUDE.md — admin(Flet・MIT)

仕様は docs/07_admin.md が正。DB 直結・運営者のみが使う。

## 規約
- 命名: 短く、アンダースコアなし(複数語はハイフン)
- Python 3.12+ / Flet / ruff / 型ヒント必須
- backend を `pip install git+…/backend.git` で導入し、models / services
  を import する(再実装禁止)。スキーマの正は backend の db/schema.sql
- 各 view は自分でデータ取得と状態を持つ(自己完結型の方針の Python 版)
- 実行は flet run --web(運営者ローカル / SSH トンネル)
- SPDX: MIT

## してはいけないこと
- 公開 API(/admin/*)の実装(DB 直結が仕様。攻撃面を増やさない)
- backend のモデル・ロジックの再実装(必ず import)
- 決済の実装
