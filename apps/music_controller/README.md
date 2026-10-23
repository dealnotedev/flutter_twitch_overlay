# OBS Music Controller

Optional Windows controller for the music player hosted by the OBS overlay.
The application uses the shared `MusicQueueOverlay` from the repository root
and connects to the overlay over loopback HTTP and WebSocket.

From the repository root, generate the shared localizations once, then run or
build the controller:

```powershell
flutter gen-l10n
cd apps\music_controller
flutter pub get
flutter run -d windows
flutter build windows --release
```

The default overlay endpoint is `http://127.0.0.1:47821`. Enable the local server
in **Overlay settings → Player**. If its preferred port is occupied, the overlay
selects a free port and shows its actual listening address. To connect the
controller, pass that actual port:

```powershell
flutter run -d windows -- --port=47900
```

To control Twitch Listener directly, run it and use `--port=47822`. Both hosts
use the shared `dart_music_player_protocol` contract and native transport. Audio remains in
the selected host application; the controller does not play audio.
