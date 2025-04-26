# ComposableArchitecture テンプレート

このディレクトリには、ComposableArchitecture (TCA) を使用した機能開発のためのテンプレートファイルが含まれています。

## FeatureTemplate.swift

`FeatureTemplate.swift` は以下の機能を提供する基本的なTCAパターンを含んでいます:

- 検索機能付きのリスト表示
- リストアイテムのお気に入り登録機能
- プルダウンでのリフレッシュ機能
- ローディング状態の表示

### 使用方法

1. `FeatureTemplate.swift` をコピーして新しいファイルを作成
2. `FeatureReducer` と `FeatureView` を新しい機能名に変更
3. `State` 構造体を機能に必要なプロパティで拡張
4. `Action` 列挙型に必要なアクションを追加
5. `Item` 構造体を実際のデータモデルに合わせて調整
6. `body` メソッド内のreducerロジックを実装
7. `FeatureView` のUI部分をカスタマイズ

### 例

```swift
// MyCustomFeature.swift
import SwiftUI
import ComposableArchitecture

@Reducer
struct MyCustomFeature {
  @ObservableState
  struct State: Equatable {
    // プロパティをカスタマイズ
  }
  
  // ... 他のコードを調整
}

@ViewAction(for: MyCustomFeature.self)
struct MyCustomView: View {
  // ... UIをカスタマイズ
}
```

## 注意事項

- このテンプレートはComposableArchitecture v1.5以降を対象としています
- @ObservableStateと@ViewActionパターンを使用しています
- Previewセクションを含んでいるため、すぐにUIを確認できます 