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
and select its port in **Overlay settings → Player** in the overlay. To connect
the controller to another port, pass the same value:

```powershell
flutter run -d windows -- --port=47900
```

To control Twitch Listener directly, run it and use `--port=47822`. Both hosts
use the shared `dart_music_player_protocol` contract and native transport. Audio remains in
the selected host application; the controller does not play audio.
