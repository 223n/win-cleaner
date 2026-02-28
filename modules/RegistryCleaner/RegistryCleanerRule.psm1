function Get-RegistryCleanerTargets {
    param(
        [hashtable]$Settings
    )

    return , @($Settings.registryCleaner.targets)
}

function Test-InvalidRegistryReference {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $true
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ($expanded -match '^[A-Za-z]:\\' -or $expanded -match '^\\\\') {
        return -not (Test-Path $expanded)
    }

    return $false
}

Export-ModuleMember -Function Get-RegistryCleanerTargets, Test-InvalidRegistryReference
