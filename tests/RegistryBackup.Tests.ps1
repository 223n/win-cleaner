#Requires -Modules Pester
using module ..\modules\Core\ICleanerModule.psm1
using module ..\modules\RegistryCleaner\RegistryCleaner.psm1

# レジストリ削除前の控えに関するテスト。
# 削除は取り消せないため、控えが取れることと、取れなければ削除しないことを固定する。

BeforeAll {
    Import-Module "$PSScriptRoot\..\modules\RegistryCleaner\RegistryCleaner.psm1" -Force
    $script:testRoot = 'HKCU:\SOFTWARE\win-cleaner-pester'
    $script:testRootNative = 'HKCU\SOFTWARE\win-cleaner-pester'
}

AfterAll {
    & reg.exe delete $script:testRootNative /f 2>&1 | Out-Null
}

Describe "ConvertTo-NativeRegistryPath" {
    It "<name> を reg.exe の形式へ変換する" -ForEach @(
        @{ name = 'HKLM ドライブ'; in = 'HKLM:\SOFTWARE\Classes\.jpg'; want = 'HKEY_LOCAL_MACHINE\SOFTWARE\Classes\.jpg' }
        @{ name = 'HKCU ドライブ'; in = 'HKCU:\SOFTWARE\Test'; want = 'HKEY_CURRENT_USER\SOFTWARE\Test' }
        @{ name = 'プロバイダー修飾'; in = 'Microsoft.PowerShell.Core\Registry::HKEY_CLASSES_ROOT\.jpg'; want = 'HKEY_CLASSES_ROOT\.jpg' }
        @{ name = 'ネイティブ形式'; in = 'HKEY_LOCAL_MACHINE\SOFTWARE\Test'; want = 'HKEY_LOCAL_MACHINE\SOFTWARE\Test' }
    ) {
        ConvertTo-NativeRegistryPath -Path $in | Should -Be $want
    }

    It "レジストリ以外のパスは null を返す" {
        ConvertTo-NativeRegistryPath -Path 'C:\temp\file.txt' | Should -BeNullOrEmpty
    }
}

Describe "Export-RegistryKeyBackup" {
    BeforeEach {
        $script:backup = Join-Path ([IO.Path]::GetTempPath()) ("wc-bak-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + ".reg")
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:backup) { [System.IO.File]::Delete($script:backup) }
        & reg.exe delete $script:testRootNative /f 2>&1 | Out-Null
    }

    It "控えから元の値を復元できる" {
        $key = "$script:testRoot\restore"
        New-Item -Path $key -Force | Out-Null
        Set-ItemProperty -LiteralPath $key -Name 'V' -Value 'original'

        Export-RegistryKeyBackup -Path $key -BackupPath $script:backup
        Test-Path -LiteralPath $script:backup | Should -Be $true

        & reg.exe delete "$script:testRootNative\restore" /f 2>&1 | Out-Null
        Test-Path -LiteralPath $key | Should -Be $false

        & reg.exe import $script:backup 2>&1 | Out-Null
        (Get-ItemProperty -LiteralPath $key).V | Should -Be 'original'
    }

    It "複数キーを1ファイルへ追記してもヘッダーは1行だけになる" {
        1..3 | ForEach-Object {
            $k = "$script:testRoot\multi$_"
            New-Item -Path $k -Force | Out-Null
            Set-ItemProperty -LiteralPath $k -Name 'V' -Value "value$_"
            Export-RegistryKeyBackup -Path $k -BackupPath $script:backup
        }

        $lines = [System.IO.File]::ReadAllLines($script:backup, [System.Text.Encoding]::Unicode)
        @($lines | Where-Object { $_ -like 'Windows Registry Editor*' }).Count | Should -Be 1
        @($lines | Where-Object { $_ -like '`[HKEY*' }).Count | Should -Be 3
    }

    It "変換できないパスは例外を投げる" {
        { Export-RegistryKeyBackup -Path 'C:\temp\not-registry' -BackupPath $script:backup } |
            Should -Throw -ExpectedMessage "*reg.exe の形式へ変換できません*"
    }
}
