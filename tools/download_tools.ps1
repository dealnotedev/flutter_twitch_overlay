[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$toolDirectory = $PSScriptRoot
$temporaryDirectory = Join-Path `
  ([System.IO.Path]::GetTempPath()) `
  ("obssource-tools-" + [System.Guid]::NewGuid().ToString('N'))

function Download-File {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  Write-Host "Downloading $Uri"
  Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing
}

function Assert-Sha256 {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Expected
  )

  $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
  if ($actual -ne $Expected.Trim().ToUpperInvariant()) {
    throw "SHA256 mismatch for $Path. Expected $Expected, got $actual"
  }
}

function Read-Sha256 {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  $match = [System.Text.RegularExpressions.Regex]::Match(
    (Get-Content -LiteralPath $Path -Raw),
    '(?i)[a-f0-9]{64}'
  )
  if (-not $match.Success) {
    throw "SHA256 value was not found in $Path"
  }
  return $match.Value
}

New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null

try {
  $ytDlpPath = Join-Path $toolDirectory 'yt-dlp.exe'
  $ytDlpSums = Join-Path $temporaryDirectory 'yt-dlp-SHA2-256SUMS'
  Download-File `
    -Uri 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' `
    -Destination $ytDlpPath
  Download-File `
    -Uri 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS' `
    -Destination $ytDlpSums
  $ytDlpChecksumLine = Get-Content -LiteralPath $ytDlpSums |
    Where-Object { $_ -match '\syt-dlp\.exe$' } |
    Select-Object -First 1
  if ($null -eq $ytDlpChecksumLine) {
    throw 'yt-dlp checksum was not found in SHA2-256SUMS'
  }
  Assert-Sha256 `
    -Path $ytDlpPath `
    -Expected ($ytDlpChecksumLine -split '\s+')[0]

  $denoArchive = Join-Path $temporaryDirectory 'deno.zip'
  $denoChecksum = Join-Path $temporaryDirectory 'deno.zip.sha256sum'
  Download-File `
    -Uri 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' `
    -Destination $denoArchive
  Download-File `
    -Uri 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip.sha256sum' `
    -Destination $denoChecksum
  Assert-Sha256 `
    -Path $denoArchive `
    -Expected (Read-Sha256 -Path $denoChecksum)
  $denoExtractDirectory = Join-Path $temporaryDirectory 'deno'
  Expand-Archive -LiteralPath $denoArchive -DestinationPath $denoExtractDirectory
  Copy-Item `
    -LiteralPath (Join-Path $denoExtractDirectory 'deno.exe') `
    -Destination (Join-Path $toolDirectory 'deno.exe') `
    -Force

  $ffmpegArchive = Join-Path $temporaryDirectory 'ffmpeg.zip'
  $ffmpegChecksum = Join-Path $temporaryDirectory 'ffmpeg.zip.sha256'
  Download-File `
    -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' `
    -Destination $ffmpegArchive
  Download-File `
    -Uri 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip.sha256' `
    -Destination $ffmpegChecksum
  Assert-Sha256 `
    -Path $ffmpegArchive `
    -Expected (Read-Sha256 -Path $ffmpegChecksum)
  $ffmpegExtractDirectory = Join-Path $temporaryDirectory 'ffmpeg'
  Expand-Archive -LiteralPath $ffmpegArchive -DestinationPath $ffmpegExtractDirectory

  foreach ($executable in 'ffmpeg.exe', 'ffprobe.exe') {
    $source = Get-ChildItem `
      -LiteralPath $ffmpegExtractDirectory `
      -Filter $executable `
      -File `
      -Recurse |
      Select-Object -First 1
    if ($null -eq $source) {
      throw "$executable was not found in the FFmpeg archive"
    }
    Copy-Item `
      -LiteralPath $source.FullName `
      -Destination (Join-Path $toolDirectory $executable) `
      -Force
  }

  Write-Host 'Tools downloaded and checksums verified.'
}
finally {
  if (Test-Path -LiteralPath $temporaryDirectory) {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
  }
}
