# Bundled music tools

Run `powershell -ExecutionPolicy Bypass -File .\tools\download_tools.ps1` from
the repository root. The script downloads and verifies the current Windows x64
releases of:

- `yt-dlp.exe` from the official yt-dlp GitHub release;
- `deno.exe` from the official Deno GitHub release;
- `ffmpeg.exe` and `ffprobe.exe` from the FFmpeg release-essentials build by
  gyan.dev, one of the Windows build providers linked by ffmpeg.org.

The executables are ignored by Git and copied into `tools` beside
`obssource.exe` by the Windows CMake install step.

Versions downloaded and verified on 2026-09-03:

- yt-dlp `2026.08.19`;
- Deno `2.9.6`;
- FFmpeg and FFprobe `9.0.1-essentials_build-www.gyan.dev`.
