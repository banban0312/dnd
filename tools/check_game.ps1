param([string]$GodotPath = 'D:\Godot\Godot_v4.7.1-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $projectRoot '_test'
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path $testRoot 'appdata'
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    $cases = @(
        @{ Name = 'controls'; Tail = @('--script', 'res://tools/test_mvp_controls.gd'); Marker = 'MVP CONTROLS' },
        @{ Name = 'contact-escape'; Tail = @('--script', 'res://tools/test_mvp_contact_escape.gd'); Marker = 'MVP CONTACT ESCAPE OK' },
        @{ Name = 'warden-hitbox'; Tail = @('--script', 'res://tools/test_mvp_warden_hitbox.gd'); Marker = 'WARDEN HITBOX OK' },
        @{ Name = 'v05-combat'; Tail = @('--script', 'res://tools/test_mvp_v05.gd'); Marker = 'MVP V05 COMBAT OK' },
        @{ Name = 'special-enemies'; Tail = @('--script', 'res://tools/test_mvp_special_enemy.gd'); Marker = 'MVP SPECIAL ENEMY OK' },
        @{ Name = 'necromancer'; Tail = @('--script', 'res://tools/test_mvp_necromancer.gd'); Marker = 'NECROMANCER OK' },
        @{ Name = 'music'; Tail = @('--script', 'res://tools/test_mvp_music.gd'); Marker = 'MVP MUSIC OK' },
        @{ Name = 'flow'; Tail = @('--', '--smoke'); Marker = 'MVP smoke OK' },
        @{ Name = 'equipment'; Tail = @('--script', 'res://tools/test_mvp_equipment.gd'); Marker = 'MVP equipment checks OK' },
        @{ Name = 'baseline'; Tail = @('--script', 'res://tools/test_combat_baseline.gd'); Marker = 'COMBAT BASELINE OK' },
        @{ Name = 'layout'; Tail = @('--script', 'res://tools/test_mvp_layout.gd'); Marker = 'MVP LAYOUT OK' },
        @{ Name = 'contract'; Tail = @('--script', 'res://tools/test_mvp_contract.gd'); Marker = 'MVP CONTRACT OK' },
        @{ Name = 'boss'; Tail = @('--script', 'res://tools/test_mvp_boss_dash.gd'); Marker = 'MVP BOSS DASH OK' },
        @{ Name = 'legacy'; Tail = @('res://tools/test_startup.tscn'); Marker = 'Startup smoke OK' }
    )
    foreach ($case in $cases) {
        $log = Join-Path $testRoot ($case.Name + '-suite.log')
        # Detailed physical contact/hitbox matrices need more ticks than short smokes.
        $frameLimit = if ($case.Name -in @('contact-escape', 'warden-hitbox')) { '12000' } else { '2400' }
        $engineArgs = @('--headless', '--path', $projectRoot, '--log-file', $log, '--quit-after', $frameLimit) + $case.Tail
        $output = & $GodotPath @engineArgs 2>&1
        $exitCode = $LASTEXITCODE
        $textLog = $output -join "`n"
        if ($exitCode -ne 0 -or $textLog -match 'SCRIPT ERROR:|(?m)^ERROR:|FAIL:' -or $textLog -notmatch [regex]::Escape($case.Marker)) {
            $output | ForEach-Object { Write-Output $_ }
            throw "Regression failed: $($case.Name). See $log"
        }
        Write-Output "PASS $($case.Name): $($case.Marker)"
    }
    Write-Output 'Game regression passed: 14 suites. Human playtest and clean-machine export remain separate gates.'
}
finally { $env:APPDATA = $previousAppData }
