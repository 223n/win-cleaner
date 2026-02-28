function Get-TempCleanerTargets {
    param(
        [hashtable]$Settings
    )

    $targets = @()
    foreach ($entry in $Settings.tempCleaner.targets) {
        $path = [Environment]::ExpandEnvironmentVariables($entry.path)
        if (Test-Path $path) {
            $targets += @{
                Path     = $path
                Pattern  = $entry.pattern
                Recurse  = $entry.recurse
                Category = $entry.category
            }
        }
    }
    return , @($targets)
}

function Test-ExcludedPath {
    param(
        [string]$FilePath,
        [string[]]$ExcludePatterns
    )

    foreach ($pattern in $ExcludePatterns) {
        if ($FilePath -like $pattern) {
            return $true
        }
    }
    return $false
}

Export-ModuleMember -Function Get-TempCleanerTargets, Test-ExcludedPath
