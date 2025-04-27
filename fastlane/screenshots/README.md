# スクリーンショットについて

このディレクトリはApp Storeに表示するスクリーンショットを保存するためのものです。

## ディレクトリ構造

```
screenshots/
├── iphone/     # iPhone用スクリーンショット
│   ├── ja/     # 日本語
│   └── en-US/  # 英語（米国）
└── ipad/       # iPad用スクリーンショット
    ├── ja/     # 日本語
    └── en-US/  # 英語（米国）
```

## ファイル名の規則

スクリーンショットは数字順に表示されるため、ファイル名の先頭に番号を付けることをお勧めします。
例：

- `1_ホーム画面.png`
- `2_録音画面.png`
- `3_プレイリスト.png`
- `4_音声編集.png`
- `5_設定画面.png`

## App Storeへのアップロード

以下のコマンドで、スクリーンショットをApp Store Connectにアップロードできます：

```
bundle exec fastlane update_screenshots
```

## スクリーンショットのサイズ

App Storeに表示するスクリーンショットは、以下のサイズガイドラインに従ってください：

### iPhone

- iPhone 6.7" (iPhone 14 Pro Max): 1290 x 2796
- iPhone 6.5" (iPhone 14 Pro): 1242 x 2688
- iPhone 5.5" (iPhone 8 Plus): 1242 x 2208
- iPhone 5.8" (iPhone X/XS): 1125 x 2436

### iPad

- iPad Pro (12.9-inch): 2048 x 2732
- iPad Pro (11-inch): 1668 x 2388
- iPad (10.2-inch): 1620 x 2160

## その他

スクリーンショットには効果的なキャプションを付けることで、アプリの機能を強調することができます。
キャプションはApp Store Connectで直接設定するか、Fastlaneの設定で自動的に付けることができます。 