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

function ConvertTo-RegistryKeyComponents {
    param(
        [string]$Path
    )

    $hive = $null
    $hiveName = $null
    $subPath = $null

    if ($Path -match '^HKLM:\\(.+)$') {
        $hive = [Microsoft.Win32.Registry]::LocalMachine
        $hiveName = 'HKEY_LOCAL_MACHINE'
        $subPath = $Matches[1]
    }
    elseif ($Path -match '^HKCU:\\(.+)$') {
        $hive = [Microsoft.Win32.Registry]::CurrentUser
        $hiveName = 'HKEY_CURRENT_USER'
        $subPath = $Matches[1]
    }
    elseif ($Path -match '(?i)Registry::HKEY_CLASSES_ROOT\\(.+)$') {
        $hive = [Microsoft.Win32.Registry]::ClassesRoot
        $hiveName = 'HKEY_CLASSES_ROOT'
        $subPath = $Matches[1]
    }
    elseif ($Path -match '(?i)Registry::HKEY_LOCAL_MACHINE\\(.+)$') {
        $hive = [Microsoft.Win32.Registry]::LocalMachine
        $hiveName = 'HKEY_LOCAL_MACHINE'
        $subPath = $Matches[1]
    }
    elseif ($Path -match '(?i)Registry::HKEY_CURRENT_USER\\(.+)$') {
        $hive = [Microsoft.Win32.Registry]::CurrentUser
        $hiveName = 'HKEY_CURRENT_USER'
        $subPath = $Matches[1]
    }
    else {
        return $null
    }

    return @{
        Hive     = $hive
        HiveName = $hiveName
        SubPath  = $subPath
    }
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

    $components = ConvertTo-RegistryKeyComponents -Path $Target.keyPath
    if ($null -eq $components) { return }

    $baseKey = $null
    try {
        $baseKey = $components.Hive.OpenSubKey($components.SubPath, $false)
        if ($null -eq $baseKey) { return }

        foreach ($name in $baseKey.GetSubKeyNames()) {
            $clsidKey = $null
            try {
                $clsidKey = $baseKey.OpenSubKey($name, $false)
                if ($null -eq $clsidKey) { continue }

                $invalid = $false
                foreach ($serverKey in @('InprocServer32', 'LocalServer32')) {
                    $serverSubKey = $null
                    try {
                        $serverSubKey = $clsidKey.OpenSubKey($serverKey, $false)
                        if ($null -ne $serverSubKey) {
                            $defaultValue = $serverSubKey.GetValue('')
                            if (-not $defaultValue) { continue }

                            # LocalServer32はコマンドラインなので実行ファイルパスを抽出
                            if ($serverKey -eq 'LocalServer32') {
                                $checkPath = Get-ExecutablePath -CommandLine $defaultValue
                            }
                            else {
                                $checkPath = $defaultValue
                            }

                            if ($checkPath -and (Test-InvalidRegistryReference -Path $checkPath)) {
                                $invalid = $true
                                break
                            }
                        }
                    }
                    finally {
                        if ($null -ne $serverSubKey) { $serverSubKey.Dispose() }
                    }
                }

                if ($invalid) {
                    # 書き込み権限を確認 — 削除できないキーはスキップ
                    $canDelete = $false
                    $writableKey = $null
                    try {
                        $writableKey = $baseKey.OpenSubKey($name, $true)
                        if ($null -ne $writableKey) { $canDelete = $true }
                    }
                    catch {}
                    finally {
                        if ($null -ne $writableKey) { $writableKey.Dispose() }
                    }

                    if ($canDelete) {
                        $item = [CleanerItem]::new()
                        $item.Path = "Microsoft.PowerShell.Core\Registry::$($components.HiveName)\$($components.SubPath)\$name"
                        $item.Size = 0
                        $item.Category = $Target.category
                        $Items.Add($item)
                    }
                }
            }
            catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
                # Permission denied — skip this subkey
            }
            catch {
                Write-Warning "Registry scan error at '$($Target.keyPath)\$name': $($_.Exception.Message)"
            }
            finally {
                if ($null -ne $clsidKey) { $clsidKey.Dispose() }
            }
        }
    }
    catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
        # Permission denied
    }
    finally {
        if ($null -ne $baseKey) { $baseKey.Dispose() }
    }
}

function Invoke-RuleInvalidTypeLib {
    param(
        [hashtable]$Target,
        [System.Collections.Generic.List[CleanerItem]]$Items
    )

    $components = ConvertTo-RegistryKeyComponents -Path $Target.keyPath
    if ($null -eq $components) { return }

    $baseKey = $null
    try {
        $baseKey = $components.Hive.OpenSubKey($components.SubPath, $false)
        if ($null -eq $baseKey) { return }

        foreach ($guidName in $baseKey.GetSubKeyNames()) {
            $guidKey = $null
            try {
                $guidKey = $baseKey.OpenSubKey($guidName, $false)
                if ($null -eq $guidKey) { continue }

                $invalid = $false
                foreach ($versionName in $guidKey.GetSubKeyNames()) {
                    $versionKey = $null
                    try {
                        $versionKey = $guidKey.OpenSubKey($versionName, $false)
                        if ($null -eq $versionKey) { continue }

                        $zeroKey = $null
                        try {
                            $zeroKey = $versionKey.OpenSubKey('0', $false)
                            if ($null -eq $zeroKey) { continue }

                            foreach ($platform in @('win32', 'win64')) {
                                $platKey = $null
                                try {
                                    $platKey = $zeroKey.OpenSubKey($platform, $false)
                                    if ($null -ne $platKey) {
                                        $defaultValue = $platKey.GetValue('')
                                        if ($defaultValue -and (Test-InvalidRegistryReference -Path $defaultValue)) {
                                            $invalid = $true
                                            break
                                        }
                                    }
                                }
                                finally {
                                    if ($null -ne $platKey) { $platKey.Dispose() }
                                }
                            }
                        }
                        finally {
                            if ($null -ne $zeroKey) { $zeroKey.Dispose() }
                        }
                    }
                    finally {
                        if ($null -ne $versionKey) { $versionKey.Dispose() }
                    }
                    if ($invalid) { break }
                }

                if ($invalid) {
                    # 書き込み権限を確認 — 削除できないキーはスキップ
                    $canDelete = $false
                    $writableKey = $null
                    try {
                        $writableKey = $baseKey.OpenSubKey($guidName, $true)
                        if ($null -ne $writableKey) { $canDelete = $true }
                    }
                    catch {}
                    finally {
                        if ($null -ne $writableKey) { $writableKey.Dispose() }
                    }

                    if ($canDelete) {
                        $item = [CleanerItem]::new()
                        $item.Path = "Microsoft.PowerShell.Core\Registry::$($components.HiveName)\$($components.SubPath)\$guidName"
                        $item.Size = 0
                        $item.Category = $Target.category
                        $Items.Add($item)
                    }
                }
            }
            catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
                # Permission denied — skip this subkey
            }
            catch {
                Write-Warning "Registry scan error at '$($Target.keyPath)\$guidName': $($_.Exception.Message)"
            }
            finally {
                if ($null -ne $guidKey) { $guidKey.Dispose() }
            }
        }
    }
    catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
        # Permission denied
    }
    finally {
        if ($null -ne $baseKey) { $baseKey.Dispose() }
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
    ConvertTo-RegistryKeyComponents,
    Invoke-RuleInvalidFileReference,
    Invoke-RuleInvalidAppPath,
    Invoke-RuleInvalidCOMReference,
    Invoke-RuleInvalidTypeLib,
    Invoke-RuleInvalidFileAssociation,
    Invoke-RuleInvalidStartupEntry,
    Invoke-RuleInvalidMUICache
