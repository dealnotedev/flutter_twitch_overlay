[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$workDirectory = Join-Path (Split-Path $PSScriptRoot -Parent) 'build\ffmpeg-minimal'
New-Item -ItemType Directory -Force -Path $workDirectory | Out-Null

function Get-VerifiedArchive {
  param([string]$Uri, [string]$Name, [string]$Sha256)
  $archive = Join-Path $workDirectory $Name
  if (-not (Test-Path -LiteralPath $archive)) {
    Write-Host "Downloading $Uri"
    Invoke-WebRequest -Uri $Uri -OutFile $archive -UseBasicParsing
  }
  if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $Sha256) {
    throw "SHA256 mismatch: $archive. Remove the invalid cached archive and retry."
  }
  return $archive
}

function Expand-SourceArchive {
  param([string]$Archive)
  & tar.exe -xf $Archive -C $workDirectory
  if ($LASTEXITCODE -ne 0) { throw "Cannot extract $Archive" }
}

# The complete build environment stays in build/, with no system installation
# or persistent PATH changes. Only the finished runtime files go into tools/.
$bash = Join-Path $workDirectory 'msys64\usr\bin\bash.exe'
if (-not (Test-Path -LiteralPath $bash)) {
  $archive = Get-VerifiedArchive `
    -Uri 'https://github.com/msys2/msys2-installer/releases/download/2026-09-27/msys2-base-x86_64-20260927.tar.xz' `
    -Name 'msys2-base-x86_64-20260927.tar.xz' `
    -Sha256 'ea2f31a0b6ade63914ce441ffb022f0f6aa96982bfefa2326460a26d5fb01322'
  Expand-SourceArchive $archive
}

$sourceArchive = Get-VerifiedArchive `
  -Uri 'https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz' `
  -Name 'ffmpeg-9.0.2.tar.xz' `
  -Sha256 '8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e'
$sourceDirectory = Join-Path $workDirectory 'ffmpeg-9.0.2'
if (-not (Test-Path -LiteralPath (Join-Path $sourceDirectory 'configure'))) {
  Expand-SourceArchive $sourceArchive
}

$previousMsystem = $env:MSYSTEM
$previousChereInvoking = $env:CHERE_INVOKING
try {
  $env:MSYSTEM = 'UCRT64'
  $env:CHERE_INVOKING = '1'
  # FFmpeg's configure needs cmp (diffutils) in addition to make and GCC.
  $dependencies = @('ucrt64\bin\gcc.exe', 'usr\bin\make.exe', 'ucrt64\bin\pkg-config.exe', 'ucrt64\bin\nasm.exe', 'usr\bin\cmp.exe', 'ucrt64\lib\libmp3lame.a')
  $missing = @($dependencies | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $workDirectory "msys64\$_"))
  })
  if ($missing.Count -gt 0) {
    & $bash -lc 'pacman -Syu --noconfirm'
    if ($LASTEXITCODE -ne 0) { throw 'MSYS2 update failed; rerun after its core update.' }
    & $bash -lc 'pacman -S --noconfirm --needed make diffutils mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-pkgconf mingw-w64-ucrt-x86_64-nasm mingw-w64-ucrt-x86_64-lame'
    if ($LASTEXITCODE -ne 0) { throw 'MSYS2 build dependency installation failed.' }
  }

  $outputDirectory = Join-Path $workDirectory 'output'
  $compileDirectory = Join-Path $workDirectory 'compile'
  $script = Join-Path $PSScriptRoot 'build_ffmpeg.sh'
  & $bash -lc 'exec bash "$@"' build-ffmpeg $script $sourceDirectory $compileDirectory $outputDirectory
  if ($LASTEXITCODE -ne 0) { throw 'Minimal FFmpeg build failed.' }

  $ffmpeg = Join-Path $outputDirectory 'ffmpeg.exe'
  & $ffmpeg -version
  if ($LASTEXITCODE -ne 0) { throw 'The built FFmpeg cannot run on this machine.' }
  foreach ($name in 'ffmpeg.exe', 'FFmpeg-LICENSE.txt', 'LAME-LICENSE.txt', 'ffmpeg-build.txt') {
    Copy-Item -LiteralPath (Join-Path $outputDirectory $name) -Destination $PSScriptRoot -Force
  }
  # Remove only the obsolete bundled executable, never system/PATH tools.
  $obsoleteProbe = Join-Path $PSScriptRoot 'ffprobe.exe'
  if (Test-Path -LiteralPath $obsoleteProbe) {
    Remove-Item -LiteralPath $obsoleteProbe -Force
  }
  Write-Host ('Minimal FFmpeg installed: {0:N2} MiB (no ffprobe).' -f ((Get-Item $ffmpeg).Length / 1MB))
}
finally {
  $env:MSYSTEM = $previousMsystem
  $env:CHERE_INVOKING = $previousChereInvoking
}
