class Logger {
    [string]$LogDir
    [string]$LogPath

    Logger([string]$baseDir) {
        $this.LogDir = Join-Path $baseDir "logs"
        if (-not (Test-Path $this.LogDir)) {
            New-Item -Path $this.LogDir -ItemType Directory -Force | Out-Null
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $this.LogPath = Join-Path $this.LogDir "win-cleaner_$timestamp.log"
    }

    [void] Write([string]$message) {
        $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $message"
        Add-Content -Path $this.LogPath -Value $entry -Encoding UTF8
    }

    [void] WriteAnalyzeResult([string]$moduleName, [object[]]$items) {
        $this.Write("=== Analyze: $moduleName ===")
        if ($items.Count -eq 0) {
            $this.Write("No items found.")
            return
        }

        $grouped = $items | Group-Object -Property Category
        foreach ($group in $grouped) {
            $totalSize = ($group.Group | Measure-Object -Property Size -Sum).Sum
            $this.Write("  $($group.Name): $($group.Count) items ($totalSize bytes)")
        }
        $this.Write("Total: $($items.Count) items")
    }

    [void] WriteCleanResult([string]$moduleName, [object]$result) {
        $this.Write("=== Clean: $moduleName ===")
        $this.Write("Removed: $($result.ItemCount) items ($($result.FreedBytes) bytes)")
        if ($result.Errors.Count -gt 0) {
            $this.Write("Errors: $($result.Errors.Count)")
            foreach ($err in $result.Errors) {
                $this.Write("  $err")
            }
        }
    }

    [void] WriteDryRun([string]$moduleName, [object[]]$items) {
        $this.Write("=== DryRun: $moduleName ===")
        foreach ($item in $items) {
            $this.Write("  [DryRun] Would delete: $($item.Path) ($($item.Size) bytes)")
        }
    }
}

Export-ModuleMember -Function @()
