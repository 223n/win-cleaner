using module ..\Core\ICleanerModule.psm1
Import-Module "$PSScriptRoot\RegistryCleanerRule.psm1" -Force

class RegistryCleaner : ICleanerModule {
    [hashtable]$Settings

    RegistryCleaner([hashtable]$settings) {
        $this.Settings = $settings
    }

    [string] GetName() {
        return "Registry Cleaner"
    }

    [string] GetDescription() {
        return "Detect and remove invalid registry entries"
    }

    [bool] RequiresAdmin() {
        return $true
    }

    [CleanerItem[]] Analyze() {
        $items = [System.Collections.Generic.List[CleanerItem]]::new()
        $targets = Get-RegistryCleanerTargets -Settings $this.Settings

        foreach ($target in $targets) {
            if (-not (Test-Path $target.keyPath)) {
                continue
            }

            try {
                $subKeys = Get-ChildItem -Path $target.keyPath -ErrorAction SilentlyContinue
                foreach ($subKey in $subKeys) {
                    $shouldClean = $false

                    if ($target.rule -eq "invalidFileReference") {
                        $defaultValue = (Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue).'(default)'
                        if ($defaultValue -and (Test-InvalidRegistryReference -Path $defaultValue)) {
                            $shouldClean = $true
                        }
                    }
                    elseif ($target.rule -eq "invalidAppPath") {
                        $pathValue = (Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue).Path
                        if ($pathValue -and (Test-InvalidRegistryReference -Path $pathValue)) {
                            $shouldClean = $true
                        }
                    }

                    if ($shouldClean) {
                        $item = [CleanerItem]::new()
                        $item.Path = $subKey.PSPath
                        $item.Size = 0
                        $item.Category = $target.category
                        $items.Add($item)
                    }
                }
            }
            catch {
                # Skip inaccessible keys
            }
        }
        return $items.ToArray()
    }

    [CleanerResult] Clean([CleanerItem[]]$items) {
        $result = [CleanerResult]::new()

        foreach ($item in $items) {
            try {
                Remove-Item -Path $item.Path -Recurse -Force -ErrorAction Stop
                $result.ItemCount++
            }
            catch {
                $result.Errors += "Failed to remove: $($item.Path) - $($_.Exception.Message)"
            }
        }
        return $result
    }
}

Export-ModuleMember -Function @()
