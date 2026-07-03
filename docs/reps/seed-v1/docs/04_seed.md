# 04 交換用アプリ(Flutter)画面仕様

対象: iOS / Android / Web。個人の交換・販売・譲渡。**AGPL-3.0・無料**(LICENSING.md 参照)。
ホームは分類グリッド。見た目は docs/10 の種苗カタログ様式に従う
(フリマ風の回遊構造+カタログ様式のカード)。

**実装場所**: 画面はこのアプリ内(`apps/seed`)に自己完結で
実装する(アプリ独立の原則)。他アプリと共有するのは core(MIT)の
配管(APIクライアント・モデル・ListingCard 等の共通Widget)のみ。

状態管理ライブラリ不使用。各Widgetが自分でデータ取得する自己完結型。

## ルーティング(go_router)

```
/                        HomeScreen
/c/:categorySlug         CategoryListingsScreen
/l/:listingId            ListingDetailScreen
/post                    PostListingScreen(認証必須)
/cart                    CartScreen(認証必須)
/requests                RequestListScreen(認証必須)
/requests/:id            RequestScreen(認証必須)
/me                      MyPageScreen(認証必須)
/v/:varietyId            VarietyArticleScreen(辞典記事)
/v/:varietyId/edit       ArticleEditScreen(認証必須)
/login /register         認証(PocketBase)
/search?q=               SearchResultScreen
/scan                    QrScanScreen(mobile_scanner。読み取ったURLを
                         go_router で開く。カメラ権限が必要)
/editor/revisions        RevisionQueueScreen(role=editor 以上のみ)
/editor/revisions/:id    RevisionReviewScreen(同上)
```

下部ナビ(モバイル): ホーム / 検索 / 出品(+) / カート(バッジ付き)/ マイページ
(申込み一覧はマイページから。Web はヘッダーに同項目)
Web はヘッダーに同項目。未認証で認証必須画面に入ったら /login へ。

## 画面別仕様

### HomeScreen
- AppBar: ロゴ + 検索バー(タップで /search)+ QRアイコン(→ /scan。
  種袋・店頭POPのQRから品種・出品ページへ直行できる)
- `CategoryGrid` … 2列×4行(Web は4列)。分類アイコン+名前。
  タップで /c/:slug
- `NewListingsStrip` … 「新着」横スクロール。ListingCard の小型版
- 各部品は独立した StatefulWidget。CategoryGrid は /categories を、
  NewListingsStrip は /listings?limit=10 を各自 fetch

### CategoryListingsScreen
- `ListingGrid` … 2列カード(Web 3〜4列)、無限スクロール(cursor)
- `ListingCard` … docs/10「出品カードの解剖」に厳密に従う
  (写真+種別バッジ / キャッチコピー〔辞典から〕/ 品種名 / チップ /
  スペック行〔蒔き時は辞典から自動〕/ 条件行 / 主ボタン)
- フィルタバー: 種別(交換/販売/譲渡)・種/苗・地域

### ListingDetailScreen
- `PhotoCarousel`(スワイプ+インジケータ)
- タイトル・種別バッジ・価格 or 希望品
- `VarietyInfoTile` … 品種名・分類・固定種/在来種。タップで /v/:varietyId
  (variety_id 無し=自由入力品種は「辞典準備中」表示)
- 採種年・自家採種・地域・栽培メモ
- 指定種苗表示欄(requires_seed_label 時): 表示者氏名住所・生産地・
  発芽率・種子消毒等を「指定種苗表示」枠でまとめて表示
- 個人品(no_warranty 時): 「家庭採種品です。発芽・生育は保証されません」
  の注記を控えめに表示
- 生産物かつ郵送: 食品表示欄(名称・原産地・生産者・収穫日・保存方法)
- 郵送の事業者: 「特定商取引法に基づく表示」欄(氏名住所・連絡先・
  価格・送料・支払方法と時期・引き渡し時期・返品条件)
- 支払い: 既定(後払い等)を表示。「支払い方法は当事者間の協議」の注記
- `SellerTile` … 出品者(or 店舗)名・評価★・地域。
- 数量ステッパー+下部固定ボタン「カートに入れる」→ PUT /cart/items
  (追加後はスナックバー「カートに追加しました」+カートバッジ更新)。
  店舗出品は店側在庫APIの値を表示(テスト段階は正確な数。表示粒度は
  後日決定)。在庫なしは品切れ表示でボタン無効。個人出品は在庫表示なし
- 「⋯」メニュー: 通報 / (本人なら)編集・取引完了・削除

### PostListingScreen(ステップ形式1画面)
1. `PhotoPickerRow`(最大4枚、image_picker)
2. 分類選択(チップ)
3. `VarietySuggestField` … 入力のたび GET /varieties?q= を
   debounce(300ms)で呼びサジェスト。「見つからない→この名前で出品」
   を選ぶと自由入力扱い(投稿時にマスタ提案が自動生成される旨を小さく表示)
4. 品目種別(種 / 苗 / 生産物)、取引種別(交換・販売・譲渡)、
   受け渡し(直接 / 郵送)、支払い既定(後払い〔既定〕/ 前払い / 着払い)
5. 種別に応じて: 希望品テキスト or 価格(数値)
6. 採種年(任意)・自家採種スイッチ・地域(都道府県ピッカー)・栽培メモ
7. **確認チェック**「品種登録されていない一般品種(固定種・在来種)です」
   … 未チェック時は投稿ボタン無効。ヘルプ(?)で種苗法の簡単な説明シート
8. **指定種苗の表示**(販売・譲渡で表示):
   「反復継続して販売しています(種苗業者に該当)」スイッチ。
   ON(店舗出品は既定ON・固定)のとき表示欄を必須表示 —
   表示者氏名/名称・住所(店舗はプロフィールから補完)・生産地(都道府県)、
   種子は発芽率(例: 2025年10月現在 80%以上)、種子消毒等(任意)。
   ヘルプ(?)で指定種苗の表示義務を短く説明。
   OFF(個人)のときは no_warranty 既定 ON で「家庭採種・発芽保証なし」
   の注記が付く旨を小さく表示(義務欄は出ない)
8b. **食品表示**(生産物かつ郵送のとき必須): 名称・原産地・生産者・
    収穫日・保存方法。ヘルプ(?)で生鮮食品の表示を短く説明
8c. **特商法表示**(郵送の事業者): requires_tokushoho ON のとき、
    連絡先・返品方針・引き渡し時期(店舗はプロフィールから補完)
9. 投稿 → 詳細画面へ

### CartScreen
- **提供者(店舗 or 個人)ごとのグループ表示**。グループヘッダに
  提供者名(認証店は✓)、グループ内に品目行(サムネ・品種名・種別・
  数量ステッパー・価格 or 交換/譲渡・削除)
- 販売品はグループ小計を「小計 ¥○○(送料別)」と表示
  (参考額。送料実費と支払方法は申込み後のメッセージで合意)
- 譲渡品には「送料別」、交換品には注記なし(各自負担)
- グループごとに「申込みを送る」ボタン(一言メッセージ添付可)
  → POST /requests → RequestScreen へ
- 取引中/終了になった品目はグレー表示+「入手できなくなりました」

### RequestListScreen / RequestScreen
- 一覧: 相手名+品目数+状態バッジ(申込み中・取引中・完了・辞退)+
  最終メッセージ+未読ドット。「申込んだ」「受けた」タブ
- 申込み画面: 上部に品目リスト(折りたたみ可)と状態、
  提供者には「承諾する / 辞退する」、申込者には「取り下げる」、
  取引中は双方に「完了にする」(両者操作で completed)
- 以下は LINE 風の吹き出しメッセージ。completed 後は
  `ReviewPrompt`(★5段階+コメント)を吹き出し列に挿入
- ポーリング: 画面表示中のみ10秒間隔で GET(WebSocket は使わない)

### MyPageScreen
- プロフィール(編集)/ 出品タブ(公開中・取引中・終了)/ 申込みタブ
  (RequestListScreen へ)/ 評価タブ / 辞典への貢献タブ

### VarietyArticleScreen(辞典)
- 品種ヘッダ(名前・かな・別名・分類・来歴地域)
- セクション表示: 歴史 / 栽培方法 / 採種方法 / 料理 / 出典
- `RelatedListingsStrip` … この品種の出品中一覧(交換アプリへの逆導線)
- 「編集を提案」ボタン → ArticleEditScreen(セクションごとの
  テキストエリア+変更概要)→ 送信で「承認後に公開されます」

### RevisionQueueScreen / RevisionReviewScreen(editor のみ)
- GET /me の role が editor 以上のときだけ、マイページに「承認」項目が出る
  (role が満たない場合ルートに入っても 403 表示)
- キュー: 承認待ち一覧(記事名・著者・変更概要・提案日、古い順)
- レビュー: セクションごとに API が返す差分構造を描画
  (op=add は緑背景、op=del は赤背景+取り消し線、keep は通常。
  **差分計算はサーバー側。Flutter では diff を実装しない**)
- 承認 / 却下ボタン(却下時は review_note 入力必須)。確認ダイアログあり
- スマホでの承認作業を想定したレイアウト(セクション折りたたみ)

## core パッケージ(3アプリ共有)

```
lib/
  api_client.dart      … http ラッパ。BaseURL・Bearer 付与・エラー型
  session.dart         … 認証状態のシングルトン(トークン保持・login/logout)
  models/              … Listing, Variety, Thread, Message, Shop, ...
                         (fromJson 手書き。コード生成は使わない)
  widgets/
    listing_card.dart
    type_badge.dart
    shop_badge.dart
    photo_carousel.dart
    variety_suggest_field.dart
  constants.dart       … 配色(docs/10 のパレット)・分類アイコン対応表
```

## 自己完結型Widgetの実装パターン(統一)

```dart
class NewListingsStrip extends StatefulWidget { ... }

class _NewListingsStripState extends State<NewListingsStrip> {
  List<Listing>? _items;   // null=読込中
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final items = await ApiClient.i.fetchListings(limit: 10);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = '読み込めませんでした');
    }
  }
  // build: _error → リトライボタン付きエラー表示
  //        _items == null → スケルトン
  //        それ以外 → 本体
}
```

全Widgetでこの「null=読込中 / error / データ」3状態+リトライを統一する。
