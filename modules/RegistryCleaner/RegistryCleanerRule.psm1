using module ..\Core\ICleanerModule.psm1

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

function Get-ExecutablePath {
    param(
        [string]$CommandLine
    )

    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return $null
    }

    $cmd = $CommandLine.Trim()

    # rundll32 pattern: extract the DLL path argument
    if ($cmd -match '(?i)rundll32(?:\.exe)?\s+(.+)') {
        $arg = $Matches[1].Trim()
        if ($arg.StartsWith('"')) {
            if ($arg -match '^"([^"]+)"') {
                return $Matches[1]
            }
        }
        else {
            $commaIdx = $arg.IndexOf(',')
            if ($commaIdx -gt 0) {
                return $arg.Substring(0, $commaIdx).Trim()
            }
            $spaceIdx = $arg.IndexOf(' ')
            if ($spaceIdx -gt 0) {
                return $arg.Substring(0, $spaceIdx)
            }
            return $arg
        }
    }

    # Quoted path: "C:\path\app.exe" --args
    if ($cmd.StartsWith('"')) {
        if ($cmd -match '^"([^"]+)"') {
            return $Matches[1]
        }
        return $null
    }

    # Unquoted path starting with drive letter: C:\path\app.exe /arg
    if ($cmd -match '^([A-Za-z]:\\[^\s]+)') {
        return $Matches[1]
    }

    return $null
}

function Invoke-RuleInvalidFileReference {
    param(
        [hashtable]$Target,
        [System.Collections.Generic.List[CleanerItem]]$Items
    )

    $subKeys = Get-ChildItem -Path $Target.keyPath -ErrorAction SilentlyContinue
    foreach ($subKey in $subKeys) {
        try {
            $defaultValue = (Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue).'(default)'
            if ($defaultValue -and (Test-InvalidRegistryReference -Path $defaultValue)) {
                $item = [CleanerItem]::new()
                $item.Path = $subKey.PSPath
                $item.Size = 0
                $item.Category = $Target.category
                $Items.Add($item)
            }
        }
        catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
            # Permission denied — skip this subkey
        }
        catch {
            Write-Warning "Registry scan error at '$($subKey.PSPath)': $($_.Exception.Message)"
        }
    }
}

function Invoke-RuleInvalidAppPath {
    param(
        [hashtable]$Target,
        [System.Collections.Generic.List[CleanerItem]]$Items
    )

    $subKeys = Get-ChildItem -Path $Target.keyPath -ErrorAction SilentlyContinue
    foreach ($subKey in $subKeys) {
        try {
            $pathValue = (Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue).Path
            if ($pathValue -and (Test-InvalidRegistryReference -Path $pathValue)) {
                $item = [CleanerItem]::new()
                $item.Path = $subKey.PSPath
                $item.Size = 0
                $item.Category = $Target.category
                $Items.Add($item)
            }
        }
        catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
            # Permission denied — skip this subkey
        }
        catch {
            Write-Warning "Registry scan error at '$($subKey.PSPath)': $($_.Exception.Message)"
        }
    }
}

function Invoke-RuleInvalidCOMReference {
    param(
        [hashtable]$Target,
        [System.Collections.Generic.List[CleanerItem]]$Items
    )

    $clsidPath = $Target.keyPath
    $subKeys = Get-ChildItem -Path $clsidPath -ErrorAction SilentlyContinue
    foreach ($subKey in $subKeys) {
        try {
            $invalid = $false
            foreach ($serverKey in @('InprocServer32', 'LocalServer32')) {
                $serverPath = Join-Path $subKey.PSPath $serverKey
                if (Test-Path $serverPath) {
                    $defaultValue = (Get-ItemProperty -Path $serverPath -ErrorAction SilentlyContinue).'(default)'
                    if ($defaultValue -and (Test-InvalidRegistryReference -Path $defaultValue)) {
                        $invalid = $true
                        break
                    }
                }
            }
            if ($invalid) {
                $item = [CleanerItem]::new()
                $item.Path = $subKey.PSPath
                $item.Size = 0
                $item.Category = $Target.category
                $Items.Add($item)
            }
        }
        catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
            # Permission denied — skip this subkey
        }
        catch {
            Write-Warning "Registry scan error at '$($subKey.PSPath)': $($_.Exception.Message)"
        }
    }
}

function Invoke-RuleInvalidTypeLib {
    param(
        [hashtable]$Target,
        [System.Collections.Generic.List[CleanerItem]]$Items
    )

    $typeLibPath = $Target.keyPath
    $guidKeys = Get-ChildItem -Path $typeLibPath -ErrorAction SilentlyContinue
    foreach ($guidKey in $guidKeys) {
        try {
            $invalid = $false
            $versionKeys = Get-ChildItem -Path $guidKey.PSPath -ErrorAction SilentlyContinue
            foreach ($versionKey in $versionKeys) {
                $zeroPath = Join-Path $versionKey.PSPath '0'
                if (-not (Test-Path $zeroPath)) {
                    continue
                }
                foreach ($platform in @('win32', 'win64')) {
                    $platPath = Join-Path $zeroPath $platform
                    if (Test-Path $platPath) {
                        $defaultValue = (Get-ItemProperty -Path $platPath -ErrorAction SilentlyContinue).'(default)'
                        if ($defaultValue -and (Test-InvalidRegistryReference -Path $defaultValue)) {
                            $invalid = $true
                            break
                        }
                    }
                }
                if ($invalid) { break }
            }
            if ($invalid) {
                $item = [CleanerItem]::new()
                $item.Path = $guidKey.PSPath
                $item.Size = 0
                $item.Category = $Target.category
                $Items.Add($item)
            }
        }
        catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
            # Permission denied — skip this subkey
        }
        catch {
            Write-Warning "Registry scan error at '$($guidKey.PSPath)': $($_.Exception.Message)"
        }
    }
}

function Invoke-RuleInvalidFileAssociation {
    param(
        [hashtable]$Target,
        [System.Collections.Generic.List[CleanerItem]]$Items
    )

    $hkcrPath = $Target.keyPath
    $subKeys = Get-ChildItem -Path $hkcrPath -ErrorAction SilentlyContinue
    foreach ($subKey in $subKeys) {
        try {
            # Only process file extension keys (starting with '.')
            if ($subKey.PSChildName -notmatch '^\.') {
                continue
            }
            $defaultValue = (Get-ItemProperty -Path $subKey.PSPath -ErrorAction SilentlyContinue).'(default)'
            if ([string]::IsNullOrWhiteSpace($defaultValue)) {
                continue
            }
            $progIdPath = Join-Path $hkcrPath $defaultValue
            if (-not (Test-Path $progIdPath)) {
                $item = [CleanerItem]::new()
                $item.Path = $subKey.PSPath
                $item.Size = 0
                $item.Category = $Target.category
                $Items.Add($item)
            }
        }
        catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
            # Permission denied — skip this subkey
        }
        catch {
            Write-Warning "Registry scan error at '$($subKey.PSPath)': $($_.Exception.Message)"
        }
    }
}

function Invoke-RuleInvalidStartupEntry {
    param(
        [hashtable]$Target,
        [System.Collections.Generic.List[CleanerItem]]$Items
    )

    $keyPath = $Target.keyPath
    $properties = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
    if (-not $properties) {
        return
    }

    $exclude = @('PSPath', 'PSParentPath', 'PSChildName', 'PSProvider', 'PSDrive')
    $propNames = $properties.PSObject.Properties |
        Where-Object { $_.Name -notin $exclude } |
        Select-Object -ExpandProperty Name

    foreach ($propName in $propNames) {
        try {
            $value = $properties.$propName
            if ([string]::IsNullOrWhiteSpace($value)) {
                continue
            }
            $exePath = Get-ExecutablePath -CommandLine $value
            if ($exePath -and (Test-InvalidRegistryReference -Path $exePath)) {
                $item = [CleanerItem]::new()
                $item.Path = $keyPath
                $item.Size = 0
                $item.Category = $Target.category
                $item.PropertyName = $propName
                $Items.Add($item)
            }
        }
        catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
            # Permission denied — skip this value
        }
        catch {
            Write-Warning "Registry scan error at '$keyPath\$propName': $($_.Exception.Message)"
        }
    }
}

function Invoke-RuleInvalidMUICache {
    param(
        [hashtable]$Target,
        [System.Collections.Generic.List[CleanerItem]]$Items
    )

    $keyPath = $Target.keyPath
    $properties = Get-ItemProperty -Path $keyPath -ErrorAction SilentlyContinue
    if (-not $properties) {
        return
    }

    $exclude = @('PSPath', 'PSParentPath', 'PSChildName', 'PSProvider', 'PSDrive')
    $propNames = $properties.PSObject.Properties |
        Where-Object { $_.Name -notin $exclude } |
        Select-Object -ExpandProperty Name

    foreach ($propName in $propNames) {
        try {
            # MuiCache value names contain file paths (e.g., "C:\path\app.exe.FriendlyAppName")
            # Extract the file path portion before the last dot-separated metadata suffix
            $filePath = $propName
            if ($filePath -match '^(.+\.[^.]+)\.[^.\\]+$') {
                $filePath = $Matches[1]
            }
            if ($filePath -and (Test-InvalidRegistryReference -Path $filePath)) {
                $item = [CleanerItem]::new()
                $item.Path = $keyPath
                $item.Size = 0
                $item.Category = $Target.category
                $item.PropertyName = $propName
                $Items.Add($item)
            }
        }
        catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
            # Permission denied — skip this value
        }
        catch {
            Write-Warning "Registry scan error at '$keyPath\$propName': $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function Get-RegistryCleanerTargets,
    Test-InvalidRegistryReference,
    Get-ExecutablePath,
    Invoke-RuleInvalidFileReference,
    Invoke-RuleInvalidAppPath,
    Invoke-RuleInvalidCOMReference,
    Invoke-RuleInvalidTypeLib,
    Invoke-RuleInvalidFileAssociation,
    Invoke-RuleInvalidStartupEntry,
    Invoke-RuleInvalidMUICache
