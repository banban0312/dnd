param([string]$GodotPath = 'D:\Godot\Godot_v4.7.1-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path $projectRoot '_test'
$buildRoot = Join-Path $testRoot 'build'
$version = '0.6'
$releaseRoot = Join-Path $projectRoot ('releases/v' + $version)
$oldAppData = $env:APPDATA
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
try {
    $env:APPDATA = Join-Path $testRoot 'export-user'
    $env:TEMP = Join-Path $testRoot 'export-temp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Force -Path $buildRoot, $env:TEMP | Out-Null
    $template = Join-Path $env:APPDATA 'Godot\export_templates\4.7.1.stable\windows_release_x86_64.exe'
    if (-not (Test-Path -LiteralPath $template) -and $oldAppData) {
        $installedTemplate = Join-Path $oldAppData 'Godot\export_templates\4.7.1.stable\windows_release_x86_64.exe'
        if (Test-Path -LiteralPath $installedTemplate) {
            New-Item -ItemType Directory -Force -Path (Split-Path $template -Parent) | Out-Null
            Copy-Item -LiteralPath $installedTemplate -Destination $template
        }
    }
    if (-not (Test-Path -LiteralPath $template)) {
        throw "Install the official Godot 4.7.1 Windows release template at $template. The template is a build input and is not committed."
    }
    $exe = Join-Path $buildRoot 'deeper-and-deeper.exe'
    $exportLog = Join-Path $testRoot 'windows-export-console.log'
    $started = Get-Date
    try {
        $ErrorActionPreference = 'Continue'
        $exportOutput = & $GodotPath --headless --path $projectRoot --log-file "$testRoot/windows-export.log" --export-release 'Windows Desktop' $exe 2>&1
        $exportExit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = 'Stop' }
    $exportOutput | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $exportLog -Encoding utf8
    $errors = @(Select-String -LiteralPath $exportLog -Pattern '^ERROR:|SCRIPT ERROR:')
    $unexpected = @($errors | Where-Object { $_.Line -notmatch '^ERROR: Safe save failed\.' })
    if ($errors.Count -gt $unexpected.Count) { Write-Warning "Sandbox editor safe-save warning retained at $exportLog; validating fresh EXE separately." }
    if ($exportExit -ne 0 -or $unexpected.Count -gt 0 -or -not (Test-Path -LiteralPath $exe) -or (Get-Item -LiteralPath $exe).LastWriteTime -lt $started) {
        throw "Windows export failed. See $exportLog"
    }
    $smokeLog = Join-Path $testRoot 'windows-exe-smoke.log'
    $run = Start-Process -FilePath $exe -WorkingDirectory $buildRoot -ArgumentList @('--headless', '--log-file', $smokeLog, '--quit-after', '600', '--', '--smoke') -WindowStyle Hidden -PassThru -Wait
    if ($run.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $smokeLog) -or (Select-String -LiteralPath $smokeLog -Pattern '^ERROR:|SCRIPT ERROR:' -Quiet) -or -not (Select-String -LiteralPath $smokeLog -Pattern 'MVP smoke OK' -Quiet)) {
        throw "Independent EXE flow smoke failed. See $smokeLog"
    }
    $readme = Join-Path $buildRoot 'START_HERE.txt'
    @"
DEEPER AND DEEPER - Descent Playtest $version

Extract the entire ZIP and run deeper-and-deeper.exe.
Keep deeper-and-deeper.pck next to the EXE. No Godot installation is needed.

WASD: move and aim in EIGHT directions. Release to retain the last aim.
Mouse movement does not aim. Right click: block; Space: roll.
F: chest/lift; I: inventory/equipment; J: attack; K/L: skills; 1/2/3: potions; Esc: pause.
Choose a bow in the first chest, then equip it in inventory.
Floor one: the Warden becomes invulnerable at half health. Destroy ALL FOUR
flying stone pillars, defeat him, then extract, descend, or accept the pact.
Floor two: defeat the executioner, then choose the final descent.
Floor three: skeleton mage - rotating bone rain, delayed blooming flowers,
and summoned skeletons. At 2/3 and 1/3 health he raises his staff.
Enter the GOLD shelter completely within FOUR seconds to survive the blast.
The arena blast cannot be blocked or dodged outside the shelter.
New pixel enemies: shield guard (flank him), bone weaver, lantern wraith.
Attacked enemies keep aggro and ordinary enemies pursue across rooms.
Original medieval exploration music crossfades into electronic Boss music.
Pause menu: background music on/off; pausing lowers music automatically.

No mid-run save or permanent progression. Best score lasts for this session only.
This is a playtest. Human balance and clean-machine verification are pending.
"@ | Set-Content -LiteralPath $readme -Encoding utf8
    $pack = Join-Path $buildRoot 'deeper-and-deeper.pck'
    $credits = Join-Path $buildRoot 'CREDITS.md'
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\README.md') -Destination $credits -Force
    $musicCredits = Join-Path $buildRoot 'MUSIC_CREDITS.md'
    Copy-Item -LiteralPath (Join-Path $projectRoot 'assets\audio\README.md') -Destination $musicCredits -Force
    & $GodotPath --headless --path $projectRoot --log-file "$testRoot/engine-notices.log" --script res://tools/write_engine_notices.gd
    $notices = Join-Path $buildRoot 'GODOT_LICENSES.txt'
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $notices)) { throw 'Engine license notices were not produced.' }
    New-Item -ItemType Directory -Force -Path $releaseRoot | Out-Null
    $zip = Join-Path $releaseRoot ('deeper-and-deeper-windows-v' + $version + '.zip')
    Compress-Archive -LiteralPath $exe, $pack, $readme, $credits, $musicCredits, $notices -DestinationPath $zip -Force
    $manifestPath = Join-Path $projectRoot 'releases/manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json
    $entry = @($manifest.releases | Where-Object { $_.version -eq ('v' + $version) })
    if ($entry.Count -ne 1) { throw "Expected one release manifest entry for $version" }
    $entry[0].status = 'built'
    $entry[0].size_bytes = (Get-Item -LiteralPath $zip).Length
    $entry[0].sha256 = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Output "Windows EXE export and independent headless flow passed: $exe"
    Write-Output "Package: $zip. Native rendering and clean-machine verification remain separate gates."
}
finally {
    $env:APPDATA = $oldAppData
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
}
