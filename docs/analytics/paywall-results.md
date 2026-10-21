# Paywall result verification (#234)

## Event contract

Existing purchase event names remain unchanged. Purchase attempts and outcomes retain the same captured `product_name` (`annual` / `pro`), price, trial flag and opening `source`. Empty sources become `unknown`.

- `paywall_products_loaded`: loading cycle finished; inspect `monthly_available` and `annual_available` rather than assuming success. This existing event also fires when both products fail.
- `paywall_products_failed`: one plan failed to load. Parameters: `source`, `product_name`, `error_code`. A partial failure may coexist with one available plan.
- `paywall_purchase_failed`: `error_code` replaces localized error text.
- `paywall_restore_attempted`, `paywall_restore_completed`, `paywall_restore_failed`: now include `source` and `product_name=unknown`. Restoring entitlements does not imply purchasing the plan currently selected on screen.
- Restore failures with `error_code=no_entitlements` are purchase-history outcomes, not network failures.

Error codes: `cancelled`, `product_not_found`, `purchase_failed` (including inactive entitlement after purchase), `no_entitlements`, `network_error`, `revenuecat_<numeric code>`, `unknown`. SDK error descriptions are not sent to Analytics. Cancellation continues to use its separate existing event, without the failure alert.

## Repeatable reporting

Property: `336479548`. Use a fixed inclusive date range in JST and `platform=iOS`. Filter `appVersion` to the version containing this change, not all historical versions. Record the deployed version and first available day before comparing periods.

1. Query Data API `properties/336479548/metadata` for registered dimensions. Do not assume `customEvent:source` or `customEvent:error_code` exists.
2. If available, use `runReport` with `eventName`, `appVersion`, `customEvent:source`, `customEvent:error_code` and metrics `eventCount`, `totalUsers`. Restrict error-code breakdown to failure events; success events need not carry this parameter.
3. If custom dimensions are absent, register the needed event-scoped definitions through the GA4 administration workflow, record the registration date, and wait for processed data. Historical backfill must not be assumed. DebugView can verify delivery immediately but does not prove aggregate reporting availability.
4. The v1alpha `runFunnelReport` can filter some raw event parameters even without custom definitions. On 2026-10-21, `source` filters returned small nonzero cohorts; this does not prove complete source coverage. Unsupported parameters must be reported as unavailable, not zero.
5. Build the closed funnel `paywall_viewed → paywall_purchase_attempted → paywall_purchase_completed`, allowing intervening events. Break down by appVersion. To evaluate a specific source, constrain all three steps to that source. Users can appear in multiple source cohorts; do not sum them as unique users.
6. Count restore `no_entitlements` separately from `network_error` and other SDK failures. Keep unknown source/error counts visible. Do not add daily user counts to estimate period unique users.
7. Reconcile actual new paying customers in RevenueCat with GA4 events using matching dates, production environment, platform and product types. Trial starts, restoration and purchase events are not automatically new paid customers.

Baseline (iOS, 2026-09-20 through 2026-10-19): 171 → 7 → 3. This baseline predates the new code. Evaluate at around 100 new-version paywall viewers; 8% attempt rate is a working target, not a significance threshold.

## Device / Sandbox checklist (still pending)

Use a dedicated test account; record build, device, source and timestamp. Keep test purchases out of business metrics. Never paste customer IDs or receipts into the issue.

- Products loading: purchase disabled. Failed load: failure event, retry available; restored connectivity permits a new load and purchase.
- Monthly and annual purchase: attempt and completion have matching plan/source; cancellation has its own event and no error alert.
- Network failure: purchase failure retains the network classification.
- Restore with an active entitlement: completion event with source; restore with no entitlement: failure with `no_entitlements`; network failure: `network_error` where reported by the SDK.
- Confirm the events in DebugView, then confirm processed reporting with metadata and a new-version query. Unit-test success alone does not complete this checklist.

No pricing, release submission, GA4 configuration or advertising changes are performed by this implementation.

## Local validation — 2026-10-21

Xcode 27 / CI-VoiceMemo simulator: `PurchaseManagerTests` 18/18 and `MonthlyPaywallPolicyTests` 14/14 passed with parallel testing disabled. The initial combined parallel run was interrupted after slow progress; the sequential related suite completed in 58.45 seconds. Test commands build the app and test targets. Changed-file SwiftLint exited 0 with existing configuration/style warnings; `git diff --check` passed. Physical devices were unavailable; Sandbox/DebugView verification remains pending.
