#!/usr/bin/env bash
# Called by build_ffmpeg.ps1 inside its private MSYS2 UCRT64 environment.
set -euo pipefail

source_dir=$(cygpath -u "$1")
build_dir=$(cygpath -u "$2")
output_dir=$(cygpath -u "$3")
mkdir -p "$build_dir" "$output_dir"
cd "$build_dir"

# yt-dlp downloads media itself. FFmpeg only inspects local files, performs
# container fixups and converts YouTube AAC/Opus/Vorbis audio to MP3.
# Keep codec names/logging: yt-dlp parses `ffmpeg -i` without ffprobe.
"$source_dir/configure" \
  --target-os=mingw32 --arch=x86_64 \
  --disable-autodetect --disable-everything \
  --disable-shared --enable-static --enable-small --enable-lto \
  --disable-debug --disable-doc --disable-network \
  --disable-ffplay --disable-ffprobe --enable-ffmpeg \
  --disable-avdevice --disable-swscale \
  --enable-libmp3lame \
  --enable-decoder=aac,opus,vorbis,mp3float \
  --enable-encoder=libmp3lame,pcm_s16le \
  --enable-demuxer=aac,mov,matroska,mpegts,ogg,mp3 \
  --enable-muxer=mp3,mp4,ipod,matroska,webm,ogg,null \
  --enable-parser=aac,aac_latm,opus,vorbis,mpegaudio,h264,vp9,av1 \
  --enable-bsf=aac_adtstoasc,setts,extract_extradata \
  --enable-filter=aresample,aformat,anull,atrim,asetpts,asetnsamples,astats,ametadata \
  --enable-protocol=file,pipe \
  --pkg-config-flags=--static \
  --extra-cflags='-ffunction-sections -fdata-sections' \
  --extra-ldflags='-static -Wl,--gc-sections -Wl,--no-insert-timestamp'

make -j "${NUMBER_OF_PROCESSORS:-4}" ffmpeg.exe
strip --strip-all ffmpeg.exe
cp ffmpeg.exe "$output_dir/ffmpeg.exe"
cp "$source_dir/COPYING.LGPLv2.1" "$output_dir/FFmpeg-LICENSE.txt"
cp "$(dirname "$(realpath "$0")")/LAME-LICENSE.txt" "$output_dir/LAME-LICENSE.txt"
{
  ./ffmpeg.exe -version
  echo
  pacman -Q mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-lame
  echo
  echo 'FFmpeg source: https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz'
  echo 'SHA256: 8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e'
  echo 'LAME source/package recipe: https://github.com/msys2/MINGW-packages/tree/master/mingw-w64-lame'
} > "$output_dir/ffmpeg-build.txt"

# Static means no MSYS2/MinGW/LAME DLLs need to be shipped with the app.
objdump -p ffmpeg.exe | grep 'DLL Name:'
if objdump -p ffmpeg.exe | grep -Ei 'DLL Name:.*(msys|libgcc|libstdc|libwinpthread|libmp3lame)'; then
  echo 'Unexpected non-system DLL dependency' >&2
  exit 1
fi
