#Requires -Modules Pester

BeforeAll {
    Import-Module "$PSScriptRoot\..\modules\Core\PermissionChecker.psm1" -Force
}

Describe "PermissionChecker" {
    Context "Test-AdminPrivilege" {
        It "should return a boolean" {
            $result = Test-AdminPrivilege
            $result | Should -BeOfType [bool]
        }
    }

    Context "Assert-AdminPrivilege" {
        It "should return a boolean" {
            $result = Assert-AdminPrivilege -ModuleName "TestModule" 3>$null
            $result | Should -BeOfType [bool]
        }

        It "should accept ModuleName parameter" {
            { Assert-AdminPrivilege -ModuleName "TestModule" 3>$null } | Should -Not -Throw
        }
    }
}
