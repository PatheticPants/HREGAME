# Sweep the play harness across reading speeds and print the one number that
# matters: candle remaining at the start of each day's last matter.
#
# The whole point is that "is the day tight" has no single answer -- it is a
# curve against reading speed, and a retune judged at one point on that curve is
# how you get a change that is exactly wrong for everybody except the imaginary
# player you measured.
#
#   powershell -File tools/sweep_pacing.ps1
#   powershell -File tools/sweep_pacing.ps1 -Dwells "0,8,16" -Tag after
#
# Dwells is a COMMA STRING, not an array. `powershell -File script -Dwells
# 0,8,16,24` binds the four values to one [int[]] parameter as the single
# integer 81624, runs one nonsense sweep, and reports nothing wrong.
#
# Writes .tools/sweep_<tag>.txt and prints a table.

param(
    [string]$Dwells = "0,4,8,16,24",
    [string]$Tag = "now"
)

$DwellList = @($Dwells -split ',' | ForEach-Object { [int]$_.Trim() })

$godot = ".tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe"
if (-not (Test-Path $godot)) { throw "godot not found at $godot" }

$out = ".tools/sweep_$Tag.txt"
"pacing sweep [$Tag]" | Out-File -Encoding utf8 $out

$rows = @()
foreach ($d in $DwellList) {
    Write-Host "  dwell $d ..."
    $log = ".tools/sweep_${Tag}_d$d.jsonl"
    $raw = & $godot --path . --resolution 1600x900 --fixed-fps 60 `
        --scene res://tests/play_day.tscn --session-log=$log --dwell=$d 2>$null
    $raw | Out-File -Encoding utf8 -Append $out

    # One row per day, read out of the harness's own summary block.
    $day = ""
    foreach ($line in $raw) {
        if ($line -match '^(TUESDAY|THURSDAY|SATURDAY)\s') { $day = $Matches[1] }
        if ($line -match 'total deliberation\s+([\d.]+) s of ([\d.]+) s\s+\(burn ([\d.]+)\)') {
            $rows += [pscustomobject]@{
                dwell = $d; day = $day
                spent = [double]$Matches[1]; issued = [double]$Matches[2]
                burn  = [double]$Matches[3]; last = $null; ended = "finished"
            }
        }
        if ($line -match 'CANDLE AT THE START OF THE LAST MATTER: ([\d.]+)%') {
            if ($rows.Count) { $rows[-1].last = [double]$Matches[1] }
        }
        if ($line -match 'BURNT OUT|burnt out|drowned') {
            if ($rows.Count) { $rows[-1].ended = "burnt out" }
        }
    }
    Write-Host " done"
}

Write-Host ""
$rows | Format-Table @{l = 'dwell'; e = { $_.dwell } },
    @{l = 'day'; e = { $_.day } },
    @{l = 'issued'; e = { '{0:N0} s' -f $_.issued } },
    @{l = 'spent'; e = { '{0:N0} s' -f $_.spent } },
    @{l = 'burn'; e = { '{0:N2}' -f $_.burn } },
    @{l = 'last matter starts at'; e = { if ($null -ne $_.last) { '{0:N1}%' -f $_.last } else { '-' } } },
    @{l = 'ended'; e = { $_.ended } } -AutoSize

"full transcripts in $out"
