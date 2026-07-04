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

### Enabling iCloud sync (F11) — opt-in

Off by default so a **free** Apple ID build keeps working. To turn it on (needs a
**paid** developer account):

1. Target → *Signing & Capabilities* → **+ Capability → iCloud** → check
   **CloudKit**; container `iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)`. (A ready
   entitlements file is at `SuixinJi/SuixinJi.entitlements` — point
   `CODE_SIGN_ENTITLEMENTS` at it or let Xcode generate one.)
2. *Build Settings → Active Compilation Conditions* → add **`CLOUDKIT_ENABLED`**
   (Debug + Release). `SuixinJiApp` then builds the container with
   `ModelConfiguration(cloudKitDatabase: .automatic)`.

The `DiaryEntry` schema is already CloudKit-compatible (all properties optional
or defaulted, no unique constraints, no required relationships).

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
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

> **Use a real device for voice & camera.** The simulator has no camera and
> only partial speech/mic support — the PRD calls this out (§8). Recording,
> voice-to-text, and 拍照 are best verified on hardware.

## Tests

Unit + performance + UI tests ship with the project (targets `SuixinJiTests`
and `SuixinJiUITests`). Run all with **⌘U**, or:

```bash
xcodebuild test -project SuixinJi.xcodeproj -scheme SuixinJi \
  -destination 'platform=iOS Simulator,name=iPhone 16' -enableCodeCoverage YES
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
