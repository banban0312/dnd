param(
    [string]$GodotPath = $env:GODOT_BIN,
    [switch]$SmokeTest,
    [switch]$Compatibility
)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
if (-not $GodotPath) {
    $godotCommand = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($godotCommand) { $GodotPath = $godotCommand.Source }
}
if (-not $GodotPath) {
    $GodotPath = Get-ChildItem -LiteralPath 'D:\Godot' -Filter '*console.exe' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot not found. Run .\start-test.ps1 -GodotPath "C:\path\to\Godot.exe", or open project.godot with Godot 4.7 and press F5.'
}
$gameArgs = @('--path', $projectRoot)
if ($Compatibility) { $gameArgs += @('--rendering-method', 'gl_compatibility') }
if ($SmokeTest) { $gameArgs += @('--headless', '--quit-after', '600') }
$gameArgs += 'res://mvp.tscn'
if ($SmokeTest) { $gameArgs += @('--', '--smoke') }
if ($SmokeTest) {
    $testOutput = & $GodotPath @gameArgs 2>&1
    $testExitCode = $LASTEXITCODE
    $testOutput | ForEach-Object { Write-Output $_ }
    $testLog = $testOutput -join "`n"
    if ($testExitCode -ne 0 -or $testLog -notmatch 'MVP smoke OK' -or $testLog -match 'SCRIPT ERROR:|(?m)^ERROR:') {
        throw 'MVP smoke test failed; inspect the output above.'
    }
} else {
    & $GodotPath @gameArgs
}
if ($LASTEXITCODE -ne 0) { throw "Godot exited with code $LASTEXITCODE" }
