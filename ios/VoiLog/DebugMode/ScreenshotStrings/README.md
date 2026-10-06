# Screenshot strings (App Store mock screens)

The App Store screenshots are SwiftUI mock screens rendered by
`ios/VoiLogTests/ScreenshotRenderTests.swift`. Every visible text on them comes from
the JSON files in this folder — **translators only need to edit JSON**.

- One file per language: `<code>.json`, where `<code>` is the iOS localization code
  (`en`, `ja`, `de`, `es`, `fr`, `it`, `pt-PT`, `ru`, `tr`, `vi`, `zh-Hans`, `zh-Hant`,
  and later `ko`, `ar`, `id`, `hi`, `nl`, `pl`, `sv`, `th`, `pt-BR`, `bn`, `ca`, `cs`, `da`,
  `el`, `fi`, `gu`, `he`, `hr`, `hu`, `kn`, `ml`, `mr`, `ms`, `nb`, `or`, `pa`, `ro`, `sk`,
  `sl`, `ta`, `te`, `uk`, `ur`).
- **Adding a language = adding a file.** Copy `en.json`, rename it, translate the values.
  The renderer, the DebugMode preview (Settings → screenshot preview) and the render test
  pick it up automatically. A file must contain `display_name` to be recognised.
- A key missing from a language falls back to `en.json` (logged as
  `[ScreenshotStrings] missing key ...` in DEBUG), so a partial file still renders.
- Arrays must keep the same number of items as in `en.json` (the test checks this).
- `%d` is replaced by a number and `%@` by text. Keep them in the translation; you may move them.
- Headlines (`hero_line*`, `promo_*_line*`) are drawn on ONE line each and shrink to fit,
  so keep them short (Latin ~20 characters, CJK ~10). Chips go on one row, or two rows if
  they do not fit.
- The folder is bundled as a folder (`explicitFolders` in `project.pbxproj`), so the app
  reads `ScreenshotStrings/<code>.json` from the app bundle.

Render & export:

```bash
xcodebuild test -project ios/VoiLog.xcodeproj -scheme VoiLogTests \
  -destination 'platform=iOS Simulator,id=<UDID>' -only-testing:VoiLogTests/ScreenshotRenderTests
# → /tmp/voilog_screenshots/<code>/<n>_APP_IPHONE_67_<n>.png (0–7) / <n>_APP_IPAD_PRO_3GEN_129_<n>.png (0–6)
ios/ci/export_screenshots.sh --dry-run   # then without --dry-run to copy into fastlane/screenshots/
```

The approved hero images `fastlane/screenshots/ja/0_APP_IPHONE_67_0.png` and
`fastlane/screenshots/en-US/0_APP_IPHONE_67_0.png` (real simulator captures composed by
`fastlane/hero_screenshot/compose.py`) are never overwritten by the export script;
en-GB / en-CA / en-AU get a copy of the approved en-US hero.

## Slots

| iPhone file | Screen | iPad file | Screen |
|---|---|---|---|
| 0 | Hero (`hero_*`, `tab_*`) | 0 | aiRecording |
| 1 | playbackList | 1 | playbackList |
| 2 | useCase | 2 | useCase |
| 3 | waveformEditor | 3 | waveformEditor |
| 4 | backgroundRecording | 4 | backgroundRecording |
| 5 | playlist | 5 | playlist |
| 6 | timestampedTranscription | 6 | timestampedTranscription |
| 7 | aiTranscription | | |

`shareSheet` and `premium` are only shown in the DebugMode preview (not shipped right now),
but their strings are still translatable.

## Key reference (schema)

### Layout flags (not text)

| Key | Type | Meaning |
|---|---|---|
| `display_name` | string | Short label in the DebugMode language picker (e.g. `DE`, `简`). Required. |
| `layout_rtl` | bool | `true` for right-to-left scripts (`ar`, `he`, `ur`): the page is laid out right-to-left and uses this language's `Locale`. |

### Page headline / chips (every page except the hero)

Every page uses the approved hero design (`PromoScreenshotPageView.swift`): purple pill (`hero_pill`),
a two-line headline and three white chips above a black device frame, with the key part of
the screen zoomed into a purple-bordered card.

| Key | Shown as |
|---|---|
| `promo_<screen>_line1` | Headline line 1, dark ink. |
| `promo_<screen>_line2` | Headline line 2, purple accent (line 1 + line 2 read as one sentence). |
| `promo_<screen>_chips` [3] | 3 white chips under the headline (short feature labels). |

`<screen>` is one of `aiRecording`, `useCase`, `playbackList`, `backgroundRecording`,
`timestampedTranscription`, `waveformEditor`, `playlist`, `shareSheet`, `premium`, `aiTranscription`
(what each screen shows: see the table above / the mock screen keys below).
The test `testEveryLanguageHasPromoTextsForShippedPages` fails if a shipped page lacks them.

### Hero (iPhone slot 0)

| Key | Shown as |
|---|---|
| `hero_pill` | Purple pill at the top (app name). ja: シンプル録音 / en: Simple Voice Recorder |
| `hero_line1` | Headline line 1, dark ink. Keep it short; it shrinks to one line. |
| `hero_line2` | Headline line 2, purple accent. |
| `hero_chips` | 3 white chips under the headline: one-tap recording / quality presets / AI transcription. |
| `hero_screen_title` | Large navigation title of the recording screen inside the phone (app's `録音` in Recording table). |
| `hero_recording_status` | Red status above the timer while recording (app's `録音中`). |
| `tab_recording`, `tab_playback`, `tab_playlist`, `tab_settings` | Tab bar labels of the app (app's `録音` / `再生` / `プレイリスト` / `設定`). |

### Mock screen texts

| Key | Shown as |
|---|---|
| `app_title` | App name. Language picker + lock-screen Live Activity (backgroundRecording). |
| `recording_title` | Large title of the recording screen (iPad slot 0). |
| `recording_status` | "Recording" status text (iPad slot 0, lock-screen Live Activity). |
| `recording_files` | Large title of the recordings list (playbackList, useCase). |
| `lock_screen_date` | Date above the big clock on the lock screen (backgroundRecording). |
| `sample_recording_titles` [5] | Recording names in the list (playbackList, share sheet). |
| `sample_date` | Row date/time; `%d` = minutes (10–14). e.g. `17.08.2024 11:%d`. |
| `use_case_sample_titles` [5] | Recording names in the use-case list and transcription mini player: meeting notes, economics lecture vol.3, interview with a person (use a local surname), idea memo, English speaking practice. |
| `use_case_tags` [5] | Small colored tag under each use-case row: meeting, lecture, interview, idea, practice. |
| `playlist` | Large title of the playlist screen. |
| `playlist_names` [3] | Playlist names: work meetings, study notes, ideas. |
| `recording_count` | Under a playlist name; `%d` = number of recordings. |
| `created_date` | Under a playlist name; `%d` = day (15–17). e.g. `Created: 2024/08/%d`. |
| `audio_edit` | Title of the waveform editor. |
| `split` | Label under the scissors button in the waveform editor ("Split"). |
| `cancel` | Red left button in the waveform editor; share sheet cancel. |
| `save` | Right button in the waveform editor; purple button on the AI transcription screen. |
| `audio_recording` | File type under the file name in the share sheet ("Audio Recording • 2.1 MB"). |
| `share_message`, `share_mail`, `share_link`, `share_more` | Share sheet app icons: Messages, Mail, Link, More. |
| `copy`, `save_to_files`, `delete` | Share sheet action rows. `delete` is red. |
| `transcription_title` | Title of the transcription screens. |
| `transcription_sample_texts` [4] | Four transcript lines (meeting: review last week's progress / sales up 15% / next project budget / Q4 planning with marketing). |
| `ai_tab_apple`, `ai_tab_ai` | Segmented tabs on the AI transcription screen (Apple on-device vs AI). Usually untranslated. |
| `ai_summary_label` | Purple "Summary" label. |
| `ai_summary_text` | One-sentence meeting summary under it. |
| `ai_segments` [4] | Speaker-labelled transcript lines (A: let's start the meeting / B: progress on schedule / A: next steps / B: release next month). |
| `premium_badge` | Gold badge text on the premium screen (`PREMIUM`). |
| `premium_headline` | Big headline on the premium screen. |
| `premium_no_ads`, `premium_offline`, `premium_unlimited`, `premium_icloud` | The 4 premium feature cards. |
| `premium_cta` | White call-to-action button ("Start Free Trial"). |

## Keys needing translation per language

These values were copied mechanically from the old Swift code, which used fallbacks, so the
existing screenshots render exactly as before. Translators should replace them.

| Language | Keys |
|---|---|
| all except `ja` (incl. `en`) | `split`, `share_message`, `share_mail`, `share_link`, `share_more`, `delete` — still the Japanese literals (分割 / メッセージ / メール / リンク / その他 / 削除) that were hardcoded in the mock views. App translations of 分割 exist in `AudioEditor.xcstrings` (en Split, de Teilen, es Dividir, fr Diviser, it Dividere, pt-PT Dividir, ru Разделить, tr Böl, vi Tách, zh 分割). |
| `es`, `fr`, `it`, `pt-PT`, `ru`, `tr`, `vi`, `zh-Hans`, `zh-Hant` | `transcription_sample_texts`, `ai_segments` — generic English fallback text. |
| `de`, `es`, `fr`, `it`, `pt-PT`, `ru`, `tr`, `vi`, `zh-Hans`, `zh-Hant` | `hero_pill`, `hero_line1`, `hero_line2`, `hero_chips` — drafted (not from compose.py); need native review. `hero_pill` is the store app name for now. |
