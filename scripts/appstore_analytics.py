#!/usr/bin/env python3
"""
App Store Connect Analytics - ASO施策効果集計
Usage: python3 appstore_analytics.py

Reports used:
  - App Store Discovery and Engagement Standard → Impressions, Product Page Views
  - App Downloads Standard                      → Installs (Download Type=First Time)
  - App Sessions Standard                       → Sessions
"""

import jwt
import time
import json
import gzip
import io
import csv
import sys
import requests
from pathlib import Path
from collections import defaultdict

# ── 認証情報 ──────────────────────────────────────────────────────────────
KEY_ID        = "B2PBX57LA3"
ISSUER_ID     = "3cc1c923-009c-4963-a9db-83d030e4c4e3"
REPORT_REQ_ID = "004c346a-faa0-410c-9357-6dc3a7896d8a"
P8_PATH       = Path.home() / "Documents/secrets/AuthKey_B2PBX57LA3.p8"

# ── 集計期間 ────────────────────────────────────────────────────────────────
PERIODS = [
    ("3/8-3/12",  "2026-03-08", "2026-03-12"),
    ("3/13-3/17", "2026-03-13", "2026-03-17"),
    ("3/18-3/31", "2026-03-18", "2026-03-31"),
    ("4/1-4/12",  "2026-04-01", "2026-04-12"),
]

# ── 対象レポート定義 ────────────────────────────────────────────────────────
# (report_name, handler_key)
TARGET_REPORTS = {
    "App Store Discovery and Engagement Standard": "engagement",
    "App Downloads Standard":                      "downloads",
    "App Sessions Standard":                       "sessions",
}


def generate_token() -> str:
    private_key = P8_PATH.read_text()
    payload = {
        "iss": ISSUER_ID,
        "iat": int(time.time()),
        "exp": int(time.time()) + 1200,
        "aud": "appstoreconnect-v1",
    }
    token = jwt.encode(payload, private_key, algorithm="ES256",
                       headers={"kid": KEY_ID})
    return token if isinstance(token, str) else token.decode()


def api_get(token: str, url: str, allow_404: bool = False) -> dict | None:
    resp = requests.get(url, headers={"Authorization": f"Bearer {token}"})
    if resp.status_code == 404 and allow_404:
        return None
    if not resp.ok:
        print(f"  HTTPError {resp.status_code}: {resp.text[:300]}", file=sys.stderr)
        resp.raise_for_status()
    return resp.json()


def download_tsv(url: str) -> list[dict]:
    resp = requests.get(url)
    resp.raise_for_status()
    raw = resp.content
    try:
        data = gzip.decompress(raw).decode("utf-8")
    except Exception:
        data = raw.decode("utf-8")
    return list(csv.DictReader(io.StringIO(data), delimiter="\t"))


def date_in_period(date_str: str, start: str, end: str) -> bool:
    from datetime import datetime
    try:
        d = datetime.strptime(date_str[:10], "%Y-%m-%d").date()
        s = datetime.strptime(start, "%Y-%m-%d").date()
        e = datetime.strptime(end, "%Y-%m-%d").date()
        return s <= d <= e
    except Exception:
        return False


def get_segments(token: str, base: str, report_id: str) -> list[str]:
    """レポートのセグメントURLリストを取得 (ページネーション対応)"""
    urls = []
    inst_url = f"{base}/analyticsReports/{report_id}/instances?limit=200"
    instances = api_get(token, inst_url).get("data", [])
    for inst in instances:
        inst_id = inst["id"]
        inst_attrs = inst.get("attributes", {})
        direct_url = inst_attrs.get("url")
        if direct_url:
            urls.append(direct_url)
            continue
        seg_url = f"{base}/analyticsReportInstances/{inst_id}/segments"
        seg_resp = api_get(token, seg_url, allow_404=True)
        if seg_resp is None:
            continue
        for seg in seg_resp.get("data", []):
            u = seg.get("attributes", {}).get("url") or seg.get("links", {}).get("self")
            if u:
                urls.append(u)
    return urls


def aggregate_rows(rows: list[dict], handler: str,
                   period_stats: dict):
    """行データを期間別に集計"""
    for row in rows:
        date = row.get("Date", "")
        for label, start, end in PERIODS:
            if not date_in_period(date, start, end):
                continue

            def count(key: str) -> float:
                v = row.get(key, "0") or "0"
                try:
                    return float(v.replace(",", ""))
                except Exception:
                    return 0.0

            if handler == "engagement":
                event = row.get("Event", "")
                c = count("Counts")
                if event == "Impression":
                    period_stats[label]["impressions"] += c
                elif event == "Tap":
                    period_stats[label]["taps"] += c
                elif event == "Page view":
                    period_stats[label]["page_views"] += c

            elif handler == "downloads":
                dl_type = row.get("Download Type", "")
                if dl_type == "First-time download":
                    period_stats[label]["installs"] += count("Counts")

            elif handler == "sessions":
                period_stats[label]["sessions"] += count("Sessions")


def main():
    print("=== App Store Connect Analytics ===\n")
    token = generate_token()
    base = "https://api.appstoreconnect.apple.com/v1"

    # 1. レポート一覧取得
    print("1. レポート取得中...")
    reports_url = f"{base}/analyticsReportRequests/{REPORT_REQ_ID}/reports?limit=100"
    reports = api_get(token, reports_url).get("data", [])
    print(f"   レポート数: {len(reports)}")

    # 対象レポートのIDをマッピング
    target_map = {}  # handler_key → report_id
    for r in reports:
        name = r.get("attributes", {}).get("name", "")
        if name in TARGET_REPORTS:
            target_map[TARGET_REPORTS[name]] = r["id"]

    print(f"   対象レポート: {list(target_map.keys())}")
    if not target_map:
        print("対象レポートが見つかりませんでした")
        return

    # 2. セグメントURLを収集
    print("2. セグメントURL収集中...")
    handler_segments: dict[str, list[str]] = {}
    for handler, report_id in target_map.items():
        segs = get_segments(token, base, report_id)
        handler_segments[handler] = segs
        print(f"   {handler}: {len(segs)} セグメント")

    # 3. 集計
    print("3. データ集計中...")
    period_stats = {label: defaultdict(float) for label, *_ in PERIODS}
    total_rows = 0

    for handler, seg_urls in handler_segments.items():
        print(f"   [{handler}] {len(seg_urls)} ファイル処理中...")
        for i, url in enumerate(seg_urls, 1):
            try:
                rows = download_tsv(url)
                aggregate_rows(rows, handler, period_stats)
                total_rows += len(rows)
            except Exception as e:
                print(f"   スキップ [{i}]: {e}")

    print(f"\n   合計行数: {total_rows:,}\n")

    # 4. 結果表示
    print("=" * 85)
    print(f"{'期間':<12} {'インプレッション':>14} {'Tap':>8} {'CTR':>6} {'ページ閲覧':>10} {'インストール':>12} {'セッション':>10}")
    print("-" * 85)
    result = {}
    for label, start, end in PERIODS:
        s = period_stats[label]
        imp   = int(s["impressions"])
        taps  = int(s["taps"])
        pv    = int(s["page_views"])
        inst  = int(s["installs"])
        sess  = int(s["sessions"])
        # CTR = Tap / Impression (App Store標準定義)
        ctr   = round(taps / imp * 100, 2) if imp > 0 else 0.0
        # CVR = Install / Page view
        cvr   = round(inst / pv  * 100, 2) if pv  > 0 else 0.0
        print(f"{label:<12} {imp:>14,} {taps:>8,} {ctr:>5.1f}% {pv:>10,} {inst:>12,} {sess:>10,}")
        result[label] = {
            "impressions": imp,
            "taps": taps,
            "ctr_pct": ctr,
            "page_views": pv,
            "cvr_pct": cvr,
            "installs": inst,
            "sessions": sess,
        }
    print("=" * 85)

    # 5. JSON保存
    out_path = Path(__file__).parent / "analytics_result.json"
    out_path.write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print(f"\nJSON保存: {out_path}")


if __name__ == "__main__":
    main()
