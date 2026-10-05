#if DEBUG
import Foundation
import UIKit

/// 終日録音の実現性検証用（spike/allday-recording ブランチ限定、main には入れない）。
///
/// 録音中に 60 秒ごとにバッテリー残量・充電状態・発熱状態・録音ファイルのサイズを
/// Documents/allday_probe.csv に追記する。1 時間録音したあと CSV を回収すれば
/// %/h と MB/h がそのまま読める。
///
/// 回収: `xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer
///        --domain-identifier <bundle id> --user mobile --source Documents/allday_probe.csv --destination .`
actor AllDayRecordingProbe {
    static let shared = AllDayRecordingProbe()

    private var task: Task<Void, Never>?

    private var csvURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("allday_probe.csv")
    }

    func start(recordingURL: URL, interval: TimeInterval = 60) {
        task?.cancel()
        let csvURL = csvURL
        task = Task {
            await MainActor.run { UIDevice.current.isBatteryMonitoringEnabled = true }
            if !FileManager.default.fileExists(atPath: csvURL.path) {
                FileManager.default.createFile(
                    atPath: csvURL.path,
                    contents: Data("timestamp,file,elapsed_s,battery,battery_state,thermal,low_power,app_state,file_bytes\n".utf8)
                )
            }
            let startedAt = Date()
            while !Task.isCancelled {
                await Self.appendRow(csvURL: csvURL, recordingURL: recordingURL, elapsed: Date().timeIntervalSince(startedAt))
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private static func appendRow(csvURL: URL, recordingURL: URL, elapsed: TimeInterval) async {
        let (battery, batteryState, appState) = await MainActor.run {
            (UIDevice.current.batteryLevel, UIDevice.current.batteryState.rawValue, UIApplication.shared.applicationState.rawValue)
        }
        let info = ProcessInfo.processInfo
        let size = (try? FileManager.default.attributesOfItem(atPath: recordingURL.path)[.size] as? Int64) ?? -1
        let row = [
            ISO8601DateFormatter().string(from: Date()),
            recordingURL.lastPathComponent,
            String(Int(elapsed)),
            String(format: "%.2f", battery),
            String(batteryState),
            String(info.thermalState.rawValue),
            info.isLowPowerModeEnabled ? "1" : "0",
            String(appState),
            String(size)
        ].joined(separator: ",") + "\n"
        guard let handle = try? FileHandle(forWritingTo: csvURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(row.utf8))
    }
}
#endif
