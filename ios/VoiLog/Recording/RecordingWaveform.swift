import Foundation

/// 録音中に表示するスクロール波形のデータ（iOS 標準「ボイスメモ」風）。
///
/// レコーダーのメーター値（dBFS）を 1 サンプル = 1 本のバーとして蓄積する。
/// 表示側は末尾（最新）を再生ヘッド位置に置き、古いサンプルほど左へ流す。
///
/// 変換の考え方:
/// 1. **ノイズゲート**: `noiseFloor`(-50dB) 以下は無音として 0 にする。室内の環境音でバーが立ち続けないようにする。
/// 2. **正規化＋カーブ**: `noiseFloor`〜`ceiling`(-12dB) を 0〜1 に線形変換してから `curveExponent` 乗する。
///    AVAudioRecorder の averagePower は話し声でもおおむね -30〜-20dB に収まる（シミュレータ実測の中央値 -27.5dB）。
///    0dB を上限にすると話し声がバーの半分にも届かないので、上限を -12dB に下げて話し声の幅を高さいっぱいに使う。
///    さらに累乗で「環境音は低く、話し声ははっきり高く」コントラストを付ける。
/// 3. **アタック即時・リリース緩やか**: 立ち上がりはそのまま反映し、下がるときは前のバーから
///    `releaseFactor` の割合だけ戻す。声の途切れでバーがガタつかず、音量計らしい動きになる。
struct RecordingWaveform: Equatable {
    /// 保持するサンプル数の上限。100ms 間隔で約 2 分ぶん。画面幅より十分大きければよい。
    static let capacity = 1200
    static let noiseFloor: Float = -50
    /// この値以上はバーの最大の高さにする
    static let ceiling: Float = -12
    static let curveExponent: Float = 1.5
    static let releaseFactor: Float = 0.65

    /// 0...1 に正規化済みのバーの高さ。末尾が最新。
    private(set) var samples: [Float] = []

    /// メーター値（dBFS）を 1 本ぶん追加する。
    mutating func append(decibels: Float) {
        let target = Self.normalizedLevel(decibels: decibels)
        let previous = samples.last ?? 0
        let level = target >= previous ? target : previous + (target - previous) * Self.releaseFactor
        samples.append(level)
        if samples.count > Self.capacity {
            samples.removeFirst(samples.count - Self.capacity)
        }
    }

    mutating func reset() {
        samples.removeAll()
    }

    /// dBFS を 0...1 のバーの高さに変換する（ノイズゲート＋累乗カーブ）。
    static func normalizedLevel(decibels: Float) -> Float {
        guard decibels.isFinite, decibels > noiseFloor else { return 0 }
        let linear = min(1, (decibels - noiseFloor) / (ceiling - noiseFloor))
        return pow(linear, curveExponent)
    }
}
