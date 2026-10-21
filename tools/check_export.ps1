param(
    [string]$GodotExe = 'D:\Godot\Godot_v4.7.1-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputRoot = Join-Path $projectRoot '_test'
$buildRoot = Join-Path $outputRoot 'build'
$oldAppData = $env:APPDATA
$oldTemp = $env:TEMP
$oldTmp = $env:TMP
try {
    # Keep editor settings, saves and export scratch files inside the workspace.
    $env:APPDATA = Join-Path $outputRoot 'export-user'
    $env:TEMP = Join-Path $outputRoot 'export-temp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Path $buildRoot, $env:APPDATA, $env:TEMP -Force | Out-Null
    & $GodotExe --headless --path $projectRoot --rendering-method gl_compatibility --log-file "$outputRoot/export-preflight.log" --script res://tools/test_export_preflight.gd
    if ($LASTEXITCODE -ne 0) { throw 'Imported title resource preflight failed.' }

    $pack = Join-Path $buildRoot 'deeper-and-deeper.pck'
    $packLog = Join-Path $outputRoot 'pack-export-console.log'
    $exportStarted = Get-Date
    # Windows PowerShell 5 turns native stderr into ErrorRecord objects.
    # Capture it first, then apply the explicit exit/log/fresh-file checks below.
    try {
        $ErrorActionPreference = 'Continue'
        $exportOutput = & $GodotExe --headless --path $projectRoot --rendering-method gl_compatibility --log-file "$outputRoot/pack-export.log" --export-pack 'Windows Desktop' $pack 2>&1
        $exportExit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = 'Stop' }
    $exportOutput | ForEach-Object { $_.ToString() } | Set-Content -LiteralPath $packLog -Encoding utf8
    $packErrors = @(Select-String -LiteralPath $packLog -Pattern '^ERROR:|SCRIPT ERROR:')
    $unexpectedErrors = @($packErrors | Where-Object { $_.Line -notmatch '^ERROR: Safe save failed\.' })
    if ($packErrors.Count -gt $unexpectedErrors.Count) {
        Write-Warning "Godot editor reported a safe-save error in this sandbox. Retaining $packLog; validating the fresh PCK separately."
    }
    if ($exportExit -ne 0 -or $unexpectedErrors.Count -gt 0 -or -not (Test-Path -LiteralPath $pack) -or (Get-Item -LiteralPath $pack).LastWriteTime -lt $exportStarted) {
        throw "PCK export failed. See $packLog"
    }
    & $GodotExe --headless --main-pack $pack --rendering-method gl_compatibility --log-file "$outputRoot/pack-smoke.log" --quit-after 600 -- --smoke
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath "$outputRoot/pack-smoke.log" -Pattern '^ERROR:|SCRIPT ERROR:' -Quiet) -or -not (Select-String -LiteralPath "$outputRoot/pack-smoke.log" -Pattern 'MVP smoke OK' -Quiet)) {
        throw 'PCK game flow smoke failed. See _test/pack-smoke.log.'
    }
    Write-Output "PCK export and host headless game flow passed: $pack"
    Write-Output 'This does not verify native rendering, human gameplay balance, an independent Windows EXE, or a clean machine.'

}
finally {
    $env:APPDATA = $oldAppData
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
}
