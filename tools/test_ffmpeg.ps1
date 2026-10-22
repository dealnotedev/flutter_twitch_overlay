[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ReferenceFfmpeg,
  [string]$Ffmpeg,
  [string]$YtDlp,
  [string]$Deno
)

# Offline integration test: real yt-dlp download, fixup and MP3 conversion.
# A full FFmpeg is only used to create fixtures and independently decode results.
$ErrorActionPreference = 'Stop'
if (-not $Ffmpeg) { $Ffmpeg = Join-Path $PSScriptRoot 'ffmpeg.exe' }
if (-not $YtDlp) { $YtDlp = Join-Path $PSScriptRoot 'yt-dlp.exe' }
if (-not $Deno) { $Deno = Join-Path $PSScriptRoot 'deno.exe' }
$ReferenceFfmpeg = (Resolve-Path -LiteralPath $ReferenceFfmpeg).Path
$Ffmpeg = (Resolve-Path -LiteralPath $Ffmpeg).Path
$YtDlp = (Resolve-Path -LiteralPath $YtDlp).Path
$Deno = (Resolve-Path -LiteralPath $Deno).Path
$testRoot = Join-Path (Split-Path $PSScriptRoot -Parent) ('build\ffmpeg-test-' + [guid]::NewGuid().ToString('N'))
$toolDirectory = Join-Path $testRoot 'tools'
$fixtures = Join-Path $testRoot 'fixtures'
New-Item -ItemType Directory -Force -Path $toolDirectory, $fixtures | Out-Null
Copy-Item -LiteralPath $Ffmpeg -Destination (Join-Path $toolDirectory 'ffmpeg.exe')
# This private directory deliberately contains no ffprobe, even if one is on PATH.

function Invoke-Reference {
  param([string[]]$Arguments)
  & $ReferenceFfmpeg -hide_banner -loglevel error -y @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Reference FFmpeg failed: $Arguments" }
}

$tone = @('-f', 'lavfi', '-i', 'sine=frequency=440:duration=2', '-ar', '48000')
Invoke-Reference ($tone + @('-c:a', 'libopus', (Join-Path $fixtures 'opus.webm')))
Invoke-Reference ($tone + @('-c:a', 'libvorbis', (Join-Path $fixtures 'vorbis.webm')))
Invoke-Reference ($tone + @('-c:a', 'aac', '-movflags', '+dash+frag_keyframe', (Join-Path $fixtures 'dash.m4a')))
Invoke-Reference ($tone + @('-c:a', 'aac', (Join-Path $fixtures 'audio.aac')))
Invoke-Reference ($tone + @('-c:a', 'libmp3lame', (Join-Path $fixtures 'audio.mp3')))
Invoke-Reference @('-f', 'lavfi', '-i', 'color=size=64x64:rate=10:duration=2', '-f', 'lavfi', '-i', 'sine=frequency=440:duration=2', '-c:v', 'libx264', '-c:a', 'aac', '-shortest', (Join-Path $fixtures 'video.mp4'))
Invoke-Reference @('-f', 'lavfi', '-i', 'color=size=64x64:rate=10:duration=2', '-f', 'lavfi', '-i', 'sine=frequency=440:duration=2', '-c:v', 'libvpx-vp9', '-c:a', 'libopus', '-shortest', (Join-Path $fixtures 'video.webm'))
Invoke-Reference ($tone + @('-c:a', 'aac', '-f', 'hls', '-hls_time', '1', '-hls_list_size', '0', '-hls_segment_filename', (Join-Path $fixtures 'segment-%03d.ts'), (Join-Path $fixtures 'audio.m3u8')))

$cases = @(
  @{ Name = 'opus'; File = 'opus.webm'; Ext = 'webm'; Codec = 'opus' },
  @{ Name = 'vorbis'; File = 'vorbis.webm'; Ext = 'webm'; Codec = 'vorbis' },
  @{ Name = 'dash'; File = 'dash.m4a'; Ext = 'm4a'; Codec = 'aac'; Container = 'm4a_dash' },
  @{ Name = 'aac'; File = 'audio.aac'; Ext = 'aac'; Codec = 'aac' },
  @{ Name = 'mp3'; File = 'audio.mp3'; Ext = 'mp3'; Codec = 'mp3' },
  @{ Name = 'video-mp4'; File = 'video.mp4'; Ext = 'mp4'; Codec = 'aac'; Video = 'h264' },
  @{ Name = 'video-webm'; File = 'video.webm'; Ext = 'webm'; Codec = 'opus'; Video = 'vp9' },
  @{ Name = 'hls'; File = 'audio.m3u8'; Ext = 'mp4'; Codec = 'aac'; Protocol = 'm3u8_native' }
)
$readyFile = Join-Path $testRoot 'server.port'
$serverScript = Join-Path $PSScriptRoot 'serve_ffmpeg_fixtures.js'
$server = Start-Process -FilePath $Deno -WindowStyle Hidden -PassThru `
  -ArgumentList @('run', '--allow-net=127.0.0.1', "--allow-read=`"$fixtures`"", "--allow-write=`"$readyFile`"", "`"$serverScript`"", "`"$fixtures`"", "`"$readyFile`"") `
  -RedirectStandardOutput (Join-Path $testRoot 'server.stdout.log') `
  -RedirectStandardError (Join-Path $testRoot 'server.stderr.log')
try {
  for ($attempt = 0; $attempt -lt 100 -and -not (Test-Path -LiteralPath $readyFile); $attempt++) {
    if ($server.HasExited) { throw 'Local fixture server exited before starting.' }
    Start-Sleep -Milliseconds 100
  }
  if (-not (Test-Path -LiteralPath $readyFile)) { throw 'Local fixture server startup timed out.' }
  $port = (Get-Content -LiteralPath $readyFile -Raw).Trim()
  foreach ($case in $cases) {
    $uri = "http://127.0.0.1:$port/$($case.File)"
    $info = @{
      id = $case.Name; title = $case.Name; url = $uri; webpage_url = $uri
      extractor = 'generic'; extractor_key = 'Generic'; ext = $case.Ext
      acodec = $case.Codec; vcodec = 'none'; duration = 2
    }
    if ($case.Video) { $info.vcodec = $case.Video }
    if ($case.Container) { $info.container = $case.Container }
    if ($case.Protocol) { $info.protocol = $case.Protocol }
    $infoPath = Join-Path $testRoot ($case.Name + '.json')
    [IO.File]::WriteAllText($infoPath, ($info | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    $destination = Join-Path $testRoot ($case.Name + ' output')
    $log = Join-Path $testRoot ($case.Name + '.log')
    try {
      # Windows PowerShell 5.1 treats redirected native stderr (including yt-dlp's
      # successful --verbose diagnostics) as errors. Check the process exit code.
      $ErrorActionPreference = 'Continue'
      & $YtDlp --ignore-config --no-colors --encoding utf-8 --no-playlist `
        --load-info-json $infoPath --format 'ba/b' `
        --extract-audio --audio-format mp3 --audio-quality 0 `
        --ffmpeg-location $toolDirectory --paths $destination --output 'audio.%(ext)s' `
        --verbose *> $log
      $downloadExitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = 'Stop' }
    if ($downloadExitCode -ne 0) {
      Get-Content -LiteralPath $log
      throw "yt-dlp integration failed: $($case.Name)"
    }
    $mp3 = Join-Path $destination 'audio.mp3'
    if (-not (Test-Path -LiteralPath $mp3) -or (Get-Item $mp3).Length -eq 0) {
      throw "Missing MP3: $($case.Name)"
    }
    $pcm = Join-Path $destination 'decoded.pcm'
    Invoke-Reference @('-i', $mp3, '-map', '0:a:0', '-ar', '48000', '-ac', '1', '-f', 's16le', $pcm)
    # Two seconds of mono PCM16 at 48 kHz, allowing codec delay/padding.
    $decodedBytes = (Get-Item $pcm).Length
    if ($decodedBytes -lt 180000 -or $decodedBytes -gt 210000) {
      throw "Unexpected decoded duration: $($case.Name) ($decodedBytes bytes)"
    }
    Write-Host "PASS $($case.Name): MP3 conversion without ffprobe"
  }
  Write-Host "All $($cases.Count) cases passed. Logs and fixtures: $testRoot"
}
finally {
  if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force }
}
