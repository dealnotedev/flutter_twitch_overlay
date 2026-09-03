# Freydis Overlay Changelog

## [1.0.0] — 2026-09-03

The first release of Freydis Overlay, a Twitch overlay for OBS featuring pixel-art notifications and
a controllable music request queue.

### Twitch and notifications

- Added Twitch authentication and EventSub integration with automatic reconnection and cleanup of
  inactive subscriptions.
- Added new-follower notifications featuring a pixel-art animation, the follower's name and avatar,
  and a sound effect.
- Added an optimized atlas renderer and a compatible legacy renderer for follower animations; avatar
  resolution can be configured through the OBS source settings.
- Added animated channel points reward notifications showing the viewer's avatar, reward name, and
  cost.
- Duplicate events are filtered by ID.
- Added indicators for the Twitch connection state and invalid OBS source configuration.

### Music requests

- Viewers can add tracks to the queue through a configurable channel points reward by submitting a
  `youtube.com` or `youtu.be` URL.
- Track metadata and audio are retrieved with `yt-dlp`, FFmpeg, and Deno, and requests are played in
  FIFO order.
- Added configurable queue length and track duration limits, with handling for missing or invalid
  URLs, live streams, and download failures.
- Added an interactive player showing artwork, track title, artist, playback progress, and upcoming
  requests.
- The player supports pause and resume, seeking, skipping the current track, and removing queued
  requests.
- In OBS, the player automatically collapses into a compact view and expands when the queue changes,
  on hover or click, or when the `!music` command is posted in Twitch chat.
- Playback is integrated with OBS Audio and supports native started, progress, ended, and error
  events, with a duration-based fallback for track completion.
- Music volume is configured independently from other overlay sounds and updates for the active
  track without restarting playback.
- Added a persistent MP3 cache keyed by YouTube video ID, with a configurable size limit, LRU
  eviction, and isolated handling of incomplete downloads.

### Standalone music controller

- Added a standalone Windows application for controlling the music player without interacting with
  the OBS interface.
- The controller displays the full queue and connection state, reconnects automatically, and uses
  the same player interface as the overlay.
- The overlay remains responsible for the queue and playback, so closing the controller does not
  interrupt the music.
- Added a versioned local HTTP/WebSocket API under `/v1`, supporting pause, seek, skip, and queue
  removal commands.
- The control server binds only to IPv4 loopback, rejects browser-originated requests, and supports
  a configurable port.
- Added a dedicated application icon for the controller.

### Configuration and localization

- Added OBS source settings for music and follower notifications, the music reward name, queue,
  duration, and cache limits, volume, animation options, and the local control server.
- Added Ukrainian and English localization; Ukrainian is used by default.
- Expanded the pixel font with Ukrainian characters and standardized the pixel size at 8 px.
- Added a script that downloads and verifies the SHA-256 checksums of the Windows builds of
  `yt-dlp`, FFmpeg, FFprobe, and Deno.
- Music tools are discovered automatically in the OBS plugin directory, beside the standalone
  executable, or through `PATH`; explicit development overrides are also supported.

### Performance and reliability

- Moved pixel animations to batched rendering with `drawRawAtlas`.
- Added tests for OBS configuration, Twitch EventSub handling, notifications, pixel animations, the
  music queue, caching, the audio bridge, the local protocol, and the remote controller.
