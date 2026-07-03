# 08 実装計画(Claude Code のフェーズ分割)

各フェーズは「テストが通り、動くものがある」状態で完了とする。
フェーズ内のタスクは上から順に。フェーズをまたいだ先回り実装はしない。
**3つの Flutter アプリは独立実装。共有は core(MIT)の配管のみ**
(CLAUDE.md「アプリ独立の原則」)。

## ステップ1(本体に先行): 軽量キット(docs/12)

- [ ] 商品台帳 xlsx の様式設計(名前付きセル・入力規則・在庫状態)
- [ ] カタログ HTML 生成(台帳→カテゴリ別一覧+品目ページ。docs/10 簡略)
- [ ] 注文様式 xlsx の自動生成(台帳から。FAX 兼用・記入例つき)
- [ ] 注文読み取り→注文台帳(番号採番)→請求書 xlsx 生成。未処理フォルダ
- [ ] たねの森へのデモ(動くものを見せる)

## Phase 0: リポジトリ初期化
- [ ] 公開リポジトリの構成作成(CLAUDE.md 通り)+ LICENSE(AGPL-3.0)配置
- [ ] SPDX ヘッダの雛形・チェックスクリプト(ruff/CI で検査)
- [ ] backend: FastAPI 雛形 + ruff + pytest + docker-compose
      (PostgreSQL + PocketBase。開発用)
- [ ] db/schema.sql を適用する初期化スクリプト(alembic は Phase 1 から)
- [ ] packages/core: 雛形(api_client / session / constants)
- [ ] apps/seed: 雛形(go_router + 下部ナビの空画面5つ)

## Phase 1: バックエンド基盤
- [ ] SQLAlchemy モデル(schema.sql と一致。テストで突合)
- [ ] PocketBase トークン検証ミドルウェア + app_users 自動作成
- [ ] GET /categories, GET/POST /listings, GET /listings/{id}
- [ ] 画像アップロード(Pillow で長辺1600pxに縮小)
- [ ] 出品バリデーション: 確認チェック必須(422)/ 登録品種ブロック(409)/
      自由入力品種 → varieties pending 自動生成 /
      指定種苗表示(requires_seed_label 時に氏名住所・生産地・発芽率必須、422)/
      個人出品は no_warranty 既定 true(業者品との区別表示)
- [ ] GET /varieties(pg_trgm 検索)
- [ ] pytest: 正常系・認可・法対応バリデーション

## Phase 2: 交換用アプリ MVP(閲覧+出品)
- [ ] core: モデル・ApiClient・Session(PocketBase ログイン)
- [ ] HomeScreen(CategoryGrid + NewListingsStrip)
- [ ] CategoryListingsScreen(無限スクロール)+ ListingCard
- [ ] ListingDetailScreen(PhotoCarousel, VarietyInfoTile, SellerTile)
- [ ] ログイン/登録画面(PocketBase、メール確認)
- [ ] PostListingScreen(VarietySuggestField・確認チェック含む)
- [ ] seed の Web ビルドが Cloudflare Pages で動くことを確認

## Phase 3: カート・申込み・評価・通知
- [ ] API: cart / requests / request_items / messages / reviews / reports
- [ ] 期限切れ: requested 放置(7日)を expired に自動クローズ(定期ジョブ)
- [ ] 申込番号: 全申込みに DB全体の通し番号(年+連番)を採番
      (行ロックでその年の最大+1。店舗・個人を区別しない)
- [ ] 処理時刻: accepted_at / completed_at の記録
- [ ] メール送信 services/mail.py(Stalwart SMTP、抽象化+relay切替)
- [ ] 申込み受信・承諾/辞退の即時メール、未読15分のメッセージ通知(定期ジョブ)
- [ ] CartScreen(提供者ごとグループ)/ RequestListScreen /
      RequestScreen(10秒ポーリング)/ ReviewPrompt / 通報UI
- [ ] MyPageScreen(出品管理・申込み・評価)

## Phase 4: 辞典連携
- [ ] API: articles / revisions(提案受付)。承認フロー・記事枠自動作成は
      services に実装(admin から共有)。GET /articles/export(認証不要)
- [ ] VarietyArticleScreen / ArticleEditScreen(投稿画面に CC BY-SA 同意文)/
      RelatedListingsStrip / マイページ貢献タブ
- [ ] editor API(一覧 / 差分付き詳細〔difflib はサーバー側〕/ 承認・却下)
- [ ] RevisionQueueScreen / RevisionReviewScreen(role=editor 以上のみ表示)
- [ ] 検索画面(品種+出品横断)

## Phase 5: 販売用アプリ
- [ ] API: shop 系一式(listings/import CSV 照合、bulk、export xlsx/CSV、
      stats、店舗宛 requests)。export kind=deals は成約台帳
      (申込番号・受付/承諾/成約日・相手・品目・数量・金額)
- [ ] apps/shop: レスポンシブ骨格(LayoutBuilder、900px 境界)→
      初回の担当名登録 → ダッシュボード → 出品管理(モバイル=カード+
      長押し選択 / ワイド=テーブル)→ 申込み対応(承諾担当者を記録)→
      CSV取込・エクスポート(ワイドのみ)→ 店舗設定(担当名編集)
- [ ] iOS/Android ビルド確認(スマホでの問い合わせ対応が通ること)
- [ ] CSV テンプレートとサンプルデータ(ダミー20品種)

## Phase 5a: 店側在庫API連携+静的配信
- [ ] 店側在庫APIの最小実装(Python。品目コードと在庫数を返す。
      たねの森の番号付き在庫表を返す形から始める)
- [ ] aiseed/seed の在庫表示を店側在庫API経由に(テスト段階は正確な数)。
      店側API不応答時は「在庫は店舗にお問い合わせください」
- [ ] 申込みの店側通知(POST。形式は店ごとに相談できる土台)
- [ ] カタログJSON生成→R2アップロード(品目・品種・辞典・店舗カタログ。
      在庫は含めない)。Flutter のカタログ系Widgetは静的JSONを読む
- [ ] QR: 生成API(segno。品種/出品/品目/申込番号)、QRラベル一括PDF、
      Flutter の QrScanScreen(mobile_scanner)

## Phase 5b: 生産物対応(seed / shop 両方)
- [ ] item_kind=produce、delivery_method(直接/郵送)、payment_default
      (後払い既定)を出品フォーム・API・カードに追加
- [ ] 生産物×郵送で食品表示必須(422)、郵送事業者で特商法表示(422)
- [ ] 店舗プロフィールに特商法項目(連絡先・返品方針・引き渡し時期)
- [ ] docs/11 の歯止め遵守(加工品・許可要食品は作らない)

## Phase 6: 統合利用者アプリ+管理アプリ
- [ ] admin/(Flet・公開リポジトリ・MIT・DB直結): backend の
      models / services を import。通報キュー → 品種承認(品種登録DB
      外部リンク付き)→ 辞典リビジョン承認(difflib 差分)→ 店舗管理 →
      ユーザー管理 → ダッシュボード。/admin/* API は作らない
- [ ] API: GET /crops, GET /crops/{id}(品目ハブ用の集約)
- [ ] 非公開リポジトリ作成(core を git 依存で参照)
- [ ] aiseed を独立実装: CropGrid / CropHub(品目軸)→
      出品・カート・申込み・辞典・editor 承認 → 店舗モード
      (仕様は docs/04/05 に準ずる。コードは本アプリ内に自己完結)
- [ ] 管理アプリの品種承認に品目紐付け(crops 新規作成含む)を実装
      (Phase 6 で admin/ に追加)

## Phase 7: デプロイ・運用
- [ ] deploy/: Caddyfile、systemd unit、nftables の Cloudflare IP 許可
      スクリプト(cron 更新)
- [ ] rclone バックアップ(pg_dump + images → R2/B2)+ リストア手順書
- [ ] PocketBase の SMTP を Stalwart に設定する手順書
- [ ] 本番 smoke test(登録→メール確認→出品→問い合わせ→評価の通し)

## Phase 8: セールス・公開準備
- [ ] デモ用シードデータ(伝統野菜30品種+出品50件+辞典記事10本)
- [ ] たねの森向け提案資料の素材: スクリーンショット、運用費試算、
      種苗法対応1ページ、事務基盤(OnlyOffice+メール)同時提案ページ、
      並行稼働の説明
- [ ] 野口のタネ向け: 種の森・出店プラン提案(月額定額+事務基盤
      オプション)の骨子
- [ ] 利用規約・プライバシーポリシー草案(登録品種禁止・決済非関与・
      **送料規定〔販売・譲渡は送料別、交換は各自負担〕**・
      **指定種苗の表示義務の説明と出品者責任の免責**・
      **個人品は家庭採種・無保証(性質表示であり義務回避手段ではない旨)**・
      個人間取引の免責・辞典投稿の CC BY-SA 同意)
- [ ] 店舗向け利用契約書の草案(出店プラン。専門家レビュー前提のたたき台)
- [ ] 公開リポジトリ README に PR 歓迎(inbound=outbound)と
      ストア配布追加許可の説明を明記
- [ ] 公開リポジトリの README(コミュニティ向け)整備
