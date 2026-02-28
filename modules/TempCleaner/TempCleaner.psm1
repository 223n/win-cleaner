using module ..\Core\ICleanerModule.psm1
Import-Module "$PSScriptRoot\TempCleanerRule.psm1" -Force

class TempCleaner : ICleanerModule {
    [hashtable]$Settings

    TempCleaner([hashtable]$settings) {
        $this.Settings = $settings
    }

    [string] GetName() {
        return "Temp Cleaner"
    }

    [string] GetDescription() {
        return "Delete temporary files and caches"
    }

    [bool] RequiresAdmin() {
        return $false
    }

    [CleanerItem[]] Analyze() {
        $items = [System.Collections.Generic.List[CleanerItem]]::new()
        $targets = Get-TempCleanerTargets -Settings $this.Settings
        $excludes = $this.Settings.tempCleaner.excludePatterns

        foreach ($target in $targets) {
            $params = @{
                Path        = $target.Path
                ErrorAction = 'SilentlyContinue'
            }
            if ($target.Pattern) {
                $params.Filter = $target.Pattern
            }
            if ($target.Recurse) {
                $params.Recurse = $true
            }

            $files = Get-ChildItem @params -File
            foreach ($file in $files) {
                if (-not (Test-ExcludedPath -FilePath $file.FullName -ExcludePatterns $excludes)) {
                    $item = [CleanerItem]::new()
                    $item.Path = $file.FullName
                    $item.Size = $file.Length
                    $item.Category = $target.Category
                    $items.Add($item)
                }
            }
        }
        return $items.ToArray()
    }

    [CleanerResult] Clean([CleanerItem[]]$items) {
        $result = [CleanerResult]::new()

        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.Path -Force -ErrorAction Stop
                $result.ItemCount++
                $result.FreedBytes += $item.Size
            }
            catch {
                $result.Errors += "Failed to delete: $($item.Path) - $($_.Exception.Message)"
            }
        }
        return $result
    }
}

Export-ModuleMember -Function @()
