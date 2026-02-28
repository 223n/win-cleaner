using module ..\Core\ICleanerModule.psm1
Import-Module "$PSScriptRoot\RegistryCleanerRule.psm1" -Force

function Resolve-HkcrPath {
    param(
        [string]$Path
    )

    # HKCRパスでなければそのまま返す
    $hkcrMarker = 'HKEY_CLASSES_ROOT\'
    $idx = $Path.IndexOf($hkcrMarker, [StringComparison]::OrdinalIgnoreCase)
    if ($idx -lt 0) {
        return $Path
    }

    $relativePath = $Path.Substring($idx + $hkcrMarker.Length)

    # .NET APIでハイブを順に確認（Test-PathはACL制限で失敗するケースがある）
    $candidates = @(
        @{ Hive = [Microsoft.Win32.Registry]::LocalMachine; Drive = 'HKLM:'; Sub = "SOFTWARE\Classes\$relativePath" }
        @{ Hive = [Microsoft.Win32.Registry]::CurrentUser;  Drive = 'HKCU:'; Sub = "SOFTWARE\Classes\$relativePath" }
        @{ Hive = [Microsoft.Win32.Registry]::LocalMachine; Drive = 'HKLM:'; Sub = "SOFTWARE\WOW6432Node\Classes\$relativePath" }
    )

    foreach ($c in $candidates) {
        $key = $null
        try {
            $key = $c.Hive.OpenSubKey($c.Sub, $false)
            if ($null -ne $key) {
                return "$($c.Drive)\$($c.Sub)"
            }
        }
        catch {}
        finally {
            if ($null -ne $key) { $key.Dispose() }
        }
    }

    return $Path
}

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
                switch ($target.rule) {
                    'invalidFileReference'    { Invoke-RuleInvalidFileReference    -Target $target -Items $items }
                    'invalidAppPath'          { Invoke-RuleInvalidAppPath          -Target $target -Items $items }
                    'invalidCOMReference'     { Invoke-RuleInvalidCOMReference     -Target $target -Items $items }
                    'invalidTypeLib'          { Invoke-RuleInvalidTypeLib          -Target $target -Items $items }
                    'invalidFileAssociation'  { Invoke-RuleInvalidFileAssociation  -Target $target -Items $items }
                    'invalidStartupEntry'     { Invoke-RuleInvalidStartupEntry     -Target $target -Items $items }
                    'invalidMUICache'         { Invoke-RuleInvalidMUICache         -Target $target -Items $items }
                }
            }
            catch [System.Security.SecurityException], [System.UnauthorizedAccessException] {
                # Permission denied — expected for protected registry keys
            }
            catch {
                Write-Warning "Registry scan error at '$($target.keyPath)': $($_.Exception.Message)"
            }
        }
        return $items.ToArray()
    }

    [CleanerResult] Clean([CleanerItem[]]$items) {
        $result = [CleanerResult]::new()

        foreach ($item in $items) {
            try {
                $resolvedPath = Resolve-HkcrPath -Path $item.Path
                if ($item.PropertyName) {
                    Remove-ItemProperty -Path $resolvedPath -Name $item.PropertyName -Force -ErrorAction Stop
                }
                else {
                    Remove-Item -Path $resolvedPath -Recurse -Force -ErrorAction Stop
                }
                $result.ItemCount++
            }
            catch {
                $result.Errors += "Failed to remove: $($item.Path) - $($_.Exception.Message)"
            }
        }
        return $result
    }
}

Export-ModuleMember -Function @('Resolve-HkcrPath')
