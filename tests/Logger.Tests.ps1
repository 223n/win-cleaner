#Requires -Modules Pester
using module ..\modules\Core\ICleanerModule.psm1
using module ..\modules\Core\Logger.psm1

Describe "Logger" {
    BeforeAll {
        $testDir = Join-Path $env:TEMP "win-cleaner-test-$(Get-Random)"
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $testDir) {
            Remove-Item -Path $testDir -Recurse -Force
        }
    }

    Context "Initialization" {
        It "should create logs directory" {
            $logger = [Logger]::new($testDir)
            Test-Path (Join-Path $testDir "logs") | Should -Be $true
        }

        It "should set log file path with timestamp" {
            $logger = [Logger]::new($testDir)
            $logger.LogPath | Should -Match "win-cleaner_\d{8}_\d{6}\.log"
        }
    }

    Context "Write" {
        It "should write timestamped entry to log file" {
            $logger = [Logger]::new($testDir)
            $logger.Write("test message")
            $content = Get-Content $logger.LogPath -Raw
            $content | Should -Match "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] test message"
        }
    }

    Context "WriteAnalyzeResult" {
        It "should log 'No items found' for empty array" {
            $logger = [Logger]::new($testDir)
            $logger.WriteAnalyzeResult("TestModule", @())
            $content = Get-Content $logger.LogPath -Raw
            $content | Should -Match "No items found"
        }

        It "should log grouped results for items" {
            $logger = [Logger]::new($testDir)
            $item = [CleanerItem]::new()
            $item.Path = "C:\test\file.tmp"
            $item.Size = 1024
            $item.Category = "Test Category"
            $logger.WriteAnalyzeResult("TestModule", @($item))
            $content = Get-Content $logger.LogPath -Raw
            $content | Should -Match "Test Category: 1 items"
            $content | Should -Match "Total: 1 items"
        }
    }

    Context "WriteCleanResult" {
        It "should log clean results" {
            $logger = [Logger]::new($testDir)
            $result = [CleanerResult]::new()
            $result.ItemCount = 5
            $result.FreedBytes = 2048
            $logger.WriteCleanResult("TestModule", $result)
            $content = Get-Content $logger.LogPath -Raw
            $content | Should -Match "Removed: 5 items"
        }

        It "should log errors when present" {
            $logger = [Logger]::new($testDir)
            $result = [CleanerResult]::new()
            $result.ItemCount = 1
            $result.FreedBytes = 512
            $result.Errors = @("Failed to delete: test.tmp")
            $logger.WriteCleanResult("TestModule", $result)
            $content = Get-Content $logger.LogPath -Raw
            $content | Should -Match "Errors: 1"
            $content | Should -Match "Failed to delete: test.tmp"
        }
    }

    Context "WriteDryRun" {
        It "should log dry run entries" {
            $logger = [Logger]::new($testDir)
            $item = [CleanerItem]::new()
            $item.Path = "C:\test\file.tmp"
            $item.Size = 512
            $item.Category = "Test"
            $logger.WriteDryRun("TestModule", @($item))
            $content = Get-Content $logger.LogPath -Raw
            $content | Should -Match "\[DryRun\] Would delete: C:\\test\\file.tmp"
        }
    }
}
