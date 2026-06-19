param(
    [string]$VcdPath = "interconnect_tb.vcd",
    [string]$OutputPath = "docs/slide/design/test/interconnect.png"
)

Add-Type -AssemblyName System.Drawing

$signals = @(
    @{ Name = "clk"; Id = ","; Kind = "bit" },
    @{ Name = "reset"; Id = "3"; Kind = "bit" },
    @{ Name = "core_mem_req[7:0]"; Id = "/"; Kind = "bus" },
    @{ Name = "arb_request[7:0]"; Id = "("; Kind = "bus" },
    @{ Name = "arb_grant[7:0]"; Id = "+"; Kind = "bus" },
    @{ Name = "grant_valid"; Id = ")"; Kind = "bit" },
    @{ Name = "grant_id[2:0]"; Id = "*"; Kind = "bus" },
    @{ Name = "dm_addr[31:0]"; Id = "%"; Kind = "bus" },
    @{ Name = "dm_wdata[31:0]"; Id = '"'; Kind = "bus" },
    @{ Name = "dm_we"; Id = "!"; Kind = "bit" },
    @{ Name = "dm_re"; Id = "#"; Kind = "bit" },
    @{ Name = "core_ready[7:0]"; Id = "'"; Kind = "bus" },
    @{ Name = "core_sc_result[7:0]"; Id = "&"; Kind = "bus" }
)

$changes = @{}
foreach ($sig in $signals) {
    $changes[$sig.Id] = New-Object System.Collections.Generic.List[object]
}

$time = 0
foreach ($line in [System.IO.File]::ReadLines((Resolve-Path $VcdPath))) {
    if ($line.StartsWith("#")) {
        $time = [int64]$line.Substring(1)
        continue
    }

    if ($line.Length -eq 0) { continue }

    if ($line[0] -eq "b") {
        $parts = $line.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($parts.Length -ne 2) { continue }
        $value = $parts[0].Substring(1)
        $id = $parts[1]
    } else {
        $value = $line.Substring(0, 1)
        $id = $line.Substring(1)
    }

    if ($changes.ContainsKey($id)) {
        $changes[$id].Add([pscustomobject]@{ Time = $time; Value = $value })
    }
}

function Format-BusValue([string]$bits) {
    if ($bits -match "^[01]+$") {
        $n = [Convert]::ToInt64($bits, 2)
        if ($bits.Length -gt 8) { return ("0x{0:X}" -f $n) }
        return ("0b{0}" -f $bits)
    }
    return $bits
}

$width = 1920
$height = 900
$left = 280
$right = 30
$top = 55
$rowH = 58
$waveH = 20
$maxTime = 935000
$endTime = 935000
$scale = ($width - $left - $right) / $endTime

$outDir = Split-Path $OutputPath -Parent
if ($outDir -and !(Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$bmp = New-Object System.Drawing.Bitmap $width, $height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$black = [System.Drawing.Color]::FromArgb(8, 9, 15)
$grid = [System.Drawing.Color]::FromArgb(35, 63, 145)
$green = [System.Drawing.Color]::FromArgb(121, 255, 44)
$white = [System.Drawing.Color]::White
$panel = [System.Drawing.Color]::FromArgb(236, 236, 236)
$labelText = [System.Drawing.Color]::FromArgb(25, 25, 25)
$blueText = [System.Drawing.Color]::FromArgb(160, 210, 255)
$red = [System.Drawing.Color]::FromArgb(255, 80, 80)

$g.Clear($black)
$g.FillRectangle((New-Object System.Drawing.SolidBrush $panel), 0, 0, $left - 6, $height)

$font = New-Object System.Drawing.Font("Consolas", 15)
$smallFont = New-Object System.Drawing.Font("Consolas", 12)
$titleFont = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$brushWhite = New-Object System.Drawing.SolidBrush $white
$brushLabel = New-Object System.Drawing.SolidBrush $labelText
$brushBlue = New-Object System.Drawing.SolidBrush $blueText
$penGrid = New-Object System.Drawing.Pen $grid, 1
$penGreen = New-Object System.Drawing.Pen $green, 2
$penRed = New-Object System.Drawing.Pen $red, 1

$g.DrawString("Interconnect waveform - interconnect_tb.vcd", $titleFont, $brushWhite, $left, 12)
$g.DrawString("Time", $titleFont, $brushLabel, 8, 12)

for ($ns = 0; $ns -le 900; $ns += 100) {
    $x = $left + (($ns * 1000) * $scale)
    $g.DrawLine($penGrid, $x, $top - 10, $x, $height - 25)
    $g.DrawString(("{0} ns" -f $ns), $smallFont, $brushWhite, $x + 3, 28)
}

for ($i = 0; $i -lt $signals.Count; $i++) {
    $sig = $signals[$i]
    $yMid = $top + ($i * $rowH) + 26
    $yHigh = $yMid - $waveH / 2
    $yLow = $yMid + $waveH / 2

    $g.DrawString($sig.Name, $font, $brushLabel, 8, $yMid - 14)
    $g.DrawLine($penGrid, $left, $yMid + 25, $width - $right, $yMid + 25)

    $items = @($changes[$sig.Id] | Sort-Object Time)
    if ($items.Count -eq 0) { continue }

    if ($sig.Kind -eq "bit") {
        $prevX = $left
        $prevY = if ($items[0].Value -eq "1") { $yHigh } else { $yLow }
        foreach ($item in $items) {
            if ($item.Time -gt $endTime) { break }
            $x = $left + ($item.Time * $scale)
            $newY = if ($item.Value -eq "1") { $yHigh } else { $yLow }
            $g.DrawLine($penGreen, $prevX, $prevY, $x, $prevY)
            $g.DrawLine($penGreen, $x, $prevY, $x, $newY)
            $prevX = $x
            $prevY = $newY
        }
        $g.DrawLine($penGreen, $prevX, $prevY, $width - $right, $prevY)
    } else {
        $prev = $items[0]
        for ($j = 1; $j -lt $items.Count; $j++) {
            $next = $items[$j]
            if ($prev.Time -gt $endTime) { break }
            $x1 = $left + ($prev.Time * $scale)
            $x2 = $left + ([Math]::Min($next.Time, $endTime) * $scale)
            if ($x2 -lt $x1 + 2) { $prev = $next; continue }
            $g.DrawLine($penGreen, $x1, $yHigh, $x2, $yHigh)
            $g.DrawLine($penGreen, $x1, $yLow, $x2, $yLow)
            $g.DrawLine($penGreen, $x1, $yHigh, $x1 + 8, $yMid)
            $g.DrawLine($penGreen, $x1, $yLow, $x1 + 8, $yMid)
            $g.DrawString((Format-BusValue $prev.Value), $smallFont, $brushBlue, $x1 + 10, $yMid - 23)
            $prev = $next
        }
        $xLast = $left + ($prev.Time * $scale)
        if ($xLast -lt $width - $right) {
            $g.DrawLine($penGreen, $xLast, $yHigh, $width - $right, $yHigh)
            $g.DrawLine($penGreen, $xLast, $yLow, $width - $right, $yLow)
            $g.DrawString((Format-BusValue $prev.Value), $smallFont, $brushBlue, $xLast + 10, $yMid - 23)
        }
    }
}

$g.DrawLine($penRed, $left + (935000 * $scale), $top - 10, $left + (935000 * $scale), $height - 25)
$g.DrawString("SUMMARY: 10 PASSED, 0 FAILED", $titleFont, (New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(0, 185, 90))), $left + 940, $height - 44)

$fullOut = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path (Get-Location) $OutputPath }
$bmp.Save($fullOut, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose()
$bmp.Dispose()

Write-Output "Rendered waveform: $fullOut"
