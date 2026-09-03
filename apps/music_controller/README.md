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

The default overlay endpoint is `http://127.0.0.1:47821`. To use another port:

```powershell
flutter run -d windows -- --port=47900
```
