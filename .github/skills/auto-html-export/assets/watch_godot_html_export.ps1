param(
    [int]$DebounceMs = 1200,
    [switch]$RunInitialExport
)

$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$GodotRoot = Join-Path $RepoRoot "godot"
$ExportScript = Join-Path $RepoRoot "scripts\launch_godot.ps1"

if (-not (Test-Path $GodotRoot)) {
    throw "Godot folder not found: $GodotRoot"
}
if (-not (Test-Path $ExportScript)) {
    throw "Export script not found: $ExportScript"
}

$script:IsExporting = $false
$script:PendingAfterExport = $false
$script:PendingReason = ""

function Get-RelativeGodotPath {
    param([string]$FullPath)

    $prefix = "$GodotRoot\"
    if ($FullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $FullPath.Substring($prefix.Length)
    }
    return $FullPath
}

function Test-RelevantPath {
    param([string]$RelativePath)

    $normalized = $RelativePath.Replace("/", "\")

    if ($normalized.StartsWith("build\web\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    if ($normalized.StartsWith(".godot\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    if ($normalized.EndsWith(".import", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }

    if ($normalized.StartsWith("scenes\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    if ($normalized.StartsWith("scripts\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    if ($normalized.StartsWith("assets\textures\", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $importantFiles = @(
        "project.godot",
        "export_presets.cfg",
        "custom_html_shell.html"
    )

    foreach ($name in $importantFiles) {
        if ($normalized.Equals($name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Invoke-Export {
    param([string]$Reason)

    if ($script:IsExporting) {
        $script:PendingAfterExport = $true
        return
    }

    $script:IsExporting = $true
    try {
        Write-Host ""
        Write-Host "==> Auto export triggered: $Reason" -ForegroundColor Cyan
        & powershell -NoProfile -ExecutionPolicy Bypass -File $ExportScript -Mode export -SkipSmoke
        if ($LASTEXITCODE -ne 0) {
            throw "Export command failed with exit code $LASTEXITCODE"
        }
        Write-Host "==> Auto export complete" -ForegroundColor Green
    }
    catch {
        Write-Host "==> Auto export failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
        $script:IsExporting = $false
    }

    if ($script:PendingAfterExport) {
        $script:PendingAfterExport = $false
        Invoke-Export -Reason "queued changes during previous export"
    }
}

$debounceTimer = New-Object System.Timers.Timer
$debounceTimer.Interval = [Math]::Max($DebounceMs, 250)
$debounceTimer.AutoReset = $false

Register-ObjectEvent -InputObject $debounceTimer -EventName Elapsed -SourceIdentifier "wahoo-html-export-timer" -Action {
    $reason = $script:PendingReason
    $script:PendingReason = ""
    Invoke-Export -Reason $reason
} | Out-Null

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $GodotRoot
$watcher.Filter = "*"
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor
    [System.IO.NotifyFilters]::DirectoryName -bor
    [System.IO.NotifyFilters]::LastWrite

$handleChange = {
    $fullPath = $Event.SourceEventArgs.FullPath
    $relativePath = Get-RelativeGodotPath -FullPath $fullPath

    if (-not (Test-RelevantPath -RelativePath $relativePath)) {
        return
    }

    $changeType = $Event.SourceEventArgs.ChangeType
    $script:PendingReason = "$changeType $relativePath"

    Write-Host "Queued export: $changeType $relativePath"
    $debounceTimer.Stop()
    $debounceTimer.Start()
}

Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier "wahoo-html-export-changed" -Action $handleChange | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier "wahoo-html-export-created" -Action $handleChange | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Deleted -SourceIdentifier "wahoo-html-export-deleted" -Action $handleChange | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier "wahoo-html-export-renamed" -Action $handleChange | Out-Null

$watcher.EnableRaisingEvents = $true

Write-Host "Watching Godot files for web export sync..." -ForegroundColor Yellow
Write-Host "Repo root: $RepoRoot"
Write-Host "Godot root: $GodotRoot"
Write-Host "Debounce: $($debounceTimer.Interval) ms"
Write-Host "Press Ctrl+C to stop."

if ($RunInitialExport) {
    Invoke-Export -Reason "initial run"
}

try {
    while ($true) {
        Wait-Event -Timeout 1 | Out-Null
    }
}
finally {
    $watcher.EnableRaisingEvents = $false
    $debounceTimer.Stop()

    Unregister-Event -SourceIdentifier "wahoo-html-export-timer" -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier "wahoo-html-export-changed" -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier "wahoo-html-export-created" -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier "wahoo-html-export-deleted" -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier "wahoo-html-export-renamed" -ErrorAction SilentlyContinue

    $watcher.Dispose()
    $debounceTimer.Dispose()
}