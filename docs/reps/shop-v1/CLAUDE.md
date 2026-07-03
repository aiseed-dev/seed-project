# CLAUDE.md — shop(販売用アプリ)

仕様は docs/05_shop.md が正。デザインは docs/10_design.md。
命名規約: 手で打つ名前は短く、アンダースコアなし(複数語はハイフン)。
許可パッケージ: http, go_router, image_picker, cached_network_image,
intl, file_selector(取込ファイル選択)、mobile_scanner(QR)。
追加は理由を添えて確認。
SPDX: AGPL-3.0-only(ストア配布の追加許可は LICENSING.md 参照)。

## Flutter 規約(重要)
- **Riverpod / provider / bloc 等の状態管理ライブラリは使わない**
- **小さな自己完結型 Widget** を徹底:
  - 各画面・部品は StatefulWidget が自分でデータ取得(core の
    APIクライアント呼出)と状態を持つ。親から渡すのは ID とコールバックのみ
  - Widget 間の連携はコンストラクタ引数とコールバック
  - グローバル状態は core の Session シングルトン1つ(認証トークン等)
  - null=読込中 / error(リトライ。API不応答は「メンテナンス中」)/
    データ の3状態。mounted チェック必須
- 1ファイル1Widget、1Widget 200行以内を目安
- go_router のみ(Web ディープリンク・QR の飛び先)
- UI テキストは日本語。Material 3。配色・カードは docs/10 が正
  (テーマ色は core の定数から。Widget 内での直接色指定は禁止)
- API 仕様の正は backend リポジトリの docs/03(隣に clone して参照)

## してはいけないこと
- Riverpod/provider の導入(明示的方針)
- 決済機能の実装
- 在庫の保持・減算(在庫表示は店側在庫API由来の値を表示するのみ)
- core への画面の追加(画面はこのアプリ内に自己完結)
- 仕様書にない画面の追加実装
