# Supporting Audio and Video in the Standard Catalog

## Summary

We want the `genui` library provide a complete Flutter implementation of the
A2UI standard catalog (see `packages/genui/lib/src/catalog/basic_catalog_widgets`).

Almost all of the standard catalog can be implemented using built-in Flutter
widgets without taking on additional dependencies. The two that cannot are
`AudioPlayer` and `Video`. Today, the `genui` library stubs these out with
placeholders.

The initial concern was that implementing real audio/video playback would
require heavy native dependencies (bundled media engines like libmpv/Ffmpeg or
libmdk), inflating binary size for all genui users—even those who don't need
audio/video.

However, after some research, the problem seems much less dire (with one major caveat):

- **Audio** is fully solved by `audioplayers`, which covers all 6 platforms
  using lightweight OS-provided APIs.
- **Video** is mostly solved by `video_player`, which
  covers Android, iOS, macOS, and Web using OS-native APIs. Windows support is
  available via `video_player_win`, a federated plugin that auto-registers with
  no code changes —just a pubspec addition. **The only remaining gap is Linux
  video**, which has no well-established lightweight `video_player` platform
  implementation.

The major caveat, then, is video playback on Linux. Here, there are two options:

1. write our own package that uses build hooks to conditionally import a heavier package on Linux, or
2. leave video playback on Linux unsupported and fail gracefully with debug time placeholders and warnings.

## Flutter audio/video library landscape

**Audio:**

- `just_audio`: Android, iOS, macOS, Web. No native Linux/Windows support
  (available via `just_audio_media_kit` add-on, but that pulls in media_kit's
  heavy native binaries on those platforms). Lightweight on
  supported platforms. More features than we need (gapless playlists,
  sequencing, clipping).
- `audioplayers`: All 6 platforms natively using OS-provided APIs. Lightweight
  everywhere. Supports all the basic features we need:
  URL playback, play/pause/stop/seek, volume control, and position/duration streams.

**Video:**

- `video_player`: Android, iOS, macOS, Web. **No
  Linux/Windows support**—the Flutter team hasn't prioritized it.
  Windows support can be achieved with `video_player_win`, a federated plugin implementation for Windows. Uses Windows
  Media Foundation.
- `media_kit`: All 6 platforms via bundled libmpv/FFmpeg. Heavy (~+47 MB on
  macOS). The only single-package option for full cross-platform video.
- `fvp`: Implements the `video_player` platform interface using libmdk
  (lighter than media_kit's libmpv/FFmpeg). Supports all 6 platforms including
  Linux and Windows. Added 24 MB on macOS testing.

**Combined:**

- `media_kit` handles both audio and video.
- `video_player_media_kit` bridges `media_kit` into the standard `video_player`
  API, allowing existing `video_player` APIs to work on Linux/Windows.

### Size impact (macOS release build of `examples/catalog_gallery`)

| Build                                            | App Size | Delta          |
| ------------------------------------------------ | -------- | -------------- |
| **Baseline** (no audio/video deps)               | 44 MB    | —              |
| **audioplayers + video_player** (OS-native APIs) | 46 MB    | +2 MB (+5%)    |
| **fvp** (bundles libmdk, all platforms)          | 68 MB    | +24 MB (+55%)  |
| **media_kit** (bundles libmpv/FFmpeg)            | 91 MB    | +47 MB (+107%) |

### Size impact (Android arm64 release APK of `examples/catalog_gallery`)

| Build                                            | App Size | Delta          |
| ------------------------------------------------ | -------- | -------------- |
| **Baseline** (no audio/video deps)               | 18 MB    | —              |
| **audioplayers + video_player** (OS-native APIs) | 19 MB    | +1 MB (+4%)    |
| **fvp** (bundles libmdk, all platforms)          | 30 MB    | +12 MB (+70%)  |

### Size impact (Windows release build of `examples/catalog_gallery`)

| Build                                            | App Size | Delta          |
| ------------------------------------------------ | -------- | -------------- |
| **Baseline** (no audio/video deps)               | 30 MB    | —              |
| **audioplayers + video_player** (OS-native APIs) | 30 MB    | +0 MB (+1%)    |
| **fvp** (bundles libmdk, all platforms)          | 45 MB    | +15 MB (+50%)  |

The lightweight libraries (`audioplayers`, `video_player`) use OS-provided APIs
(AVPlayer on macOS/iOS, ExoPlayer on Android, HTML elements on web), so they
add almost no binary weight. `fvp` bundles libmdk and `media_kit` bundles
libmpv/FFmpeg—both add significant weight on all platforms, even if the app
never plays audio or video.

### Platform coverage summary

| Component | Android | iOS | macOS | Web | Windows         | Linux |
| --------- | ------- | --- | ----- | --- | --------------- | ----- |
| **Audio** | ✅      | ✅  | ✅    | ✅  | ✅              | ✅    |
| **Video** | ✅      | ✅  | ✅    | ✅  | ✅ (w/ drop-in) | ❌    |

Audio: `audioplayers` — all 6 platforms, OS-native APIs, lightweight.
Video: `video_player` — Android/iOS/macOS/Web natively.
`video_player_win` adds Windows as a federated plugin.

### Could native assets enable platform-conditional dependencies?

Flutter's native assets feature (stable in Flutter 3.38/Dart 3.10) allows
packages to define `hook/build.dart` scripts that compile or download native
libraries at build time. The build hook knows the target platform, so in
theory a package could download libmdk only when building for Linux and skip it
entirely on other platforms (where `video_player` already has lightweight
OS-native support).

This would be meaningfully different from `fvp`, which bundles libmdk on
_all_ platforms unconditionally. A native-assets-based approach could give
add only 2MB on macOS (video_player only) instead of 24MB (fvp everywhere),
while covering Linux with the heavier backend only where needed.

This is promising in principle but comes with a non-trivial development and
maintance cost. This level of developer experience optimization is premature in
this early stage of the `genui` library.

### The user can always implement their own audio and video players

The `Catalog` class already provides `copyWith` and `copyWithout` methods that
let users replace or remove any catalog item by name. A user who wants a custom
audio/video implementation (e.g. YouTube embed) can already do:

```dart
final catalog = BasicCatalogItems.asCatalog()
    .copyWithout(itemsToRemove: [BasicCatalogItems.video])
    .copyWith(newItems: [myCustomVideoPlayer]);
```

## Plan

Add `audioplayers`, `video_player`, and `video_player_win` as dependencies of
the `genui` package. This completes the standard catalog on 5/6 platforms with
negligible size impact (+2 MB / +5%).

On Linux, the Video catalog item should render a graceful fallback (e.g. a
placeholder with a "Video playback is not supported on this platform" message)
and log a warning so developers are aware during development. Linux users who
need video can provide their own `CatalogItem` via `Catalog.copyWith`.

### Alternatives considered

- **Separate package** (e.g. `genui_media`): Not worth it given the +2 MB
  cost. Adds a setup step and a package to maintain for negligible savings.
- **Keep current placeholders**: Leaves the standard catalog incomplete out of
  the box. Every user wanting audio/video would have to build from scratch.

If Linux video becomes a common need, we can revisit the native assets
approach (see above) or take on `fvp` as an optional add-on later.
