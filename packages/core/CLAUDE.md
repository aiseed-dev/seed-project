# CLAUDE.md — core(共有パッケージ・MIT)

## 役割と境界
配管のみ: api_client / models / session / constants(docs/10 の配色)/
共通Widget(ListingCard・TypeBadge 等の最小限)。
**画面(Screen)はここに置かない**(各アプリ内に自己完結で実装する。
アプリ独立の原則)。API 仕様の正は backend リポジトリの docs/03。

## 規約
- パッケージ名は core(接頭辞不要。publish せず git 依存で使う)
- Riverpod / provider / bloc を持ち込まない。Session はシングルトン1つ
- 依存パッケージは http, intl のみ(追加は理由を添えて確認)
- SPDX: MIT

## してはいけないこと
- 画面・ナビゲーション・go_router 設定の実装
- アプリ固有ロジックの混入(3アプリのどれか専用のコードは各アプリへ)

## デザイン原則
UI の作成・変更時は `.claude/skills/design` を必ず参照
(レスポンシブ規則と文字スケーリング規則を含む)。
