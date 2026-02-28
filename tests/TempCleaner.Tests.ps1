#Requires -Modules Pester
using module ..\modules\Core\ICleanerModule.psm1
using module ..\modules\TempCleaner\TempCleaner.psm1

BeforeAll {
    Import-Module "$PSScriptRoot\..\modules\TempCleaner\TempCleanerRule.psm1" -Force
}

Describe "TempCleanerRule" {
    Context "Test-ExcludedPath" {
        It "should return true for matching exclude pattern" {
            Test-ExcludedPath -FilePath "C:\temp\test.sys" -ExcludePatterns @("*.sys") | Should -Be $true
        }

        It "should return false for non-matching pattern" {
            Test-ExcludedPath -FilePath "C:\temp\test.tmp" -ExcludePatterns @("*.sys") | Should -Be $false
        }

        It "should return false for empty exclude patterns" {
            Test-ExcludedPath -FilePath "C:\temp\test.tmp" -ExcludePatterns @() | Should -Be $false
        }
    }

    Context "Get-TempCleanerTargets" {
        It "should expand environment variables" {
            $settings = @{
                tempCleaner = @{
                    targets = @(
                        @{
                            category = "Test"
                            path     = "%TEMP%"
                            pattern  = "*"
                            recurse  = $true
                        }
                    )
                }
            }

            $targets = Get-TempCleanerTargets -Settings $settings
            $targets.Count | Should -BeGreaterThan 0
            $targets[0].Path | Should -Not -BeLike "*%*"
        }
    }
}

Describe "TempCleaner" {
    Context "Module properties" {
        BeforeAll {
            $settings = @{
                tempCleaner = @{
                    targets         = @()
                    excludePatterns = @()
                }
            }
            $cleaner = [TempCleaner]::new($settings)
        }

        It "should return correct name" {
            $cleaner.GetName() | Should -Be "Temp Cleaner"
        }

        It "should not require admin" {
            $cleaner.RequiresAdmin() | Should -Be $false
        }
    }

    Context "Analyze with no targets" {
        BeforeAll {
            $settings = @{
                tempCleaner = @{
                    targets         = @()
                    excludePatterns = @()
                }
            }
            $cleaner = [TempCleaner]::new($settings)
        }

        It "should return empty array" {
            $items = $cleaner.Analyze()
            $items.Count | Should -Be 0
        }
    }
}
