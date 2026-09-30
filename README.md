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
Windows builds continue to use `tools` beside `obssource.exe`. Tools are found
automatically in the OBS plugin-local `flutter_obs_tools` directory, standalone
`tools`, and finally `PATH`. Manual tool-path overrides are no longer supported.

Configure music in **Overlay settings → Player**. Options are saved locally
with the overlay preferences and apply without restarting OBS:

| Option | Default |
| --- | --- |
| Accept music requests | On |
| Music volume | 70% (0–100%) |
| Music volume during TTS | 25% of the configured music volume |
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
Music volume changes apply to the active track immediately, including while
TTS is playing.

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

## TTS Channel Points

Open **Overlay settings → TTS** to enable processing, enter the service URL
(default https://api.teamplay.com.ua/tts/v1), select a mood, and create or select
an app-managed reward. Voice and language use the server defaults. Rewards must
require text and retain redemptions in Twitch's queue, and cannot also be
assigned to music. New rewards cost 1000 points; edit their name and price on
Twitch and refresh the list.

The base URL includes the full API prefix and version. The overlay appends
/health on startup and once per minute. Settings show the
last result, check time, and connected/healthy agent counts. The reward is
automatically paused when the service, Twitch subscription, local audio, or
queue is unavailable. The overlay controls the selected reward's paused state,
including after a restart. To turn it off manually, disable TTS processing or
disable the reward on Twitch; disabled rewards are never automatically enabled.

Requests run in order, up to ten including the active request, with a
1024 Unicode code-point limit (inclusive). The client uses synchronous POST /audio/speech
relative to the base URL,
with a 100-second HTTP deadline and a two-minute limit for queueing plus
generation. Any timeout is terminal: cancel/refund the Twitch redemption,
discard late audio, and never poll or resubmit the synthesis job. The server
may finish its work independently.

Before each speech file, assets/tts_notification.wav plays to completion,
followed by one second of silence. The notification is a dedicated sound
stored as 16-bit PCM WAV, 44.1 kHz stereo. Both files use the OBS audio host; music
is temporarily reduced to the percentage chosen in Player settings (initially
25% of its configured volume). Native audio completion events are required.
The test button uses the same audio path without spending Channel Points.
The speech volume slider (0–200%, initially 100%) is saved in TTS settings and
applies immediately to current speech, including test playback. It does not
change the notification sound's volume.

Redemption IDs are kept only in memory for the current session to ignore duplicate
events. Each request gets one Twitch fulfillment/refund attempt. Failed updates
and requests interrupted by a crash are left for moderators to resolve on Twitch.
There are no retries, persisted request records, or recovery of pending requests
on startup or reconnection. Use one active overlay for a channel.
Orderly shutdown pauses the reward. Abrupt termination or loss of internet
cannot immediately pause it.

Validation:

    flutter test test/tts
    dart run tools/check_tts.dart https://api.teamplay.com.ua/tts/v1

The second command performs one real short synthesis, validates WAV and SHA-256,
and removes the temporary audio; it does not modify Twitch rewards.

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
