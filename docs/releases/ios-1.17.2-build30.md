# iOS 1.17.2 (30) 再提出

- 提出日: 2026-10-25 JST
- 確認状態: WAITING_FOR_REVIEW
- 公開設定: AFTER_APPROVAL（既存設定を維持）
- App ID: 6443528409
- Version ID: e953ab92-afcd-4a32-b087-a18f8ca92351
- Build ID: f1585aef-b5ee-4299-bbab-f0221e076fb6
- Review submission ID: 7f4e2398-32d6-4e1a-8ed2-c1896898611d
- 配布ソース: d0f6dc46 (codex/voilog-app-open-release-30)
- IPA SHA-256: ee9e24d4e8536418fbd0f7912c050768be2c6b5a8cf9b15059b92b3272c47597

ビルド29の提出ソース e4772616 を基に、起動広告の読み込み中の待機要求を保持し、完了・失敗を通知する修正を反映。関連5テスト成功済み。Xcode 27.1でReleaseアーカイブ・IPA書き出し・アップロード成功。

50言語の更新説明を反映。その他のメタデータ属性・公開設定の維持をAPIで照合。新ビルドがVALIDになってから29の申請を取り下げ、30を関連付けて再提出。Apple APIの500エラー後、既存申請を再利用して成功。選択ビルド30と審査待ちを再取得して確認。

専用ソース: /private/tmp/voilog-release-30
元ワークスペースには他作業の未コミット変更があるため、mainに統合していない。
GitHub pushは自動承認レビューで拒否され、ユーザーの公開操作承認待ち。コミット・タグはローカルに保存済み。
