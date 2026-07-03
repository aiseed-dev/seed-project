# 03 API 仕様(FastAPI)

ベースパス: `/api/v1`。レスポンスは JSON。日時は ISO 8601 (UTC)。
ページングは `?cursor=<created_at>&limit=20`(カーソル方式、無限スクロール前提)。

## 認証

- クライアントは PocketBase でログインしトークンを取得
  (`POST {POCKETBASE_URL}/api/collections/users/auth-with-password`)
- FastAPI へは `Authorization: Bearer <token>` で送る
- ミドルウェアが PocketBase の `GET /api/collections/users/auth-refresh`
  相当でトークンを検証し、`request.state.user_id` に PocketBase ID を格納。
  検証結果は数分間メモリキャッシュしてよい
- 初回アクセス時、shared.app_users に行が無ければ自動作成
  (display_name は PocketBase の name か email ローカル部)
- 認可レベル: 公開(認証不要)/ 認証必須 / 本人のみ / 店舗スタッフ /
  editor(app_users.role が editor/moderator/admin)。
  editor 以外の管理操作は API 外(docs/07 参照)

## エンドポイント一覧

### 公開(認証不要)

| メソッド/パス | 内容 |
|---|---|
| GET /categories | 分類一覧 |
| GET /listings | 出品一覧。`?category=&type=&region=&q=&shop=` で絞込。active+approved のみ |
| GET /listings/{id} | 出品詳細(閲覧数をインクリメント) |
| GET /crops | 品目一覧 `?category=`(統合アプリのホーム用) |
| GET /crops/{id} | 品目ハブ用の集約: 品目情報+所属品種(approved)+出品中の種苗+辞典記事の有無(+将来: 料理) |
| GET /varieties | 品種検索 `?q=`(pg_trgm。name/kana/aliases 対象、approved のみ) |
| GET /varieties/{id} | 品種詳細 |
| GET /articles/{variety_id} | 辞典記事(current_revision の内容) |
| GET /shops/{slug} | 店舗プロフィール+出品一覧 |
| GET /articles/export | 辞典記事の一括JSON(CC BY-SA の持ち出し保証。認証不要) |
| GET /users/{id}/public | 公開プロフィール(表示名・地域・評価集計・出品) |

### 認証必須

| メソッド/パス | 内容 |
|---|---|
| GET /me | 自分のプロフィール |
| PATCH /me | プロフィール更新 |
| PATCH /shop/me | 自分の店舗内担当名(contact_label)を更新(店舗スタッフのみ) |
| POST /listings | 出品作成。variety_id 無しなら variety_name_free 必須(varieties に pending 提案を自動生成)。non_registered_confirmed=false は 422。is_registered_variety=true の品種は 409。**requires_seed_label=true なら指定種苗表示(氏名・住所・生産地、種子は発芽率)必須(422 `SEED_LABEL_REQUIRED`)。item_kind=produce かつ delivery_method=mail なら食品表示(名称・原産地・生産者・収穫日・保存方法)必須(422 `FOOD_LABEL_REQUIRED`)。requires_tokushoho=true なら特商法表示の項目(店舗プロフィールの住所・連絡先・返品方針・引き渡し時期)が揃っていること(422 `TOKUSHOHO_REQUIRED`)** |
| PATCH /listings/{id} | 本人(または所属店舗スタッフ)のみ。status 変更含む |
| POST /listings/{id}/photos | multipart。最大4枚。JPEG/PNG/WebP、10MBまで。保存時に長辺1600pxへ縮小 |
| DELETE /photos/{id} | 本人のみ |
| GET /cart | カート内容(提供者ごとにグループ化。販売品グループには小計を含む。送料は含まない=送料別) |
| PUT /cart/items/{listing_id} | 追加・数量変更 {quantity}。取引中/終了の出品は 409 |
| DELETE /cart/items/{listing_id} | カートから削除 |
| POST /requests | 申込み送信 {provider(user/shop+id), note}。カート内の該当提供者分を request_items へ移す。**request_no を DB全体の通し番号で採番(年+連番、例 2026-00042。店舗宛・個人間とも)**。提供者へメール通知 |
| GET /requests | 自分が関わる申込み一覧(申込んだ/受けた、最終メッセージ付き) |
| GET /requests/{id} | 申込み詳細(品目リスト・状態・当事者) |
| PATCH /requests/{id} | 状態変更。提供者: accepted(accepted_at と accepted_by〔操作した担当者〕を記録)/ declined、申込者: cancelled、双方: completed(completed_at 記録=売上計上基準)。在庫は aiseed で扱わない(店側の責任) |
| GET /requests/{id}/messages | メッセージ一覧。開いたら相手の read_at 更新 |
| POST /requests/{id}/messages | 送信。相手が15分以上未読ならメール通知(申込みごとに未読解消まで1通) |
| POST /requests/{id}/reviews | 評価(completed 後、1申込みにつき各1回) |
| POST /reports | 通報 |
| POST /varieties | 品種マスタへの新規提案(pending) |
| POST /articles/{variety_id}/revisions | 辞典編集提案(pending) |
| GET /me/revisions | 自分の編集提案と状態 |

### 店舗スタッフ(shop_members に所属)

| メソッド/パス | 内容 |
|---|---|
| GET /shop/listings | 自店舗の全出品(全ステータス) |
| POST /shop/listings/import | CSV 一括出品。1行=1出品。品種名をマスタ照合し、結果レポート(成功/提案生成/エラー行)を返す |
| POST /shop/listings/bulk | 一括操作 {ids, action: publish/close/price, price_yen?} |
| GET /shop/requests | 店舗宛の全申込み(スタッフ共有。requested を上に) |
| GET /shop/export?format=xlsx|csv&kind=listings|deals | エクスポート。xlsx 生成は openpyxl。kind=deals は経理向け成約台帳: **申込番号(request_no)・店舗コード・受付日・承諾日・承諾担当者・成約日・相手・品目・数量・金額**。自店分のみ抽出 |
| GET /shop/stats | 出品ごとの閲覧数・申込み数 |
| PATCH /shop | 店舗プロフィール更新(owner のみ。特商法表示用に連絡先・返品方針・引き渡し時期を含む) |
| GET /shop/members | 店舗スタッフ一覧(担当名つき) |

### editor(辞典リビジョン承認。外部協力者が使う唯一の管理系)

| メソッド/パス | 内容 |
|---|---|
| GET /editor/revisions?status=pending | 承認待ち一覧(古い順)。記事タイトル・著者・edit_summary 付き |
| GET /editor/revisions/{id} | 詳細。**サーバー側で difflib により現行版とのセクション別差分を計算**し、行ごとに {text, op: keep/add/del} の構造で返す(Flutter は色を塗るだけ) |
| PATCH /editor/revisions/{id} | {action: approve/reject, review_note(reject時必須)}。承認で current_revision_id 更新+著者へメール(services 経由) |

editor の役割付与は運営者が管理アプリで行う。

### その他の管理系エンドポイントは存在しない

通報対応・品種承認・店舗/ユーザー管理は admin/(Flet・DB直結)が
backend の models / services を import して行う。
公開 API に /admin/* を実装しないこと(docs/07 参照)。
品種マスタ承認は登録品種チェック(種苗法)という法的判断を含むため、
editor には開放せず運営者に残す。

## エラー形式

```json
{ "detail": "human readable", "code": "REGISTERED_VARIETY" }
```

主なコード: `REGISTERED_VARIETY`(409) / `CONFIRMATION_REQUIRED`(422) /
`SEED_LABEL_REQUIRED`(422) / `FOOD_LABEL_REQUIRED`(422) /
`TOKUSHOHO_REQUIRED`(422) / `NOT_OWNER`(403) /
`SUSPENDED`(403) / `DUPLICATE_REVIEW`(409)

## メール送信(services/mail.py)

| トリガ | 宛先 | 内容 |
|---|---|---|
| 申込み受信 | 提供者 | 申込み内容(品目リスト)+リンク |
| 申込みの承諾/辞退 | 申込者 | 結果+リンク |
| メッセージ着信(15分未読) | 受信者 | 申込み名+抜粋+リンク |
| 品種提案の承認/却下 | 提案者 | 結果+記事リンク |
| 辞典リビジョンの承認/却下 | 著者 | 結果+差分要約 |
| 出品が flagged/removed | 出品者 | 理由+問い合わせ先 |

登録確認メールは PocketBase(SMTP設定で Stalwart を指定)が送る。

## 定期ジョブ

- 申込みの期限切れ: requested のまま一定期間(既定7日)承諾も辞退も
  ないものを expired(自動クローズ)にし、申込者・提供者にメール通知
- メッセージ未読15分でのメール通知(前掲)
- カタログJSONの再生成(下記)

## 店側在庫API連携(外部連携)

在庫の正は店側にあり、aiseed は在庫を持たない。
- 店側は在庫API(標準HTTP+JSON)を実装する。最小形:
  `GET /inventory` → `[{item_code, qty}, ...]`(品目コードと在庫数)。
  たねの森の現行の番号付き在庫表(0001 完売…)をそのまま返す形でも成立
- aiseed の在庫表示Widgetは、店側在庫APIの値を(バックエンド経由で)
  取得して表示。テスト段階は正確な数、表示粒度(内数)は後日決定
- 店側APIが応答しない場合は「在庫は店舗にお問い合わせください」を表示
  (自己完結型Widgetの error 状態)
- 申込みが入ったら店側APIへ通知(POST。形式は店ごとに相談)。
  在庫を減らすかどうかの判断は店側システムの責任
- つなぎ方は店側Webが自システムに繋ぐのと同じ標準HTTP+JSONに揃える

## 静的データ配信(Cloudflare)

読み取り専用の基本データは静的JSONとして Cloudflare(R2/Pages)から配信し、
アプリ機停止中も閲覧を成立させる:
- 対象: 品目(crops)・品種マスタ・辞典記事・店舗カタログ(出品の基本情報)
- 非対象: 在庫・カート・申込み・メッセージ・評価(動的。API必須)
- backend が対象データの更新時にJSONを生成し R2 へアップロード
- 在庫はカタログJSONに**含めない**(必ず店側在庫API経由。ずれ防止)
- カタログ表示が数分古いのは許容(取引時に最新をAPIで確認)

## QRコード(公開・認証不要)

紙・実物とアプリをつなぐ入口。生成はサーバー側(Python: segno)。
| メソッド/パス | 内容 |
|---|---|
| GET /qr/v/{variety_id}.png | 品種ページのQR。**種袋・店頭POPに印刷**→辞典(栽培方法)へ |
| GET /qr/l/{listing_id}.png | 出品ページのQR。店頭の現物棚→出品詳細へ |
| GET /qr/c/{crop_id}.png | 品目ページのQR(aiseed の品目ハブへ) |
| GET /qr/r/{request_no}.png | 申込みのQR。**同梱票に印刷**→受け取った人が申込み画面を開ける |

- 中身はURLのみ(例 https://…/v/{id})。go_router のディープリンクで開く
- サイズ・余白は印刷を想定した既定値(300px・quiet zone 4)。?size= で変更可
- 店舗の一括出品(CSV)後に「QRラベル一括PDF」を生成できると店頭作業が楽
  (Phase 5a に含める。1ページに面付け、品種名+QR)
