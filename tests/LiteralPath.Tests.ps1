#Requires -Modules Pester
using module ..\modules\Core\ICleanerModule.psm1
using module ..\modules\TempCleaner\TempCleaner.psm1

# パス中のワイルドカード文字（角括弧）に対する回帰テスト。
#
# -Path はワイルドカードを解釈するため、file[1].txt の削除を指示すると
# file1.txt が消え、対象は残る。ブラウザーキャッシュでよく使われる名前
# なので一時ファイル削除では現実に踏む。

BeforeAll {
    Import-Module "$PSScriptRoot\..\modules\TempCleaner\TempCleanerRule.psm1" -Force
    Import-Module "$PSScriptRoot\..\modules\RegistryCleaner\RegistryCleanerRule.psm1" -Force
}

Describe "角括弧を含むパスの扱い" {
    Context "TempCleaner の削除" {
        BeforeEach {
            $script:workDir = Join-Path ([IO.Path]::GetTempPath()) ("wc-lit-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
            New-Item -ItemType Directory -Path $script:workDir | Out-Null
            $script:bracket = Join-Path $script:workDir 'file[1].txt'
            $script:plain = Join-Path $script:workDir 'file1.txt'
            Set-Content -LiteralPath $script:bracket -Value 'target'
            Set-Content -LiteralPath $script:plain -Value 'innocent'
        }

        AfterEach {
            if (Test-Path -LiteralPath $script:workDir) {
                Remove-Item -LiteralPath $script:workDir -Recurse -Force
            }
        }

        It "角括弧を含むファイルだけを削除し、展開先のファイルを巻き添えにしない" {
            $item = [CleanerItem]::new()
            $item.Path = $script:bracket
            $item.Size = 6

            $cleaner = [TempCleaner]::new(@{ tempCleaner = @{ targets = @(); excludePatterns = @() } })
            $result = $cleaner.Clean(@($item))

            $result.Errors.Count | Should -Be 0
            Test-Path -LiteralPath $script:bracket | Should -Be $false
            Test-Path -LiteralPath $script:plain | Should -Be $true
        }
    }

    Context "Test-InvalidRegistryReference" {
        BeforeEach {
            $script:workDir = Join-Path ([IO.Path]::GetTempPath()) ("wc-lit2-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
            New-Item -ItemType Directory -Path $script:workDir | Out-Null
        }

        AfterEach {
            if (Test-Path -LiteralPath $script:workDir) {
                Remove-Item -LiteralPath $script:workDir -Recurse -Force
            }
        }

        It "角括弧を含む実在ファイルを無効と判定しない" {
            $exe = Join-Path $script:workDir 'app[1].exe'
            Set-Content -LiteralPath $exe -Value 'x'

            Test-InvalidRegistryReference -Path $exe | Should -Be $false
        }

        It "実在しないファイルは無効と判定する" {
            $missing = Join-Path $script:workDir 'missing[1].exe'

            Test-InvalidRegistryReference -Path $missing | Should -Be $true
        }
    }
}
