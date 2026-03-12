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

## Setup

All commands run from `examples/catalog_gallery/`.

Between each build, edit `pubspec.yaml` to swap dependency sets and run
`flutter pub get`. Restore the original pubspec when done.

### Dependency sets

**Baseline** — no changes. Use the existing pubspec as-is.

**audioplayers + video_player** — add via pub:

```bash
dart pub add audioplayers video_player video_player_win
```

**fvp + video_player** — remove the above, then add:

```bash
dart pub remove audioplayers video_player video_player_win
dart pub add fvp video_player
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

Fill in the table with your measurements:

| Platform | Baseline | audioplayers + video_player | fvp + video_player        |
| -------- | -------- | --------------------------- | ------------------------- |
| Android  | 17.8 MB  | 18.5 MB (+0.7 MB / +4.0%)   | 30.2 MB (+12.4 MB / +70%) |
| iOS      |          |                             |                           |
| Linux    |          |                             |                           |
| Windows  | 30.0 MB  | 30.2 MB (+0.2 MB / +0.6%)   | 44.8 MB (+14.9 MB / +50%) |
| macOS    | 44 MB    | 46 MB (+2 MB / +5%)         | 68 MB (+24 MB / +55%)     |
