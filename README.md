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

Choose the music Channel Points reward from the overlay settings next to the
Twitch connection indicator. The reward must be managed by this application,
require viewer input, and keep redemptions in Twitch's request queue. Invalid,
unavailable, overlong, failed, or manually removed requests are canceled so
Twitch refunds their points. A request is fulfilled after playback finishes or
is skipped while playing. If Twitch cannot be updated, the redemption remains
unfulfilled so the streamer can resolve it in Twitch's moderation interface.

For precise queue advancement, the native audio host publishes JSON messages on
`obs_audio_events` with `event` set to `loaded`, `started`, `progress`, `ended`,
or `error`, plus the numeric `id` and optional `session_id`. The player waits for
the native load and start confirmations, surfaces decoder failures, and advances
the queue on `ended`. A duration-based watchdog remains for older native hosts.

## Optional Windows music controller

The overlay owns the music queue, playback, and a loopback-only control server.
The standalone controller in `apps/music_controller` is optional; closing it
does not interrupt playback. Its player UI imports the same
`MusicQueueOverlay` used by OBS.

The default endpoint is `http://127.0.0.1:47821`. Override the port in the OBS
source configuration and pass the same port to the controller when needed:

```json
{
  "music_control_server_enabled": true,
  "music_control_server_port": 47821
}
```

```powershell
cd apps\music_controller
flutter run -d windows -- --port=47821
```

The local interface is versioned under `/v1`: `GET /health`, `GET /player`,
`POST /player/commands`, and WebSocket `/player/events`. The server binds only
to IPv4 loopback and rejects browser-originated requests.
