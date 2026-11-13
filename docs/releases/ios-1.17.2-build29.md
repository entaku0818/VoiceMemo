# iOS 1.17.2 (29) 再提出

- 提出日時: 2026-10-24 14:36 JST
- 確認状態: WAITING_FOR_REVIEW
- 公開設定: AFTER_APPROVAL（既存設定を維持）
- App ID: 6443528409
- Version ID: e953ab92-afcd-4a32-b087-a18f8ca92351
- Build ID: 32a1d630-0781-476e-89df-05020991e44c
- Review submission ID: 147b2c6b-5dc0-485e-81c0-88d6e738ab87
- Source commit: e4772616
- Release: https://github.com/entaku0818/VoiceMemo/releases/tag/v1.17.2-build29
- Branch: codex/voilog-1.17.2-build29
- IPA SHA-256: fbc7fecd81625beed6c80ab64c1bf26503c1d42ac1ad4f2778ee46f87fefe820

ビルド28の提出ソース dd04c3dd を引き継ぎ、RevenueCatをUI表示前に同期初期化する修正と回帰テストを追加。Xcode 27.1 (27A9275) のアーカイブ・IPA書き出しに成功。購入・無料トライアル・ペイウォール関連48テスト成功。

50言語のリリースノートを更新し、その他のローカライズ項目が変わっていないことをAPIで照合。既存のスクリーンショットを維持。ビルド28の申請を取り下げ、29へ差し替えて再提出した。最初の提出APIは500エラーとなったが、作成済み申請を再利用した再試行が成功し、選択ビルド29と審査待ちを読み直して確認済み。

作業用ソース: /private/tmp/voilog-release-29
元のワークスペースには他作業の未コミット変更があるため、配布物は提出済みソースを基にした専用クローンで作成。元ワークスペースのmainにはリリースコミットをまだ統合していない。
