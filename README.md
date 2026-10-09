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

The OBS source JSON configures rendering for all user alerts, including
follow, raid, and subscription animations:

```json
{
  "alert_animation_renderer": "optimized",
  "alert_avatar_resolution": 48
}
```

The settings apply to avatars, text, and pixel decorations. Changes also update
alerts that are already visible. Supported renderer values are `optimized` (the default `drawRawAtlas` renderer) and
`legacy` (the previous canvas renderer). The avatar resolution defaults to
`48`; its pixel size remains fixed at `8`.

Subscription alerts are enabled by default; set `"subscriptions": false` in
the OBS source JSON to disable them. They handle new subscriptions, shared
resubscription messages (total months), and single or bulk gifts. Gift recipients
do not trigger duplicate alerts. Anonymous givers appear as `Анонім`.
The alerts use l10n translations (Ukrainian and English), the shared avatar animation, a
20-second lifetime, and a dedicated sound for each subscription event. Subscription alerts play in
arrival order, one at a time, with audio starting when each alert is shown.
The bundled sounds in `assets/subscriptions/` are `subscription_purchase.wav`
for a new subscription, `subscription_renewal.wav` for a shared resubscription
message, and `subscription_gift.wav` for a single or bulk gift.
Twitch authorization requires
`channel:read:subscriptions`; older tokens without this scope need a new login.

## Twitch music requests MVP

Create or select an app-managed Twitch channel-points reward in
**Overlay settings → Player**. A viewer must enter a full `youtube.com` or
`youtu.be` URL. The Flutter overlay validates the request, resolves metadata,
downloads MP3 audio with `yt-dlp`, and plays the FIFO queue through `ObsAudio`.

Prepare the bundled Windows toolchain once from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\download_tools.ps1
```

The script downloads and verifies `yt-dlp` and Deno, then builds a compact
audio-focused FFmpeg from checksum-pinned sources. The private build environment
stays in `build/ffmpeg-minimal`; see [tools/README.md](tools/README.md) for details.
`ffprobe` is unnecessary: yt-dlp uses FFmpeg itself to inspect audio.
For an installed OBS plugin, copy `yt-dlp.exe`, `deno.exe`, `ffmpeg.exe`,
`ffmpeg-build.txt`, `FFmpeg-LICENSE.txt` and `LAME-LICENSE.txt` to this directory
(remove an old `ffprobe.exe` there when upgrading):

```text
<OBS root>\obs-plugins\64bit\flutter_obs_tools\
```

For example, a default OBS installation uses
`C:\Program Files\obs-studio\obs-plugins\64bit\flutter_obs_tools`. Standalone
Windows builds continue to use `tools` beside `obssource.exe`. Tools are found
automatically in the OBS plugin-local `flutter_obs_tools` directory, standalone
`tools`, and finally `PATH`. Manual tool-path overrides are no longer supported.

Configure music in **Overlay settings → Player**. Options are saved locally
with the overlay preferences and apply without restarting OBS:

| Option | Default |
| --- | --- |
| Accept music requests | On |
| Music volume | 70% (0–100%) |
| Maximum number of tracks, including the playing track | 10 |
| Maximum duration of a new request | 600 seconds |
| Cache size | 2048 MB; 0 means unlimited |
| Local controller server | On |
| Local controller port | 47821 (1–65535) |

Music options in OBS JSON are no longer read or migrated. Configure them anew
in the UI. Existing reward selection and presentation preferences are retained.
Changing limits preserves accepted requests, including tracks still preparing.
Disabling requests pauses the selected Twitch reward and refunds late requests;
accepted tracks continue playing. The reward is also paused while the Twitch
event connection is unavailable and on orderly shutdown. Re-enabling requests
resumes the reward's paused state without enabling rewards disabled on Twitch.
Settings show failed reward updates and offer a retry.

Completed tracks are cached by YouTube video ID in
the per-user `obssource/music-cache/youtube-mp3-q0-v1` directory. Cache entries
survive playback, queue removal, and application restarts. Old entries are
removed least-recently-used when the cache exceeds its configured limit. Tracks
used in the current session are protected, so the limit can temporarily be
exceeded. Incomplete downloads are kept in an isolated staging
directory and never become cache hits.
Music volume changes apply to the active track immediately.

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

## YouTube verification

When YouTube blocks every request — a bot check or captcha, a media HTTP 403,
or a temporary rate limit — the overlay pauses track preparation instead of
refunding the queue one request at a time. Waiting requests stay in the queue,
the music reward is paused on Twitch, and the player shows that requests are
paused. A request that waits longer than 15 minutes is refunded. Problems with
a single video (private, age-restricted, removed or region-locked) are still
refunded right away and do not pause the queue.

To recover, open **Overlay settings → Player → YouTube connection → Connect
YouTube**. The app opens a separate Microsoft Edge or Google Chrome window
with the blocked video. Play it (or choose a short public video if the
homepage opens), complete any verification requested by YouTube, then return
to the settings and press **Check connection**. The window closes as soon as
its YouTube session is exported, because YouTube rotates the cookies of open
sessions and the local debugging port should not stay open. The check then
verifies metadata and a full audio download of that video in a private,
empty cache before reporting success. On success, waiting requests continue
automatically. For a rate limit, wait (usually up to an hour) and press
**Resume requests**; this button also retries without connecting.

Try checking without signing in first. A public video playing in the browser
does not guarantee that yt-dlp can retrieve its audio. A media HTTP 403 is
often fixed by a newer yt-dlp, so check the yt-dlp version in **Error
details**. Signing in to Google in the dedicated window can also help, but
use a secondary account: YouTube may restrict accounts used for downloading.
The checked video URL and error details appear only in settings; they are not
broadcast on the overlay or sent to the music controller.

The app uses its own browser profile and saves only the YouTube session locally
under the user's `obssource/youtube-session` directory next to the music cache.
It does not read the user's normal browser profile. No command-line setup,
browser extension, or manual cookie export is needed. Every yt-dlp run gets a
private copy of the session; YouTube's cookie updates are written back only
after a successful run and never over a newer or removed session. **Cancel**
closes the browser and keeps the saved session. **Disconnect** asks for
confirmation, then removes the saved session and the dedicated profile,
including any Google sign-in there.

## Optional Windows music controller

The overlay owns the music queue, playback, and a loopback-only control server.
The standalone controller in `apps/music_controller` is optional; closing it
does not interrupt playback. Its player UI imports the same
`MusicQueueOverlay` used by OBS.

The default endpoint is `http://127.0.0.1:47821`. Enable or disable the server
and change its port in **Overlay settings → Player → Local music controller
server**. Settings show the running endpoint or a startup error (for example,
an occupied port) with a retry button. Port changes restart only the control
server, preserving playback and the queue. Pass the same port to the controller:

```powershell
cd apps\music_controller
flutter run -d windows -- --port=47821
```

The local interface is versioned under `/v1`: `GET /health`, `GET /player`,
`POST /player/commands`, and WebSocket `/player/events`. The server binds only
to IPv4 loopback and rejects browser-originated requests.
