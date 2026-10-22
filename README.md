# OBS Flutter overlay

The music player supports Twitch channel point requests, a downloadable YouTube
queue with an MP3 cache, and local or external playback through the shared
`dart_music_player_protocol` protocol. Both the cosmic player and vinyl turntable
are available. Existing overlay effects run independently of the music layer.

## Player settings

Hover over the connection indicator in the upper right and press the settings
button. Before Twitch login, the settings button is always visible.
The dialog retains section navigation like `freydis`, with a single Player
section for now.

Settings include player appearance, local/external source and port, volume,
queue and track duration limits, cache size, the controller server, YouTube
connection verification, and the Twitch music reward. The cosmic player also
supports an auto-collapse delay and an always-expanded mode; `!music` in chat
expands it. Preferences and the existing Twitch login persist locally.

Local requests use a Twitch reward with required text input and an enabled
redemption queue. The settings can create or select a compatible reward. Twitch
authorization needs `channel:manage:redemptions`; reconnect an existing account
if it was authorized with read-only redemption access. External playback and its
settings are available without logging the overlay into Twitch.

## Windows setup

Keep the existing local `lib/secrets.dart` configuration. Restore the downloader
tools as described in [tools/README.md](tools/README.md), then run:

```powershell
flutter pub get
flutter build windows
```

Windows builds verify the pinned yt-dlp release and package the music tools.
Local playback uses the OBS host's `obs_audio` and `obs_audio_events` channels;
the host must support file loading, playback, pause, seek, volume and release.

The standalone Windows controller is in
[apps/music_controller](apps/music_controller/README.md). Its default endpoint is
`127.0.0.1:47821`; the external source defaults to `127.0.0.1:47822`.

## Verification

```powershell
flutter test
flutter analyze
cd apps/music_controller
flutter pub get
flutter test
flutter analyze
```

The controller is analyzed separately from the main application.
