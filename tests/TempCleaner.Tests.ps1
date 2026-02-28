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

    Context "Clean" {
        BeforeAll {
            $settings = @{
                tempCleaner = @{
                    targets         = @()
                    excludePatterns = @()
                }
            }
            $cleaner = [TempCleaner]::new($settings)
        }

        It "should handle empty items array" {
            $result = $cleaner.Clean(@())
            $result.ItemCount | Should -Be 0
            $result.FreedBytes | Should -Be 0
            $result.Errors.Count | Should -Be 0
        }

        It "should record error for non-existent file" {
            $item = [CleanerItem]::new()
            $item.Path = "C:\nonexistent_test_path_$(Get-Random)\file.tmp"
            $item.Size = 100
            $item.Category = "Test"

            $result = $cleaner.Clean(@($item))
            $result.ItemCount | Should -Be 0
            $result.Errors.Count | Should -Be 1
        }

        It "should delete existing file and update counters" {
            $tempDir = Join-Path $env:TEMP "win-cleaner-test-$(Get-Random)"
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
            $tempFile = Join-Path $tempDir "test.tmp"
            Set-Content -Path $tempFile -Value "test content"

            $item = [CleanerItem]::new()
            $item.Path = $tempFile
            $item.Size = (Get-Item $tempFile).Length
            $item.Category = "Test"

            $result = $cleaner.Clean(@($item))
            $result.ItemCount | Should -Be 1
            $result.FreedBytes | Should -BeGreaterThan 0
            $result.Errors.Count | Should -Be 0
            Test-Path $tempFile | Should -Be $false

            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
