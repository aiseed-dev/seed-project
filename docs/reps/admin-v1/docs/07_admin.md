# 07 管理アプリ(Flet / Python)仕様

対象: 運営者。**Flet 製(Python)、DB 直結**。Flutter・core・公開APIには
依存しない。**MIT ライセンスで公開リポジトリに置く**。

## 位置づけと接続方式(重要)

- **公開 API に管理系エンドポイントは存在しない。** 管理操作はこのアプリが
  PostgreSQL に直接接続して行う。管理面がインターネットに露出しないため、
  API 経由方式より攻撃面が小さい
- **backend を Python パッケージとして import する**:
  - `app.models`(SQLAlchemy)… スキーマ変更に自動追随
  - `app.services` … 品種承認→記事枠自動作成、却下→出品flagged化、
    承認/却下のメール通知などの業務ロジックを共有。
    **管理アプリ内に業務ロジックを再実装しないこと**
- 認証: なし(アプリを起動できる=サーバー/DB認証情報にアクセスできる人が
  運営者)。DATABASE_URL は backend と同じ .env を読む
- ライセンス注記: admin/(MIT)は backend(AGPL)に依存するが、
  Python ソースとして配布する限り MIT のままで問題ない
  (組み合わせは各運営者の手元で行われる)

## 実行形態

- サーバー上で `flet run --web --port 8550`(localhost バインド)
  → 手元から `ssh -L 8550:localhost:8550` でブラウザ表示。
  DB・SMTP(Stalwart)とも localhost で完結し、メール通知も動く
- サーバーに直接向かえる環境ならデスクトップ実行(`flet run`)でも可
- ストア配布はしない

## 構成

```
admin/                     … 公開リポジトリ直下(MIT)
  pyproject.toml           … 依存: flet + backend(path 依存)。Python 3.12+
  main.py                  … 左ナビ+メインペイン
  views/
    reports.py             … 通報キュー
    varieties.py           … 品種マスタ承認
    revisions.py           … 辞典リビジョン承認(difflib で差分表示)
    shops.py               … 店舗管理
    users.py               … ユーザー管理
    dashboard.py           … ダッシュボード
```

各 view が自分でクエリと状態を持つ自己完結型。DB セッションは
backend の sessionmaker を使い、書き込みは必ず services 経由。

## 画面(機能は従来仕様のまま)

### 通報キュー
- open の通報を古い順。reason=registered_variety は最上部に固定+赤ラベル
- 行を開くと対象(出品/メッセージ/ユーザー/品種/リビジョン)のプレビュー
- 対応: 出品を停止(flagged)/ 削除(removed)/ ユーザー凍結 / 却下。
  note 必須。対応時のメール通知は services 経由で送信

### 品種マスタ承認
- pending 一覧。提案元(出品からの自動生成 or 手動)と提案者を表示
- 詳細ペイン: 名前・かな・分類・**品目(crops への紐付け。無ければ新規作成)**
  を編集してから承認できる(表記ゆれの正規化はここで行う。
  品目紐付けは統合アプリの品目ハブに品種を載せるための必須作業)
- 登録品種チェック支援: 農水省「品種登録データベース」の検索URLを
  品種名から組み立てて既定ブラウザで開くボタン。照合結果を
  registration_note に記録。登録品種なら is_registered_variety を立てて
  却下 → 紐づく出品の flagged 化は services が行う
- 承認 → 辞典記事枠の自動作成も services が行う

### 辞典リビジョン承認
- pending 一覧(古い順)。現行版との差分は **difflib** をセクション単位で
  整形表示(追加=緑・削除=赤)
- 承認 / 却下(却下時 review_note 必須)。承認で
  articles.current_revision_id 更新+著者へメール(services)

### 店舗管理
- 店舗一覧・新規作成(slug/店名/**店舗コード**〔経理識別用〕)・
  認証バッジON/OFF・出店プランの有効/無効(shops.is_active)
- スタッフ紐付け: ユーザー検索 → shop_members に追加/削除

### ユーザー管理
- 検索(表示名)・凍結/解除・役割変更
- ユーザー詳細: 出品・通報履歴・辞典貢献

### ダッシュボード
- 出品数(種別内訳)・成約数・辞典記事数・登録ユーザー数
- 週次推移は数値テーブルで可(グラフは必須ではない)

## editor との分担(当初からの仕様)

辞典リビジョンの承認は外部協力者(editor)が Flutter アプリ内の承認画面
から行う(editor API 経由。docs/03 参照)。管理アプリにも同じリビジョン
承認画面を残す(運営者が使う。どちらの経路も同じ services を呼ぶ)。
品種マスタ承認・通報・店舗/ユーザー管理は管理アプリ専任。
editor の役割付与はユーザー管理画面で行う。

## 実装メモ

- 承認系一覧は手動リロード(複数人同時運用は当面なし。楽観ロック不要)
- すべての承認/却下は確認ダイアログを挟む
- ruff / pytest は backend と同じ設定を流用
