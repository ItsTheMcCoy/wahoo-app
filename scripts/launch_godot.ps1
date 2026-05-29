param(
    [ValidateSet("game", "editor", "web", "export", "smoke")]
    [string]$Mode = "game",

    [switch]$SkipSmoke,

    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$GodotDir = Join-Path $RepoRoot "godot"
$WebDir = Join-Path $GodotDir "build\web"
$ExportPath = Join-Path $WebDir "index.html"
$GodotExe = "Godot_v4.6.3-stable_win64_console.exe"
$GodotFallback = "C:\Users\macwe\OneDrive\Documents\Gdot4\Godot_v4.6.3-stable_win64_console.exe"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Description
    )
    if (-not (Test-Path $Path)) {
        throw "$Description not found: $Path"
    }
}

function Run-Godot {
    param([string[]]$GodotArgs)
    Push-Location $GodotDir
    try {
        & $GodotExe @GodotArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Godot exited with code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

Assert-PathExists $GodotDir "Godot project folder"
Assert-PathExists (Join-Path $GodotDir "project.godot") "Godot project file"

$GodotCommand = Get-Command $GodotExe -ErrorAction SilentlyContinue
if ($GodotCommand) {
    $GodotExe = $GodotCommand.Source
}
elseif (Test-Path $GodotFallback) {
    $GodotExe = $GodotFallback
}
else {
    throw "Godot 4.6.3 was not found. Add the Godot 4.6.3 folder to PATH or edit this script's `$GodotFallback value."
}

if (-not $SkipSmoke -and $Mode -ne "editor") {
    Write-Step "Running Godot smoke tests from $GodotDir"
    Run-Godot -GodotArgs @("--headless", "--script", "res://scripts/run_smoke.gd")
}

switch ($Mode) {
    "smoke" {
        if ($SkipSmoke) {
            Write-Step "Running Godot smoke tests from $GodotDir"
            Run-Godot -GodotArgs @("--headless", "--script", "res://scripts/run_smoke.gd")
        }
    }
    "export" {
        Write-Step "Exporting Web build from $GodotDir"
        Run-Godot -GodotArgs @("--headless", "--path", ".", "--export-release", "Web", "build/web/index.html")
        Write-Host "Export written to $ExportPath"
    }
    "web" {
        Write-Step "Exporting Web build from $GodotDir"
        Run-Godot -GodotArgs @("--headless", "--path", ".", "--export-release", "Web", "build/web/index.html")

        Write-Step "Serving Web build from $WebDir"
        Assert-PathExists $ExportPath "Web export"
        Push-Location $WebDir
        try {
            Write-Host "Open http://localhost:$Port in your browser."
            python -m http.server $Port
        }
        finally {
            Pop-Location
        }
    }
    "editor" {
        Write-Step "Opening Godot editor from $GodotDir"
        Run-Godot -GodotArgs @("--path", ".", "--editor")
    }
    "game" {
        Write-Step "Launching Godot game from $GodotDir"
        Run-Godot -GodotArgs @("--path", ".")
    }
}
