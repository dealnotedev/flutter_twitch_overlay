# Compares the landed-avatar frames saved by avatar_bench_host.exe --dump.
#
# powershell -File benchmark/avatar_rain/host/compare_dumps.ps1 -Dumps build/avatar_bench/dumps -Out build/avatar_bench/compare
#
# Expects sub-directories with the same BMP names (for example sw, ganesh,
# impeller). For every scenario it writes a side-by-side PNG of the avatar
# area and prints how many pixels differ from the first directory.
param(
    [Parameter(Mandatory = $true)][string]$Dumps,
    [Parameter(Mandatory = $true)][string]$Out,
    [string[]]$Variants = @('sw', 'ganesh', 'impeller'),
    # Avatar 256 x px 3 on 1920x1080 with the alert's vertical offset.
    [int]$X = 576, [int]$Y = 36, [int]$Size = 768
)

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class DumpCompare {
    public static int[] Read(Bitmap bitmap, Rectangle area) {
        var data = bitmap.LockBits(area, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var pixels = new int[area.Width * area.Height];
        for (int y = 0; y < area.Height; y++)
            Marshal.Copy(data.Scan0 + y * data.Stride, pixels, y * area.Width, area.Width);
        bitmap.UnlockBits(data);
        return pixels;
    }

    // Pixels whose channels differ by more than the tolerance.
    public static int Differences(int[] a, int[] b, int tolerance) {
        int count = 0;
        for (int i = 0; i < a.Length; i++) {
            if (a[i] == b[i]) continue;
            for (int shift = 0; shift < 32; shift += 8) {
                if (Math.Abs(((a[i] >> shift) & 0xFF) - ((b[i] >> shift) & 0xFF)) > tolerance) { count++; break; }
            }
        }
        return count;
    }
}
'@

New-Item -ItemType Directory -Force $Out | Out-Null
$area = New-Object System.Drawing.Rectangle $X, $Y, $Size, $Size
$names = Get-ChildItem (Join-Path $Dumps $Variants[0]) -Filter *.bmp | Select-Object -ExpandProperty BaseName
foreach ($name in $names) {
    $pixels = @{}
    $sheet = New-Object System.Drawing.Bitmap ($Size * $Variants.Count + 16 * ($Variants.Count + 1)), ($Size + 56)
    $graphics = [System.Drawing.Graphics]::FromImage($sheet)
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 16, 16, 18))
    $font = New-Object System.Drawing.Font 'Consolas', 16
    $line = "$name"
    for ($i = 0; $i -lt $Variants.Count; $i++) {
        $path = Join-Path (Join-Path $Dumps $Variants[$i]) "$name.bmp"
        if (-not (Test-Path $path)) { continue }
        $bitmap = New-Object System.Drawing.Bitmap $path
        $pixels[$Variants[$i]] = [DumpCompare]::Read($bitmap, $area)
        $left = 16 + $i * ($Size + 16)
        $graphics.DrawImage($bitmap, (New-Object System.Drawing.Rectangle $left, 40, $Size, $Size), $area, [System.Drawing.GraphicsUnit]::Pixel)
        $graphics.DrawString($Variants[$i], $font, [System.Drawing.Brushes]::White, $left, 8)
        $bitmap.Dispose()
        if ($i -gt 0 -and $pixels.ContainsKey($Variants[0])) {
            $exact = [DumpCompare]::Differences($pixels[$Variants[0]], $pixels[$Variants[$i]], 0)
            $loose = [DumpCompare]::Differences($pixels[$Variants[0]], $pixels[$Variants[$i]], 8)
            $line += " | $($Variants[$i]) differs from $($Variants[0]): $exact px (by more than 8 levels: $loose)"
        }
    }
    $graphics.Dispose()
    $sheet.Save((Join-Path $Out "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $sheet.Dispose()
    Write-Output $line
}
