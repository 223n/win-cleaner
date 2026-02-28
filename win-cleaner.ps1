#Requires -Version 5.1
using module .\modules\Core\ICleanerModule.psm1
using module .\modules\Core\CleanerEngine.psm1
using module .\modules\Core\Logger.psm1
using module .\modules\TempCleaner\TempCleaner.psm1
using module .\modules\RegistryCleaner\RegistryCleaner.psm1

param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot

Import-Module "$scriptRoot\modules\Core\PermissionChecker.psm1" -Force

function Read-Settings {
    $settingsPath = Join-Path $scriptRoot "config\settings.json"
    if (-not (Test-Path $settingsPath)) {
        throw "Settings file not found: $settingsPath"
    }
    $json = Get-Content -Path $settingsPath -Raw -Encoding UTF8
    return $json | ConvertFrom-Json | ConvertTo-Hashtable
}

function ConvertTo-Hashtable {
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $list = @()
        foreach ($item in $InputObject) {
            $list += (ConvertTo-Hashtable -InputObject $item)
        }
        return , $list
    }
    elseif ($InputObject -is [PSCustomObject]) {
        $hash = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $hash[$prop.Name] = ConvertTo-Hashtable -InputObject $prop.Value
        }
        return $hash
    }
    else {
        return $InputObject
    }
}

function Format-FileSize {
    param(
        [long]$Bytes
    )

    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Show-Banner {
    param(
        [bool]$IsDryRun
    )

    $mode = if ($IsDryRun) { " [DryRun]" } else { "" }
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Windows Cleaner v0.1.0$mode" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    param(
        [hashtable[]]$ModuleList
    )

    Write-Host "Available modules:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($m in $ModuleList) {
        $adminMark = if ($m.Admin) { " [Admin]" } else { "" }
        Write-Host "  $($m.Index). $($m.Name)$adminMark" -ForegroundColor White
        Write-Host "     $($m.Description)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "  0. Exit" -ForegroundColor White
    Write-Host ""
}

function Invoke-CleanerModule {
    param(
        [CleanerEngine]$Engine,
        [int]$ModuleIndex,
        [bool]$IsDryRun,
        [Logger]$Logger
    )

    $moduleInfo = $Engine.GetModuleList()[$ModuleIndex]

    if ($moduleInfo.Admin -and -not (Assert-AdminPrivilege -ModuleName $moduleInfo.Name)) {
        return
    }

    Write-Host "Analyzing with $($moduleInfo.Name)..." -ForegroundColor Yellow
    $Logger.Write("Start: $($moduleInfo.Name)")
    $items = $Engine.AnalyzeModule($ModuleIndex)

    if ($items.Count -eq 0) {
        Write-Host "No items found." -ForegroundColor Green
        $Logger.Write("No items found.")
        return
    }

    $Logger.WriteAnalyzeResult($moduleInfo.Name, $items)

    $grouped = $items | Group-Object -Property Category
    foreach ($group in $grouped) {
        $totalSize = ($group.Group | Measure-Object -Property Size -Sum).Sum
        Write-Host "  $($group.Name): $($group.Count) items ($(Format-FileSize $totalSize))" -ForegroundColor White
    }

    $totalItems = $items.Count
    $totalSize = ($items | Measure-Object -Property Size -Sum).Sum
    Write-Host ""
    Write-Host "Total: $totalItems items ($(Format-FileSize $totalSize))" -ForegroundColor Yellow
    Write-Host ""

    if ($IsDryRun) {
        Write-Host "[DryRun] No files were deleted." -ForegroundColor Magenta
        $Logger.WriteDryRun($moduleInfo.Name, $items)
        return
    }

    $confirm = Read-Host "Proceed with cleaning? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Cancelled." -ForegroundColor Gray
        $Logger.Write("Cancelled by user.")
        return
    }

    Write-Host "Cleaning..." -ForegroundColor Yellow
    $result = $Engine.CleanModule($ModuleIndex, $items)

    $Logger.WriteCleanResult($moduleInfo.Name, $result)

    Write-Host ""
    Write-Host "Completed: $($result.ItemCount) items removed ($(Format-FileSize $result.FreedBytes))" -ForegroundColor Green

    if ($result.Errors.Count -gt 0) {
        Write-Host "Errors: $($result.Errors.Count)" -ForegroundColor Red
        foreach ($err in $result.Errors) {
            Write-Host "  $err" -ForegroundColor DarkRed
        }
    }
}

# Main
function Start-WinCleaner {
    param(
        [bool]$IsDryRun
    )

    Show-Banner -IsDryRun $IsDryRun

    $settings = Read-Settings
    $logger = [Logger]::new($scriptRoot)
    $logger.Write("Session started (DryRun: $IsDryRun)")

    Write-Host "Log: $($logger.LogPath)" -ForegroundColor DarkGray
    Write-Host ""

    $engine = [CleanerEngine]::new()
    $engine.Register([TempCleaner]::new($settings))
    $engine.Register([RegistryCleaner]::new($settings))

    while ($true) {
        $moduleList = $engine.GetModuleList()
        Show-Menu -ModuleList $moduleList

        $choice = Read-Host "Select module"

        if ($choice -eq '0') {
            Write-Host "Bye!" -ForegroundColor Cyan
            $logger.Write("Session ended.")
            break
        }

        $index = 0
        if (-not [int]::TryParse($choice, [ref]$index) -or $index -lt 1 -or $index -gt $moduleList.Count) {
            Write-Host "Invalid selection." -ForegroundColor Red
            continue
        }

        Invoke-CleanerModule -Engine $engine -ModuleIndex ($index - 1) -IsDryRun $IsDryRun -Logger $logger
        Write-Host ""
    }
}

Start-WinCleaner -IsDryRun $DryRun.IsPresent
