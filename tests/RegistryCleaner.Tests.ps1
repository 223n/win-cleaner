#Requires -Modules Pester

BeforeAll {
    using module ..\modules\Core\ICleanerModule.psm1
    using module ..\modules\RegistryCleaner\RegistryCleaner.psm1
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
}
