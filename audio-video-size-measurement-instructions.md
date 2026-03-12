# Audio/Video Dependency Size Measurements

## Context

We're measuring the binary size impact of adding audio/video playback
dependencies to `genui`. The goal is to populate the size impact table in
`audio-video-media-catalog-item-notes.md` with data from Android, iOS, Linux,
and Windows (macOS is already measured).

We test three configurations against a baseline to compare lightweight
OS-native libraries vs. heavier bundled-engine libraries:

1. **Baseline** — no audio/video dependencies
2. **audioplayers + video_player** — lightweight, uses OS-native APIs
3. **fvp + video_player** — bundles libmdk for all-platform video support

## Important: removing deps from genui first

The `genui` package itself depends on `audioplayers`, `video_player`, and
`video_player_win`. This means `examples/catalog_gallery/` already includes
those deps transitively via `genui`. Adding them again to catalog_gallery's
pubspec is a no-op — it won't change the build output.

To get a true baseline, you must **temporarily** modify `packages/genui/`:

1. Remove `audioplayers`, `video_player`, and `video_player_win` from
   `packages/genui/pubspec.yaml`.
2. Stub out the two files that import them so the project still compiles:
   - `packages/genui/lib/src/catalog/basic_catalog_widgets/audio_player.dart`
   - `packages/genui/lib/src/catalog/basic_catalog_widgets/video.dart`

   Replace each with a minimal stub that exports a placeholder `CatalogItem`
   (no plugin imports).
3. Build the baseline and record measurements.
4. Restore the original genui pubspec and source files for subsequent builds.

## Setup

All commands run from `examples/catalog_gallery/`.

Between each build, run `flutter clean`, swap dependency sets in
`packages/genui/pubspec.yaml`, and run `flutter pub get`. Restore the
original pubspec and source files when done.

### Dependency sets (pinned versions used for measurements)

**Baseline** — genui pubspec with `audioplayers`, `video_player`, and
`video_player_win` removed, and audio_player.dart / video.dart stubbed out.

**audioplayers + video_player** — restore the original genui pubspec
(includes the deps below):

```yaml
audioplayers: ^6.6.0
video_player: ^2.11.1
video_player_win: ^3.2.2
```

**fvp + video_player** — in genui's pubspec, replace `audioplayers` and
`video_player_win` with `fvp` (keep `video_player`). Stub out
audio_player.dart since `audioplayers` is removed:

```yaml
fvp: ^0.35.2
video_player: ^2.11.1
```

## Build & measure per platform

### Android

Use `--split-per-abi` so you get a per-architecture APK (arm64 is the most
representative for modern devices):

```bash
flutter build apk --release --split-per-abi
ls -lh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### iOS

Build without codesigning (not needed for size measurement):

```bash
flutter build ios --release --no-codesign
du -sh build/ios/iphoneos/Runner.app
```

### Linux

```bash
flutter build linux --release
du -sh build/linux/x64/release/bundle
```

### Windows

```powershell
flutter build windows --release
# Measure: build\windows\x64\runner\Release\
```

## Recording results

For reference, the following artifacts were measured for each platform:
*   **Android**: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
*   **iOS**: `build/ios/iphoneos/Runner.app`
*   **Linux**: `build/linux/x64/release/bundle`
*   **Windows**: `build\windows\x64\runner\Release\`
*   **macOS**: `build/macos/Build/Products/Release/Runner.app`

Fill in the table with your measurements:

| Platform | Baseline | audioplayers + video_player  | fvp + video_player           |
| -------- | -------- | ---------------------------- | ---------------------------- |
| Android  | 17.8 MB  | 18.7 MB (+0.9 MB / +5.1%)    | 30.3 MB (+12.5 MB / +70.3%)  |
| iOS*     | 18.0 MB  | 20.0 MB (+2.0 MB / +11.1%)   |                              |
| Linux    |          |                              |                              |
| Windows  | 29.9 MB  | 30.5 MB (+0.6 MB / +1.9%)    | 44.9 MB (+15.0 MB / +50.1%)  |
| macOS    | 44 MB    | 46 MB (+2 MB / +5%)          | 68 MB (+24 MB / +55%)        |

\* These measurements were taken with the minimum iOS deployment target set to iOS 15.0. If an app targets iOS 13 or 14 (Flutter's default minimum is 13), the size impact will be much larger (+8.6 MB total instead of +2.0 MB). This is because iOS < 15 lacks built-in support for Swift concurrency (async/await), forcing Xcode to bundle the `libswift_Concurrency.dylib` back-deployment library (~7.4 MB) into the app framework. Apps that already include any Swift concurrency plugin, or that target iOS 15+, do not pay this cost.

