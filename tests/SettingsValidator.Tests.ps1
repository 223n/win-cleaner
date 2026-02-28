#Requires -Modules Pester

BeforeAll {
    Import-Module "$PSScriptRoot\..\modules\Core\SettingsValidator.psm1" -Force
}

Describe "Test-SettingsSchema" {
    Context "Valid settings" {
        It "should pass with complete settings" {
            $settings = @{
                tempCleaner = @{
                    targets = @(
                        @{
                            category = "Test"
                            path     = "C:\temp"
                            pattern  = "*"
                            recurse  = $true
                        }
                    )
                    excludePatterns = @()
                }
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

            { Test-SettingsSchema -Settings $settings } | Should -Not -Throw
        }

        It "should pass with empty targets arrays" {
            $settings = @{
                tempCleaner = @{
                    targets = @()
                }
                registryCleaner = @{
                    targets = @()
                }
            }

            { Test-SettingsSchema -Settings $settings } | Should -Not -Throw
        }
    }

    Context "Missing sections" {
        It "should fail when tempCleaner section is missing" {
            $settings = @{
                registryCleaner = @{ targets = @() }
            }

            { Test-SettingsSchema -Settings $settings } | Should -Throw "*Missing required section: 'tempCleaner'*"
        }

        It "should fail when registryCleaner section is missing" {
            $settings = @{
                tempCleaner = @{ targets = @() }
            }

            { Test-SettingsSchema -Settings $settings } | Should -Throw "*Missing required section: 'registryCleaner'*"
        }

        It "should report both missing sections at once" {
            $settings = @{}

            { Test-SettingsSchema -Settings $settings } | Should -Throw "*tempCleaner*registryCleaner*"
        }
    }

    Context "Missing fields" {
        It "should fail when tempCleaner target is missing required fields" {
            $settings = @{
                tempCleaner = @{
                    targets = @(
                        @{ category = "Test" }
                    )
                }
                registryCleaner = @{ targets = @() }
            }

            { Test-SettingsSchema -Settings $settings } | Should -Throw "*missing required field 'path'*"
        }

        It "should fail when registryCleaner target is missing required fields" {
            $settings = @{
                tempCleaner = @{ targets = @() }
                registryCleaner = @{
                    targets = @(
                        @{ category = "Test" }
                    )
                }
            }

            { Test-SettingsSchema -Settings $settings } | Should -Throw "*missing required field 'keyPath'*"
        }
    }

    Context "Invalid rule values" {
        It "should fail for unknown rule value" {
            $settings = @{
                tempCleaner = @{ targets = @() }
                registryCleaner = @{
                    targets = @(
                        @{
                            category = "Test"
                            keyPath  = "HKLM:\SOFTWARE\Test"
                            rule     = "unknownRule"
                        }
                    )
                }
            }

            { Test-SettingsSchema -Settings $settings } | Should -Throw "*invalid rule 'unknownRule'*"
        }

        It "should accept invalidFileReference rule" {
            $settings = @{
                tempCleaner = @{ targets = @() }
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

            { Test-SettingsSchema -Settings $settings } | Should -Not -Throw
        }

        It "should accept invalidAppPath rule" {
            $settings = @{
                tempCleaner = @{ targets = @() }
                registryCleaner = @{
                    targets = @(
                        @{
                            category = "Test"
                            keyPath  = "HKLM:\SOFTWARE\Test"
                            rule     = "invalidAppPath"
                        }
                    )
                }
            }

            { Test-SettingsSchema -Settings $settings } | Should -Not -Throw
        }

        It "should accept all new registry cleaner rules" {
            $newRules = @('invalidCOMReference', 'invalidTypeLib', 'invalidFileAssociation', 'invalidStartupEntry', 'invalidMUICache')
            foreach ($rule in $newRules) {
                $settings = @{
                    tempCleaner = @{ targets = @() }
                    registryCleaner = @{
                        targets = @(
                            @{
                                category = "Test"
                                keyPath  = "HKLM:\SOFTWARE\Test"
                                rule     = $rule
                            }
                        )
                    }
                }

                { Test-SettingsSchema -Settings $settings } | Should -Not -Throw
            }
        }
    }
}
