# obssource

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## OBS source configuration

The OBS source JSON can select the renderer used by the complete follow
animation:

```json
{
  "follow_animation_renderer": "optimized",
  "follow_avatar_resolution": 48
}
```

Supported values are `optimized` (the default `drawRawAtlas` renderer) and
`legacy` (the previous canvas renderer). The avatar resolution defaults to
`48`; its pixel size remains fixed at `8`.

## Twitch music requests MVP

Create a custom Twitch channel-points reward named `Play Music` and enable
**Require Viewer to Enter Text**. A viewer must enter a full `youtube.com` or
`youtu.be` URL. The Flutter overlay validates the request, resolves metadata,
downloads MP3 audio with `yt-dlp`, and plays the FIFO queue through `ObsAudio`.

Download the bundled Windows toolchain once from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\download_tools.ps1
```

The script verifies SHA-256 checksums and installs `yt-dlp`, `ffmpeg`,
`ffprobe`, and Deno into the repository `tools` directory. For an installed OBS
plugin, copy the four executables to this plugin-local directory:

```text
<OBS root>\obs-plugins\64bit\flutter_obs_tools\
```

For example, a default OBS installation uses
`C:\Program Files\obs-studio\obs-plugins\64bit\flutter_obs_tools`. Standalone
Windows builds continue to use `tools` beside `obssource.exe`. No tool paths
are required in the OBS source JSON:

```json
{
  "music_enabled": true,
  "music_reward_title": "Play Music",
  "music_max_queue": 10,
  "music_max_duration_seconds": 600,
  "music_cache_max_mb": 2048,
  "music_volume_percent": 70
}
```

For development, `music_ytdlp_path`, `music_ffmpeg_location`, and
`music_deno_path` remain optional overrides. Resolution order is an explicit
override, the OBS plugin-local `flutter_obs_tools` directory, standalone
`tools`, and finally `PATH`. Completed tracks are cached by YouTube video ID in
the per-user `obssource/music-cache/youtube-mp3-q0-v1` directory. Cache entries
survive playback, queue removal, and application restarts. Old entries are
removed least-recently-used when the cache exceeds `music_cache_max_mb`; set it
to `0` for no size limit. Incomplete downloads are kept in an isolated staging
directory and never become cache hits.
`music_volume_percent` is clamped to `0..100`, applies only to music tracks,
and updates the active track immediately when the OBS source configuration is
changed.

For precise queue advancement, the native audio host can publish JSON messages
on `obs_audio_events` with `event` set to `started`, `progress`, `ended`, or
`error`, plus the numeric `id` and optional `session_id`. Until that callback is
implemented, the MVP advances using the duration reported by `yt-dlp` plus a
small grace period.
