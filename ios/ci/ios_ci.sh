#!/bin/bash
# iOS CI (GitHub Actions self-hosted runner: .github/workflows/ios-ci.yml)
# ローカルでも同じコマンドで再現できる: ios/ci/ios_ci.sh <simulator|build|test|cleanup>
#
# 環境変数:
#   CI_SIM_NAME     使用するシミュレータ名（他リポジトリの runner と取り合わないようリポジトリ専用）
#   CI_SIM_RUNTIME  シミュレータの runtime ID
#   CI_SIM_DEVICE   シミュレータの device type ID
#   CI_OUTPUT_DIR   DerivedData / xcresult の出力先（job の作業ディレクトリ配下）
set -euo pipefail

cd "$(dirname "$0")/../.."

PROJECT=ios/VoiLog.xcodeproj
CI_SIM_NAME=${CI_SIM_NAME:-CI-VoiceMemo}
CI_SIM_RUNTIME=${CI_SIM_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-27-0}
CI_SIM_DEVICE=${CI_SIM_DEVICE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}
CI_OUTPUT_DIR=${CI_OUTPUT_DIR:-$PWD/.ci-build}
DERIVED_DATA="$CI_OUTPUT_DIR/DerivedData"

# Xcode Cloud の ci_post_clone.sh で行っていた IDESkipMacroFingerprintValidation の代わりに
# -skipMacroValidation / -skipPackagePluginValidation を渡す（TCA 等の macro を非対話で許可）
COMMON_FLAGS=(
  -project "$PROJECT"
  -configuration Debug
  -derivedDataPath "$DERIVED_DATA"
  -skipMacroValidation
  -skipPackagePluginValidation
  CODE_SIGNING_ALLOWED=NO
)

sim_udid() {
  xcrun simctl list devices -j | /usr/bin/python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
devices = json.load(sys.stdin)["devices"].get(runtime, [])
for d in devices:
    if d["name"] == name and d.get("isAvailable", True):
        print(d["udid"]); break
' "$CI_SIM_NAME" "$CI_SIM_RUNTIME"
}

case "${1:-}" in
  simulator)
    UDID=$(sim_udid)
    if [ -z "$UDID" ]; then
      echo "Creating simulator $CI_SIM_NAME ($CI_SIM_DEVICE, $CI_SIM_RUNTIME)"
      UDID=$(xcrun simctl create "$CI_SIM_NAME" "$CI_SIM_DEVICE" "$CI_SIM_RUNTIME")
    fi
    echo "Simulator: $CI_SIM_NAME $UDID"
    # 高負荷時に初回テストがランナー接続タイムアウトになるので boot 完了まで待ってから test する
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b
    ;;
  build)
    for SCHEME in VoiLogDevelop VoiLog; do
      xcodebuild build "${COMMON_FLAGS[@]}" \
        -scheme "$SCHEME" \
        -destination 'generic/platform=iOS Simulator'
    done
    ;;
  test)
    UDID=$(sim_udid)
    if [ -z "$UDID" ]; then
      echo "Simulator $CI_SIM_NAME not found. Run '$0 simulator' first." >&2
      exit 1
    fi
    rm -rf "$CI_OUTPUT_DIR/VoiLogTests.xcresult"
    # PerceptionRegistrar 起因の既知フレーク (issue #147) があるため失敗テストのみ1回リトライする。
    # 並列テストは Clone シミュレータを追加起動し、高負荷時にアプリ起動失敗 (No such process) になるので無効化
    xcodebuild test "${COMMON_FLAGS[@]}" \
      -scheme VoiLogTests \
      -destination "id=$UDID" \
      -resultBundlePath "$CI_OUTPUT_DIR/VoiLogTests.xcresult" \
      -parallel-testing-enabled NO \
      -retry-tests-on-failure \
      -test-iterations 2
    ;;
  cleanup)
    # self-hosted runner のディスク逼迫対策。job ごとの DerivedData / xcresult を消す。
    # ~/Library/Caches/org.swift.swiftpm（全リポジトリ共有の SPM キャッシュ）は消さない。
    # シミュレータは次回再利用するので削除せず shutdown のみ。
    UDID=$(sim_udid || true)
    if [ -n "$UDID" ]; then
      xcrun simctl shutdown "$UDID" 2>/dev/null || true
    fi
    rm -rf "$DERIVED_DATA" "$CI_OUTPUT_DIR"/*.xcresult
    rmdir "$CI_OUTPUT_DIR" 2>/dev/null || true
    ;;
  *)
    echo "usage: $0 <simulator|build|test|cleanup>" >&2
    exit 64
    ;;
esac
