# 音声編集機能実装プラン

## 1. 機能概要

シンプル録音アプリに以下の音声編集機能を追加します：

### 1.1 基本編集機能
- **トリミング**: 音声の不要な部分をカットする
- **分割**: 1つの録音を複数の録音に分ける
- **結合**: 複数の録音を1つにまとめる
- **音量調整**: 録音全体または特定部分の音量を調整する
- **無音部分の自動削除**: 無音部分を自動的に検出して削除する

### 1.2 エフェクト機能
- **ノイズリダクション**: 背景ノイズを軽減する
- **イコライザー**: 音質調整（低音・中音・高音のバランス調整）
- **音声強調**: 人の声を強調する
- **リバーブ/エコー**: 空間的な効果を追加する

### 1.3 高度な機能（プレミアム限定）
- **音声テキスト変換**: 録音を自動的にテキストに変換する
- **キーワード検索**: 音声内の特定のキーワードを検索する
- **話者分離**: 複数の話者を識別して分離する
- **BGM追加**: 背景音楽を追加する機能

## 2. UI設計

### 2.1 編集画面のレイアウト
- 波形表示エリア（選択可能な領域）
- 編集ツールバー（トリミング、分割、結合などのアクション）
- エフェクトパネル（ノイズリダクション、イコライザーなどの設定）
- 再生コントロール（再生、一時停止、巻き戻し、早送り）
- 保存/キャンセルボタン

### 2.2 波形表示
- ピンチジェスチャーによるズームイン/アウト
- スワイプによるスクロール
- タップ&ドラッグによる範囲選択
- 選択範囲のハイライト表示

### 2.3 編集操作のUI
- トリミング: 選択範囲の両端にハンドルを表示
- 分割: 分割ポイントを示すマーカーを表示
- 結合: 結合する録音のプレビュー表示
- 音量調整: スライダーまたは波形の高さを直接操作

## 3. 技術実装

### 3.1 使用するフレームワーク
- **AVFoundation**: 基本的な音声処理
- **AudioKit**: 高度な音声処理とエフェクト
- **Speech Framework**: 音声認識（テキスト変換）
- **CoreML**: 話者分離や音声分析

### 3.2 データモデルの拡張
```swift
extension VoiceMemoReducer.State {
    // 編集履歴を保存するための配列
    var editHistory: [EditOperation] = []
    // 適用されたエフェクトのリスト
    var appliedEffects: [AudioEffect] = []
    // 元の音声ファイルへの参照（編集前の状態に戻すため）
    var originalAudioURL: URL?
}

// 編集操作を表す列挙型
enum EditOperation: Equatable {
    case trim(startTime: Double, endTime: Double)
    case split(atTime: Double)
    case merge(withMemoID: UUID)
    case adjustVolume(level: Float, range: TimeRange?)
    case applyEffect(effect: AudioEffect)
    // その他の編集操作...
}

// オーディオエフェクトを表す構造体
struct AudioEffect: Equatable, Identifiable {
    let id: UUID
    let type: EffectType
    let parameters: [String: Any]
    
    enum EffectType: String {
        case noiseReduction
        case equalizer
        case voiceEnhancement
        case reverb
        // その他のエフェクト...
    }
}
```

### 3.3 主要な実装コンポーネント

#### 3.3.1 AudioEditorReducer
```swift
struct AudioEditorReducer: Reducer {
    struct State: Equatable {
        var memoID: UUID
        var audioURL: URL
        var waveformData: [Float] = []
        var selectedRange: ClosedRange<Double>?
        var currentPlaybackTime: Double = 0
        var isPlaying: Bool = false
        var appliedEffects: [AudioEffect] = []
        var editHistory: [EditOperation] = []
        var isEdited: Bool = false
    }
    
    enum Action {
        case loadAudio
        case audioLoaded(waveformData: [Float])
        case selectRange(ClosedRange<Double>?)
        case trim
        case split
        case adjustVolume(Float)
        case applyEffect(AudioEffect)
        case playPause
        case seek(to: Double)
        case save
        case cancel
        // その他のアクション...
    }
    
    // Reducer実装...
}
```

#### 3.3.2 AudioProcessingService
```swift
protocol AudioProcessingServiceProtocol {
    func trimAudio(at url: URL, range: ClosedRange<Double>) -> AnyPublisher<URL, Error>
    func splitAudio(at url: URL, atTime: Double) -> AnyPublisher<[URL], Error>
    func mergeAudio(urls: [URL]) -> AnyPublisher<URL, Error>
    func adjustVolume(at url: URL, level: Float, range: ClosedRange<Double>?) -> AnyPublisher<URL, Error>
    func applyNoiseReduction(at url: URL, level: Float) -> AnyPublisher<URL, Error>
    func applyEqualizer(at url: URL, bands: [Float]) -> AnyPublisher<URL, Error>
    // その他の処理メソッド...
}
```

#### 3.3.3 WaveformView
```swift
struct WaveformView: View {
    let waveformData: [Float]
    let selectedRange: ClosedRange<Double>?
    let currentTime: Double
    let onRangeSelected: (ClosedRange<Double>?) -> Void
    let onSeek: (Double) -> Void
    
    var body: some View {
        // 波形表示の実装...
    }
}
```

## 4. 実装ステップ

### フェーズ1: 基本編集機能
1. **AudioEditorView**の作成: 波形表示と基本的な編集UIの実装
2. **WaveformView**の実装: 音声波形の表示とインタラクション
3. **AudioProcessingService**の実装: トリミング、分割、結合の基本機能
4. **VoiceMemoReducer**の拡張: 編集機能へのナビゲーション追加

### フェーズ2: エフェクト機能
1. **AudioEffectsPanel**の実装: エフェクト選択と設定UI
2. **AudioProcessingService**の拡張: ノイズリダクション、イコライザーなどの実装
3. **エフェクトプレビュー**機能: エフェクト適用前の試聴機能

### フェーズ3: 高度な機能（プレミアム）
1. **音声認識**機能: Speech Frameworkを使用したテキスト変換
2. **キーワード検索**機能: 変換されたテキスト内の検索と該当部分へのジャンプ
3. **話者分離**機能: CoreMLを使用した話者識別と分離
4. **BGM追加**機能: 背景音楽ライブラリとミキシング機能

## 5. プレミアム機能の制限

無料版では以下の制限を設ける：
- 基本編集機能（トリミング、分割）は1日に3回まで
- エフェクト機能はノイズリダクションのみ使用可能
- 高度な機能はすべてプレミアム限定
- 編集した音声に透かしを入れる

プレミアム版では：
- すべての編集機能を無制限に使用可能
- すべてのエフェクトを使用可能
- 高度な機能をすべて使用可能
- 透かしなし

## 6. テスト計画

1. **ユニットテスト**:
   - 各音声処理関数のテスト
   - 編集操作の状態管理テスト

2. **UI/UXテスト**:
   - 波形表示の正確性
   - 編集操作の使いやすさ
   - パフォーマンステスト（大きなファイルの処理）

3. **統合テスト**:
   - 編集から保存までの一連のフロー
   - プレミアム機能の制限テスト

## 7. 今後の拡張可能性

- **AIによる音声強調**: 機械学習を使用した高度なノイズ除去
- **音声分析**: 感情分析、キーワード抽出などの分析機能
- **音声変換**: ピッチ変更、声質変更などの変換機能
- **クラウド処理**: 重い処理をクラウドで実行するオプション
- **コラボレーション**: 複数ユーザーでの編集共有機能 