# CLAUDE.md — kit(軽量キット)

仕様は docs/step1.md が正。Python のみ・DB なし・完全独立。

## 命名規約
手で打つ名前は短く、アンダースコアを使わない(複数語はハイフン)。
Python モジュールは小文字で短く。

## Python 規約
- Python 3.12+ / ruff(format+lint)/ 型ヒント必須 / pytest
- xlsx の読み書きは openpyxl。様式は名前付きセルで読む
  (セル座標のハードコード禁止)。QR が要る場合は segno
- 読み取れない注文ファイルは「未処理」フォルダへ移す(黙って捨てない)

## 構成
catalog.py(台帳→HTML)/ forms.py(台帳→注文様式)/
invoice.py(注文→台帳記帳・請求書)/ templates/ / tests/

## してはいけないこと
- DB・サーバー・Webフレームワークの導入(スクリプトで完結が仕様)
- 決済の実装
- 本体リポジトリ(backend 等)への依存
