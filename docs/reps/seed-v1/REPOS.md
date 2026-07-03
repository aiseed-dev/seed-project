# 種の交換アプリ リポジトリ分割(7リポジトリ)

アプリ独立の原則をリポジトリ境界にする。ライセンス境界=リポジトリ境界。
横断仕様(要件・API・実装計画・スキーマ)の正は backend リポジトリの docs/。

| リポジトリ | 内容 | ライセンス | 依存 |
|---|---|---|---|
| kit | ステップ1軽量キット(最初に実装) | MIT | なし(完全独立) |
| backend | FastAPI+schema+横断仕様書 | AGPL-3.0 | なし |
| core | Dart共有パッケージ(配管のみ) | MIT | なし |
| seed | 交換用アプリ(Flutter) | AGPL+ストア許可 | core(git) |
| shop | 販売用アプリ(Flutter) | AGPL+ストア許可 | core(git) |
| admin | 運営管理(Flet) | MIT | backend(pip git) |
| aiseed | 種の森(非公開・独立実装) | 非公開 | core(git)のみ |

## コピー禁止則(リポジトリ境界で単純化)
外部コントリビュート受け入れ後、AGPL リポジトリ(backend/seed/shop)の
コードを aiseed へコピーしない。core(MIT)は制限なく利用可。

## 作成コマンド(Forgejo に7つ作った後、各リポジトリ直下で)
```bash
# kit / backend / admin / core: この zip の各フォルダを展開して git init
# seed / shop / aiseed(Flutter はリポジトリ直下がプロジェクトルート):
flutter create --org dev.aiseed --project-name seed --platforms=ios,android,web .
flutter create --org dev.aiseed --project-name shop --platforms=ios,android,web,windows,macos .
flutter create --org dev.aiseed --project-name aiseed --platforms=ios,android,web .
```

## 依存の張り方
```yaml
# seed / shop / aiseed の pubspec.yaml
dependencies:
  core:
    git:
      url: https://(Forgejo)/core.git
```
```bash
# admin(backend を import するため)
pip install git+https://(Forgejo)/backend.git
```
