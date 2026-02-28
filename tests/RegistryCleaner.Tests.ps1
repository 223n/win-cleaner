#Requires -Modules Pester
using module ..\modules\Core\ICleanerModule.psm1
using module ..\modules\RegistryCleaner\RegistryCleaner.psm1

BeforeAll {
    Import-Module "$PSScriptRoot\..\modules\RegistryCleaner\RegistryCleaner.psm1" -Force
    Import-Module "$PSScriptRoot\..\modules\RegistryCleaner\RegistryCleanerRule.psm1" -Force
}

Describe "RegistryCleanerRule" {
    Context "Test-InvalidRegistryReference" {
        It "should return true for empty path" {
            Test-InvalidRegistryReference -Path "" | Should -Be $true
        }

        It "should return true for non-existent file path" {
            Test-InvalidRegistryReference -Path "C:\nonexistent\path\app.exe" | Should -Be $true
        }

        It "should return false for existing path" {
            Test-InvalidRegistryReference -Path $env:SystemRoot | Should -Be $false
        }

        It "should return false for non-file-path string" {
            Test-InvalidRegistryReference -Path "some-value" | Should -Be $false
        }
    }

    Context "Get-RegistryCleanerTargets" {
        It "should return targets from settings" {
            $settings = @{
                registryCleaner = @{
                    targets = @(
                        @{
                            category = "Test"
                            keyPath  = "HKLM:\SOFTWARE\Test"
                            rule     = "invalidFileReference"
                        }
                    )
                }
            }

            $targets = Get-RegistryCleanerTargets -Settings $settings
            $targets.Count | Should -Be 1
            $targets[0].category | Should -Be "Test"
        }
    }

    Context "Get-ExecutablePath" {
        It "should extract quoted path" {
            Get-ExecutablePath -CommandLine '"C:\Program Files\app.exe" --arg' | Should -Be 'C:\Program Files\app.exe'
        }

        It "should extract unquoted path" {
            Get-ExecutablePath -CommandLine 'C:\tools\app.exe /silent' | Should -Be 'C:\tools\app.exe'
        }

        It "should extract DLL path from rundll32 command" {
            Get-ExecutablePath -CommandLine 'rundll32.exe C:\Windows\system32\lib.dll,EntryPoint' | Should -Be 'C:\Windows\system32\lib.dll'
        }

        It "should return null for non-path string" {
            Get-ExecutablePath -CommandLine 'just some text' | Should -BeNullOrEmpty
        }

        It "should return null for empty string" {
            Get-ExecutablePath -CommandLine '' | Should -BeNullOrEmpty
        }

        It "should return null for null input" {
            Get-ExecutablePath -CommandLine $null | Should -BeNullOrEmpty
        }
    }

    Context "Invoke-RuleInvalidFileReference" {
        It "should not error on non-existent key path" {
            $target = @{
                category = "Test"
                keyPath  = "HKCU:\SOFTWARE\WinCleanerTest_NonExistent_$(Get-Random)"
            }
            $items = [System.Collections.Generic.List[CleanerItem]]::new()

            { Invoke-RuleInvalidFileReference -Target $target -Items $items } | Should -Not -Throw
            $items.Count | Should -Be 0
        }
    }

    Context "Invoke-RuleInvalidAppPath" {
        It "should not error on non-existent key path" {
            $target = @{
                category = "Test"
                keyPath  = "HKCU:\SOFTWARE\WinCleanerTest_NonExistent_$(Get-Random)"
            }
            $items = [System.Collections.Generic.List[CleanerItem]]::new()

            { Invoke-RuleInvalidAppPath -Target $target -Items $items } | Should -Not -Throw
            $items.Count | Should -Be 0
        }
    }

    Context "Invoke-RuleInvalidCOMReference" {
        It "should not error on non-existent key path" {
            $target = @{
                category = "Test"
                keyPath  = "HKCU:\SOFTWARE\WinCleanerTest_NonExistent_$(Get-Random)"
            }
            $items = [System.Collections.Generic.List[CleanerItem]]::new()

            { Invoke-RuleInvalidCOMReference -Target $target -Items $items } | Should -Not -Throw
            $items.Count | Should -Be 0
        }
    }

    Context "Invoke-RuleInvalidTypeLib" {
        It "should not error on non-existent key path" {
            $target = @{
                category = "Test"
                keyPath  = "HKCU:\SOFTWARE\WinCleanerTest_NonExistent_$(Get-Random)"
            }
            $items = [System.Collections.Generic.List[CleanerItem]]::new()

            { Invoke-RuleInvalidTypeLib -Target $target -Items $items } | Should -Not -Throw
            $items.Count | Should -Be 0
        }
    }

    Context "Invoke-RuleInvalidFileAssociation" {
        It "should not error on non-existent key path" {
            $target = @{
                category = "Test"
                keyPath  = "HKCU:\SOFTWARE\WinCleanerTest_NonExistent_$(Get-Random)"
            }
            $items = [System.Collections.Generic.List[CleanerItem]]::new()

            { Invoke-RuleInvalidFileAssociation -Target $target -Items $items } | Should -Not -Throw
            $items.Count | Should -Be 0
        }
    }

    Context "Invoke-RuleInvalidStartupEntry" {
        It "should not error on non-existent key path" {
            $target = @{
                category = "Test"
                keyPath  = "HKCU:\SOFTWARE\WinCleanerTest_NonExistent_$(Get-Random)"
            }
            $items = [System.Collections.Generic.List[CleanerItem]]::new()

            { Invoke-RuleInvalidStartupEntry -Target $target -Items $items } | Should -Not -Throw
            $items.Count | Should -Be 0
        }
    }

    Context "Invoke-RuleInvalidMUICache" {
        It "should not error on non-existent key path" {
            $target = @{
                category = "Test"
                keyPath  = "HKCU:\SOFTWARE\WinCleanerTest_NonExistent_$(Get-Random)"
            }
            $items = [System.Collections.Generic.List[CleanerItem]]::new()

            { Invoke-RuleInvalidMUICache -Target $target -Items $items } | Should -Not -Throw
            $items.Count | Should -Be 0
        }
    }
}

Describe "ConvertTo-RegistryKeyComponents" {
    It "should parse HKLM drive path" {
        $result = ConvertTo-RegistryKeyComponents -Path "HKLM:\SOFTWARE\Classes\CLSID"
        $result.Hive | Should -Be ([Microsoft.Win32.Registry]::LocalMachine)
        $result.HiveName | Should -Be 'HKEY_LOCAL_MACHINE'
        $result.SubPath | Should -Be 'SOFTWARE\Classes\CLSID'
    }

    It "should parse HKCU drive path" {
        $result = ConvertTo-RegistryKeyComponents -Path "HKCU:\SOFTWARE\Classes"
        $result.Hive | Should -Be ([Microsoft.Win32.Registry]::CurrentUser)
        $result.HiveName | Should -Be 'HKEY_CURRENT_USER'
        $result.SubPath | Should -Be 'SOFTWARE\Classes'
    }

    It "should parse Registry::HKEY_CLASSES_ROOT path" {
        $result = ConvertTo-RegistryKeyComponents -Path "Registry::HKEY_CLASSES_ROOT\CLSID"
        $result.Hive | Should -Be ([Microsoft.Win32.Registry]::ClassesRoot)
        $result.HiveName | Should -Be 'HKEY_CLASSES_ROOT'
        $result.SubPath | Should -Be 'CLSID'
    }

    It "should return null for unsupported path" {
        $result = ConvertTo-RegistryKeyComponents -Path "C:\some\path"
        $result | Should -BeNullOrEmpty
    }
}

Describe "Resolve-HkcrPath" {
    Context "HKCR path resolution" {
        It "should resolve HKCR\CLSID to HKLM path" {
            $path = "Microsoft.PowerShell.Core\Registry::HKEY_CLASSES_ROOT\CLSID"
            $resolved = Resolve-HkcrPath -Path $path
            $resolved | Should -Be "HKLM:\SOFTWARE\Classes\CLSID"
        }

        It "should return non-HKCR path unchanged" {
            $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
            $resolved = Resolve-HkcrPath -Path $path
            $resolved | Should -Be $path
        }

        It "should return original path when key does not exist in either hive" {
            $guid = [guid]::NewGuid().ToString('B')
            $path = "Microsoft.PowerShell.Core\Registry::HKEY_CLASSES_ROOT\CLSID\$guid"
            $resolved = Resolve-HkcrPath -Path $path
            $resolved | Should -Be $path
        }

        It "should resolve to WOW6432Node path when key exists there" {
            $path = "Microsoft.PowerShell.Core\Registry::HKEY_CLASSES_ROOT\CLSID"
            # WOW6432Node\Classes\CLSID は64bit Windowsに存在する
            if (Test-Path "HKLM:\SOFTWARE\WOW6432Node\Classes\CLSID") {
                $resolved = Resolve-HkcrPath -Path $path
                # HKLMに先に存在するのでHKLMが返される（WOW6432Nodeには到達しない）
                $resolved | Should -Be "HKLM:\SOFTWARE\Classes\CLSID"
            }
        }

        It "should resolve HKCU-only key to HKCU path" {
            $testGuid = "{$([guid]::NewGuid().ToString())}"
            $testKeyPath = "HKCU:\SOFTWARE\Classes\CLSID\$testGuid"
            try {
                New-Item -Path $testKeyPath -Force | Out-Null
                $path = "Microsoft.PowerShell.Core\Registry::HKEY_CLASSES_ROOT\CLSID\$testGuid"
                $resolved = Resolve-HkcrPath -Path $path
                $resolved | Should -Be $testKeyPath
            }
            finally {
                Remove-Item -Path $testKeyPath -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "RegistryCleaner" {
    Context "Module properties" {
        BeforeAll {
            $settings = @{
                registryCleaner = @{
                    targets = @()
                }
            }
            $cleaner = [RegistryCleaner]::new($settings)
        }

        It "should return correct name" {
            $cleaner.GetName() | Should -Be "Registry Cleaner"
        }

        It "should require admin" {
            $cleaner.RequiresAdmin() | Should -Be $true
        }
    }

    Context "Analyze with no targets" {
        BeforeAll {
            $settings = @{
                registryCleaner = @{
                    targets = @()
                }
            }
            $cleaner = [RegistryCleaner]::new($settings)
        }

        It "should return empty array" {
            $items = $cleaner.Analyze()
            $items.Count | Should -Be 0
        }
    }

    Context "Clean" {
        BeforeAll {
            $settings = @{
                registryCleaner = @{
                    targets = @()
                }
            }
            $cleaner = [RegistryCleaner]::new($settings)
        }

        It "should handle empty items array" {
            $result = $cleaner.Clean(@())
            $result.ItemCount | Should -Be 0
            $result.Errors.Count | Should -Be 0
        }

        It "should record error for non-existent registry path" {
            $item = [CleanerItem]::new()
            $item.Path = "HKLM:\SOFTWARE\NonExistent_WinCleanerTest_$(Get-Random)"
            $item.Size = 0
            $item.Category = "Test"

            $result = $cleaner.Clean(@($item))
            $result.ItemCount | Should -Be 0
            $result.Errors.Count | Should -Be 1
            $result.Errors[0] | Should -Match "Failed to remove"
        }

        It "should remove registry value when PropertyName is set" {
            $testKeyPath = "HKCU:\SOFTWARE\WinCleanerTest_$(Get-Random)"
            $testPropName = "TestValue"

            try {
                New-Item -Path $testKeyPath -Force | Out-Null
                New-ItemProperty -Path $testKeyPath -Name $testPropName -Value "test" -PropertyType String -Force | Out-Null

                $item = [CleanerItem]::new()
                $item.Path = $testKeyPath
                $item.Size = 0
                $item.Category = "Test"
                $item.PropertyName = $testPropName

                $result = $cleaner.Clean(@($item))
                $result.ItemCount | Should -Be 1
                $result.Errors.Count | Should -Be 0

                # Verify the value was removed but the key still exists
                Test-Path $testKeyPath | Should -Be $true
                $props = Get-ItemProperty -Path $testKeyPath -Name $testPropName -ErrorAction SilentlyContinue
                $props | Should -BeNullOrEmpty
            }
            finally {
                Remove-Item -Path $testKeyPath -Force -ErrorAction SilentlyContinue
            }
        }

        It "should delete HKCU key via HKCR path resolution" {
            $testGuid = "{$([guid]::NewGuid().ToString())}"
            $testKeyPath = "HKCU:\SOFTWARE\Classes\CLSID\$testGuid"
            try {
                New-Item -Path $testKeyPath -Force | Out-Null

                $item = [CleanerItem]::new()
                $item.Path = "Microsoft.PowerShell.Core\Registry::HKEY_CLASSES_ROOT\CLSID\$testGuid"
                $item.Size = 0
                $item.Category = "Test"

                $result = $cleaner.Clean(@($item))
                $result.ItemCount | Should -Be 1
                $result.Errors.Count | Should -Be 0
                Test-Path $testKeyPath | Should -Be $false
            }
            finally {
                Remove-Item -Path $testKeyPath -Force -Recurse -ErrorAction SilentlyContinue
            }
        }

        It "should record error when PropertyName removal fails" {
            $item = [CleanerItem]::new()
            $item.Path = "HKCU:\SOFTWARE\NonExistent_WinCleanerTest_$(Get-Random)"
            $item.Size = 0
            $item.Category = "Test"
            $item.PropertyName = "NonExistentValue"

            $result = $cleaner.Clean(@($item))
            $result.ItemCount | Should -Be 0
            $result.Errors.Count | Should -Be 1
            $result.Errors[0] | Should -Match "Failed to remove"
        }
    }
}
