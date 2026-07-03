# kit — 軽量キット(ステップ1)

カタログHTML+注文の神Excel+請求書。DB・サーバー・アプリ不要、
店の**商品台帳 xlsx が正**。仕様は `docs/reps/kit-v1/docs/step1.md`。
MIT(店に渡して自由に使ってよい)。本体アプリ群とは完全に独立。

## 必要なもの

Python 3.11+ と openpyxl(`pip install openpyxl`)。
PDF 取込(pamphlet.py)を使う場合は pdfplumber も
(`pip install pdfplumber`)。

## 使い方

```bash
# 0. (任意)既存のカタログ PDF から台帳を起こす
#    PDF は kit/data/ に置く(第三者の著作物のためコミットしない)
python pamphlet.py data/2026main.pdf -o 台帳.xlsx

# 1. 商品台帳の雛形を作る(--sample でサンプル商品入り)
python ledger.py 台帳.xlsx --sample

# 2. 台帳からカタログ HTML を生成(Cloudflare Pages 等に置く)
python catalog.py 台帳.xlsx -o catalog

# 3. 台帳から注文書 xlsx を生成(カタログから配布。印刷すれば FAX 注文書)
python forms.py 台帳.xlsx -o catalog/注文書.xlsx

# 4. 受信した注文 xlsx を「注文受信/」に入れて実行
#    → 注文台帳に記帳(注文番号=年+連番)+ 請求書/請求書-XXXX.xlsx を生成
#    読み取れないファイルは 注文受信/未処理/ へ移動(黙って捨てない)
python invoice.py 台帳.xlsx --inbox 注文受信 --out 請求書 --book 注文台帳.xlsx
```

## 台帳の様式

- 「商品」シート: 品番・品種名・種別(固定種/在来種/F1)・価格・説明・
  生産地・発芽率・在庫状態(販売中/品切れ/終了)・カテゴリ
- 「設定」シート: 店名・住所・電話・メール・振込先・税率・税込表示
- 読み取りは名前付きセル基準(セル座標のハードコードなし)。
  列の並べ替えは可、列名の変更は不可

## 開発

```bash
pip install -e ".[dev]"
pytest        # テスト
ruff check .  # lint
ruff format . # 整形
```
