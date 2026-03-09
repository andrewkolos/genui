# Supporting Audio and Video in the Standard Catalog

## Summary

We want the `genui` library provide a complete Flutter implementation of the
A2UI standard catalog (see `packages/genui/lib/src/catalog/basic_catalog_widgets`).

Almost all of the standard catalog can be implemented using built-in Flutter
widgets without taking on additional dependencies. The two that cannot are
`AudioPlayer` and `Video`. Today, the `genui` library stubs these out with
placeholders.

The initial concern was that implementing real audio/video playback would
require heavy native dependencies (bundled media engines like libmpv or
libmdk), inflating binary size for all genui users—even those who don't need
audio/video.

However, after some research, the problem seems much less dire (with one major caveat):

- **Audio** is fully solved by `audioplayers`, which covers all 6 platforms
  using lightweight OS-provided APIs.
- **Video** is mostly solved by `video_player`, which
  covers Android, iOS, macOS, and Web using OS-native APIs. Windows support is
  available via `video_player_win`, a federated plugin that auto-registers with
  no code changes — just a pubspec addition. **The only remaining gap is Linux
  video**, which has no well-established lightweight `video_player` platform
  implementation.

The major caveat, then, is video playback on Linux. Here, there are two options:

1. write our own package that uses build hooks to conditionally import a heavier package on Linux, or
2. leave video playback on Linux unsupported and fail gracefully with debug time placeholders and warnings.

## Flutter audio/video library landscape

**Audio:**

- `just_audio` — Android, iOS, macOS, Web. No native Linux/Windows support
  (available via `just_audio_media_kit` add-on, but that pulls in media_kit's
  heavy native binaries on those platforms). Lightweight on
  supported platforms. More features than we need (gapless playlists,
  sequencing, clipping).
- `audioplayers` — All 6 platforms natively using OS-provided APIs. Lightweight
  everywhere. Supports all the basic features we need:
  URL playback, play/pause/stop/seek, volume control, and position/duration streams.

**Video:**

- `video_player` — Android, iOS, macOS, Web. **No
  Linux/Windows support**—the Flutter team hasn't prioritized it.
  Windows support can be achieved with `video_player_win`, a federated plugin implementation for Windows. Uses Windows
  Media Foundation.
- `media_kit` — All 6 platforms via bundled libmpv/FFmpeg. Heavy (~+47 MB on
  macOS). The only single-package option for full cross-platform video.
- `fvp` — Implements the `video_player` platform interface using libmdk
  (lighter than media_kit's libmpv/FFmpeg). Supports all 6 platforms including
  Linux and Windows. Added +24 MB on macOS testing.

**Combined:**

- `media_kit` handles both audio and video. Using `_video` libs includes audio
  support, so a user needing both would not have redundant native deps.
- `video_player_media_kit` bridges `media_kit` into the standard `video_player`
  API, allowing existing `VideoPlayerController` code to work on Linux/Windows.

### Could native assets enable platform-conditional dependencies?

Flutter's native assets feature (stable in Flutter 3.38/Dart 3.10) allows
packages to define `hook/build.dart` scripts that compile or download native
libraries at build time. The build hook knows the target platform, so in
theory a package could download libmdk only when building for Linux and skip it
entirely on other platforms (where `video_player` already has lightweight
OS-native support).

This would be meaningfully different from `fvp`, which bundles libmdk on
_all_ platforms unconditionally. A native-assets-based approach could give
you +2 MB on macOS (video_player only) instead of +24 MB (fvp everywhere),
while covering Linux with the heavier backend only where needed.

The catch: this means reimplementing the download-and-link logic that `fvp`
gets for free as a pub dependency. You can't conditionally depend on a pub
package per-platform — Dart's dependency graph is platform-agnostic. So you'd
write a local package with a build hook that fetches pre-built libmdk binaries
for Linux and wires them up via FFI, while delegating to `video_player`
on other platforms. Not trivial, but not a full media engine rewrite either —
the heavy lifting (decoding, rendering) is still done by libmdk or OS APIs.

**Status:** Promising in principle but significant implementation effort.
Worth revisiting if Linux video support becomes a real priority.

### Note: custom implementations are already supported

The `Catalog` class already provides `copyWith` and `copyWithout` methods that
let users replace or remove any catalog item by name. A user who wants a custom
audio/video implementation can already do:

```dart
final catalog = BasicCatalogItems.asCatalog()
    .copyWith(newItems: [myCustomVideoPlayer]);
```

This means "pluggable overrides" is not a new feature to design — it's already
part of the catalog API. The question is purely about what default
implementations genui ships, not about extensibility.

## Options

### Option A: Bundle lightweight deps directly in genui

Add `audioplayers`, `video_player`, and `video_player_win` as dependencies of
the `genui` package. This completes the standard catalog on Android, iOS,
macOS, Web, and Windows with minimal size impact (+2 MB on macOS). On Linux,
the Video component would show a graceful fallback (e.g. an informational
placeholder or assertion in debug builds) rather than crashing.

**Pros:**

- Simplest for users — standard catalog works out of the box on 5/6 platforms.
- Minimal binary size cost (+2 MB / +5%).
- No new packages to create or maintain.
- `audioplayers` covers all 6 platforms for audio — AudioPlayer is complete
  everywhere.
- Linux users can still provide their own Video `CatalogItem` via `copyWith`
  if needed.

**Cons:**

- Video does not work on Linux. Requires a graceful fallback (placeholder
  widget + debug assertion or log warning).
- Users who never encounter Audio/Video components still pay the (small)
  dependency cost.

### Option B: Separate package for audio/video implementations

Keep `genui` free of audio/video dependencies. Create a new package (e.g.
`genui_media`) that exports AudioPlayer and Video `CatalogItem`s using
`audioplayers` + `video_player`. Users opt in by adding `genui_media` and
merging its items into their catalog via `copyWith`.

**Pros:**

- Users who don't need audio/video pay zero cost.
- Clean separation — audio/video deps don't pollute the core package.

**Cons:**

- Extra setup step for users who do want audio/video — they need to add a
  second package and wire up the items.
- Another package to publish and maintain.
- Same Linux video gap as Option A.

### Option C: Keep current placeholders (no default implementation)

Ship no real audio/video implementation. Keep the current icon/placeholder
fallbacks. Users who need real playback provide their own `CatalogItem`s
via `copyWith`.

**Pros:**

- Zero forced dependencies.
- Sidesteps the Linux gap entirely.

**Cons:**

- The standard catalog is never truly "complete" out of the box.
- Every user who wants audio/video must build their own widget from scratch.
- Higher barrier to entry for new users.

## Recommendation

**Option A** — bundle lightweight defaults directly in genui.

The size cost of `audioplayers` + `video_player` + `video_player_win` is
negligible (+2 MB / +5% on macOS). This makes the standard catalog work out
of the box on Android, iOS, macOS, Web, and Windows — covering the vast
majority of Flutter deployment targets.

**Handling the Linux video gap:** On Linux, the Video catalog item should
render a graceful fallback (e.g. a placeholder with a message like "Video
playback is not supported on this platform") and fire a debug assertion or log
warning so developers are aware during development. This is consistent with
how other Flutter packages handle unsupported platforms — fail informatively,
don't crash. Linux users who need video can provide their own `CatalogItem`
via `copyWith`, or add `fvp` alongside a custom Video item that uses it.

Users who need something different already have the tools to handle it — the
existing `Catalog.copyWith` API lets them swap in YouTube embeds, Spotify
players, or any other custom implementation with no new APIs needed.

If Linux video becomes a common need, we can revisit the native assets
approach or take on `fvp` as an optional add-on later.
