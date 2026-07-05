# 随心记 (SuixinJi) — SwiftUI iOS App

A minimal **local** diary app: type, dictate, record voice memos, and attach
photos. Implemented from the Claude Design handoff (`project/随心记-UI.dc.html`)
per **`随心记-PRD.md`** and **`随心记-UI设计Brief.md`**.

This is the **P0 MVP** — everything the PRD marks P0 is functional:

| PRD | Feature | Where |
|-----|---------|-------|
| F1 | Text diary — create / edit / delete | `EditorView`, `DetailView` |
| F2 | Voice-to-text (live, on-device) | `SpeechTranscriber` |
| F3 | Voice memo — record ≤10 min, playback | `AudioRecorder`, `AudioPlaybackManager` |
| F4 | Photos — album + camera, ≤9, compressed | `EditorView`, `CameraPicker`, `FileStore` |
| F5 | Timeline home, grouped by year-month, empty state | `HomeView`, `DiaryCardView` |
| F6 | Detail / edit / delete with confirmation | `DetailView` |

### Beyond the PRD (evolution)

| Feature | Where |
|---------|-------|
| 数据洞察 · 统计 (streaks, monthly activity, mood distribution, media counts) | `DiaryStatistics` (pure engine) + `StatisticsView`, opened from the home 统计 button |
| 回顾 · 记忆 (这一天 / 去年今天, streak milestones, monthly recap → shareable long image) | `Memories` + `MonthlyRecap` engines; home "这一天" banner → `MemoriesListView`; milestone + recap sections in `StatisticsView`; `RecapCard` + `DiaryExporter.exportRecap` |
| 全量备份 · 导出/导入 (single self-contained `.json` incl. media as base64; merge-by-id restore) | `DiaryBackup` format + `BackupService`; Settings 数据备份 section (share sheet export + `.fileImporter` import) |
| 主题皮肤 (5 accent colors + 4 font-size scales, live + persisted) | `ThemeManager` + `.themedRoot()`; accent via `.tint`/`Color.accentColor`, font size via `\.themeScale` + `.scaledFont`; Settings 外观 section. Shared exports keep the signature orange (ImageRenderer content renders at base scale + the AccentColor asset). |
| 桌面小组件 + App Intents 快捷记录 | `SuixinJiWidgetExtension` target (WidgetKit): a small/medium widget showing streak + today + a compose button (`QuickAddIntent`, also a Siri/Shortcuts action). App writes a `WidgetSnapshot` to the App Group; widget reads it. See below. |

### Widget target + App Group (requires provisioning)

The widget is a second target (`SuixinJiWidgetExtension`) embedded in the app. It
reads a tiny `WidgetSnapshot` the app writes to a shared **App Group container**
(`group.com.suixinji.app`). `Shared/` (snapshot, `SharedStore`, `QuickAddIntent`)
is compiled into **both** targets.

- **Simulator builds/tests are unaffected** — App Group entitlements aren't
  enforced there, so `xcodebuild test` on a simulator runs the whole suite as before.
- **On device**, both targets carry `com.apple.security.application-groups`
  (`SuixinJi/SuixinJiApp.entitlements`, `SuixinJiWidget/SuixinJiWidget.entitlements`).
  Xcode's automatic signing provisions the App Group; if your account can't, either
  register the group in *Signing & Capabilities → App Groups* on both targets, or
  remove the `SuixinJiWidgetExtension` target + the app's `CODE_SIGN_ENTITLEMENTS`
  to revert to the app-only build.

The widget's compose button and the `QuickAddIntent` open the app (`openAppWhenRun`).

### P1 / P2 features (added on top of the MVP)

| PRD | Feature | Where |
|-----|---------|-------|
| F7  | 心情打卡 (mood emoji) | `EditorMetadata`, shown on card/detail |
| F8  | 关键词搜索 | `DiarySearch`, `.searchable` in `HomeView` |
| F9  | 日历视图 | `CalendarView` (month grid + day entries) |
| F10 | 每日提醒 (real local notification) | `ReminderManager`, wired in `SettingsView` |
| F11 | iCloud 同步 | SwiftData+CloudKit, **gated** — see below |
| F12 | Face ID / 密码锁 | `AppLockManager`, lock overlay in `SuixinJiApp` |
| F13 | 导出 PDF / 长图 | `DiaryExporter`: paginated A4 PDF **and** tall PNG, via share sheet |
| F14 | 标签 / 天气 / 位置 | `EditorMetadata`, `LocationProvider` (CoreLocation), `WeatherProvider` (WeatherKit) |

**Weather** uses real **WeatherKit** when available (tap 天气 → 自动获取), and
always keeps a **manual emoji picker** as fallback. **Location** uses CoreLocation
+ reverse geocoding to a place name. **Export** produces a multi-page A4 PDF (the
tall render is sliced into pages) or a single long PNG for sharing to chat.

### Enabling real weather (F14 · WeatherKit)

`import WeatherKit` compiles with no flag; the fetch just **fails gracefully to
the manual picker** until the capability is provisioned. To get live weather:

1. Target → *Signing & Capabilities* → **+ Capability → WeatherKit**.
2. Enable **WeatherKit** for the App ID on the Apple Developer portal
   (requires a **paid** account); allow ~30 min for it to propagate.

No `Info.plist` key is needed for WeatherKit itself; it reuses the location
permission already declared for F14.

### iCloud sync (F11) — on by default, graceful fallback

SwiftData + CloudKit sync is **on by default** (`Persistence.container`). It's
safe: if the CloudKit container can't be created (no entitlement / free account
/ not provisioned), the app **falls back to a local store at runtime** instead
of crashing — only cross-device sync is off. Simulator builds/tests are
unaffected. Settings → *iCloud 同步* shows the live account status.

To actually sync across devices (needs a **paid** developer account):

1. Target *SuixinJi* → *Signing & Capabilities* → **+ Capability → iCloud** →
   check **CloudKit**, container `iCloud.com.suixinji.app`. The entitlements are
   already declared in `SuixinJi/SuixinJiApp.entitlements` (alongside the App
   Group); Xcode's automatic signing provisions them.
2. First run creates the CloudKit schema in the **Development** environment;
   deploy it to **Production** (CloudKit Dashboard) before shipping to TestFlight.

The `DiaryEntry` schema is CloudKit-compatible (all attributes optional or
defaulted, no unique constraints, no required relationships).

**Scope:** CloudKit syncs the diary *records* (text + all metadata + file names)
**and the media** (photos + voice memos). Media rides a sidecar `MediaBlob`
`@Model` whose bytes are `@Attribute(.externalStorage)` — under CloudKit that
syncs as a **CKAsset**. The app's UI is unchanged — it still reads media by file
name from `FileStore` (PRD §5.3); the blobs are just the transport.

`MediaSyncService` is designed to survive CloudKit's **unordered, per-record**
sync (the entry record and its blob record delete independently):

- **Uploads are never inferred by `reconcile`.** They happen only on authoritative
  local actions — `DiaryService.save` uploads new media / drops removed media — plus
  a **one-time migration** that seeds the cloud with media that predates this
  feature (guarded by a `UserDefaults` flag so it can't re-fire). This is what
  prevents a *resurrection* bug: if reconcile re-uploaded "any referenced file
  without a blob," a second device that received the blob-deletion before the
  entry-deletion would push the just-deleted photo back to every device.
- **`reconcile` only downloads and cleans up.** It materializes arrived blobs into
  the sandbox, and reclaims **orphan** local files — a file referenced by *no
  entry AND no blob* can only mean both were deleted and have settled, so it's safe
  to delete (during an in-flight delete the file is still entry- or blob-backed and
  is kept). Runs on launch and on app-active.

The invariant that makes blob cleanup precise: media file names are **per-entry
UUIDs** (`FileStore.saveImage`/`adoptAudio`), so a blob backs exactly one entry.
Local storage carries both the sandbox file and the blob copy (~2× for media) — an
acceptable trade for a personal-diary media set. Known minor edge: if two devices
run the one-time migration in the same sync window they can briefly create
duplicate blobs for a name (no unique constraint is allowed under CloudKit);
they're byte-identical and converge on delete.

## Requirements

- **Xcode 16** or newer (the project uses file-system–synchronized groups,
  `objectVersion = 77`).
- **iOS 17+** deployment target (SwiftData requirement).
- No third-party dependencies — everything is system frameworks
  (SwiftUI, SwiftData, AVFoundation, Speech, PhotosUI).

## Open & run

```bash
open SuixinJi.xcodeproj
```

Then pick an iPhone simulator (or a real device) and press ⌘R.

Or from the command line:

```bash
xcodebuild -project SuixinJi.xcodeproj -scheme SuixinJi \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

> **Use a real device for voice & camera.** The simulator has no camera and
> only partial speech/mic support — the PRD calls this out (§8). Recording,
> voice-to-text, and 拍照 are best verified on hardware.

## Tests

Unit + performance + UI tests ship with the project (targets `SuixinJiTests`
and `SuixinJiUITests`). Run all with **⌘U**, or:

```bash
xcodebuild test -project SuixinJi.xcodeproj -scheme SuixinJi \
  -destination 'platform=iOS Simulator,name=iPhone 17' -enableCodeCoverage YES
```

Code coverage is enabled in the shared scheme. See **`TESTING.md`** for the
full test plan, the coverage philosophy, and how to read the coverage report.

## Permissions

Usage strings are set as `INFOPLIST_KEY_*` build settings (so the generated
`Info.plist` carries them — see `project.pbxproj`):

- `NSMicrophoneUsageDescription` — recording + voice-to-text
- `NSSpeechRecognitionUsageDescription` — voice-to-text
- `NSCameraUsageDescription` — 拍照
- `NSLocationWhenInUseUsageDescription` — 位置 (F14)
- `NSFaceIDUsageDescription` — 应用锁 (F12)

Daily reminders (F10) request notification permission at runtime (no plist key).

Album selection uses `PhotosPicker`, which needs **no** permission prompt.
If the user has denied mic/speech, tapping 录音 / 转文字 shows the
"需要麦克风权限 · 去设置" alert that jumps to system Settings (design 2e).

## Architecture (kept deliberately small — PRD §7)

```
SuixinJi/
├── SuixinJiApp.swift          @main + ModelContainer
├── Models/DiaryEntry.swift    the one @Model (PRD §5.2)
├── Services/
│   ├── FileStore.swift        sandbox images/ + audios/ (PRD §5.3)
│   ├── AudioRecorder.swift     AVAudioRecorder, 10-min cap, interruption auto-save
│   ├── AudioPlaybackManager.swift  AVAudioPlayer + progress
│   └── SpeechTranscriber.swift on-device SFSpeechRecognizer
├── DesignSystem/Theme.swift   colors / spacing / type ramp / date formatting
└── Views/
    ├── HomeView.swift          timeline + empty state + floating ➕
    ├── DiaryCardView.swift     one card
    ├── EditorView.swift        write/edit sheet (all states)
    ├── DetailView.swift        detail + playback + delete
    ├── SettingsView.swift      grouped list + mandatory data footer
    ├── PhotoPagerView.swift    full-image horizontal pager
    └── Components/
        ├── WaveformView.swift  the signature waveform (Brief §7)
        ├── RecordingBar.swift  saved-recording bar + recording-in-progress capsule
        └── CameraPicker.swift  UIKit camera bridge
```

**Data rule enforced (PRD §5):** the database stores only file *names*; the
real images/audio live in `Documents/images` and `Documents/audios`. Deleting
an entry removes its files first, then the record (`FileStore.deleteFiles` +
`DetailView.deleteEntry`), so no orphan files are left behind.

## Known deviations from the Brief (deliberate)

One spot intentionally diverges from the original P0 Brief because a later
request superseded it:

1. **Export/share on the detail page.** Brief §7 / PRD §3.3 keep social-share out
   of v1, but export (`导出 PDF` / `导出长图`) was an explicit later request, so the
   share sheet stays. It's the F13 (P2) feature, opt-in from the "···" menu.

(The earlier "dictation inserts at the end" gap is now fixed — F2 inserts at the
caret via the `DiaryTextEditor` UITextView bridge, `Views/Components`.)

## Design fidelity

Colors map to iOS semantic colors so dark mode is free (Brief §3.3); the warm
accent `#FF8A5C` is used only as an accent (FAB, save, waveform, recording),
never as a large fill (Brief §7). The type ramp (34/22/17/15/13/11), 16pt
margins, 16pt card radius, 12pt gaps, 56pt FAB, and the waveform "signature
element" all follow the Brief. The app icon is direction **3a** (声波＋心跳),
composited from the three Icon Composer layers in `project/icon-composer/`.

## Design deliverables not part of the app binary

The handoff also includes icon-production assets (design work, not app code):
`project/icon-composer/` — the three 1024pt SVG layers for iOS 27 Icon Composer
(Liquid Glass). The shipping `AppIcon` here is a flat 1024 PNG composited from
those layers; re-layer them in Icon Composer for the Liquid Glass version.
