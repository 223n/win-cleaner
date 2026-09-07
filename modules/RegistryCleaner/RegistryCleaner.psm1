using module ..\Core\ICleanerModule.psm1
Import-Module "$PSScriptRoot\RegistryCleanerRule.psm1" -Force

function Get-HkcrCandidatePath {
    <#
        HKCR は HKLM\SOFTWARE\Classes と HKCU\SOFTWARE\Classes を値単位で
        重ねた仮想ビューで、同じキーが複数のハイブに実在しうる。
        検出は HKCR の実効値で判定するが、削除は実ハイブに対して行うため、
        どのハイブを消すかで結果が変わる。

        実測（Windows 11）では HKLM\SOFTWARE\Classes 直下 4209 件と
        HKCU\SOFTWARE\Classes 直下 863 件のうち 224 件が両方に存在し、
        うち 19 件は HKCU の値が HKLM を覆い隠していた（.jpg / .gif / .avi など）。
        先に見つけたハイブを消す実装では、判定の根拠になった HKCU の値を
        残したまま、全ユーザー共通の HKLM 側を消しうる。

        そのため、一致したハイブをすべて返す。呼び出し側は候補が1つに
        定まらない場合に削除を見送る。
    #>
    param(
        [string]$Path
    )

    $hkcrMarker = 'HKEY_CLASSES_ROOT\'
    $idx = $Path.IndexOf($hkcrMarker, [StringComparison]::OrdinalIgnoreCase)
    if ($idx -lt 0) {
        # HKCR 以外はそのまま扱う（曖昧さが無い）
        return , @($Path)
    }

    $relativePath = $Path.Substring($idx + $hkcrMarker.Length)

    # Test-Path は ACL 制限で失敗しうるため .NET API で確認する
    $candidates = @(
        @{ Hive = [Microsoft.Win32.Registry]::CurrentUser;  Drive = 'HKCU:'; Sub = "SOFTWARE\Classes\$relativePath" }
        @{ Hive = [Microsoft.Win32.Registry]::LocalMachine; Drive = 'HKLM:'; Sub = "SOFTWARE\Classes\$relativePath" }
        @{ Hive = [Microsoft.Win32.Registry]::LocalMachine; Drive = 'HKLM:'; Sub = "SOFTWARE\WOW6432Node\Classes\$relativePath" }
    )

    $found = @()
    foreach ($c in $candidates) {
        $key = $null
        try {
            $key = $c.Hive.OpenSubKey($c.Sub, $false)
            if ($null -ne $key) {
                $found += "$($c.Drive)\$($c.Sub)"
            }
        }
        catch {}
        finally {
            if ($null -ne $key) { $key.Dispose() }
        }
    }

    return , @($found)
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
            if (-not (Test-Path -LiteralPath $target.keyPath)) {
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
                $candidates = Get-HkcrCandidatePath -Path $item.Path

                if ($candidates.Count -eq 0) {
                    $result.Errors += "Skipped (key not found in any hive): $($item.Path)"
                    continue
                }
                if ($candidates.Count -gt 1) {
                    # 複数のハイブに実在する。HKCR の実効値がどちらに由来するかは
                    # 値単位で決まるため、ここでは判断できない。誤って全ユーザー
                    # 共通の設定を消さないよう、削除は見送って報告する。
                    $result.Errors += "Skipped (exists in multiple hives, resolve manually): $($item.Path) -> $($candidates -join ', ')"
                    continue
                }

                $resolvedPath = $candidates[0]
                if ($item.PropertyName) {
                    # -Path はワイルドカードを解釈するため、角括弧を含むキー名で
                    # 別のキーを巻き添えにする。必ず -LiteralPath を使う。
                    Remove-ItemProperty -LiteralPath $resolvedPath -Name $item.PropertyName -Force -ErrorAction Stop
                }
                else {
                    Remove-Item -LiteralPath $resolvedPath -Recurse -Force -ErrorAction Stop
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

Export-ModuleMember -Function @('Get-HkcrCandidatePath')
