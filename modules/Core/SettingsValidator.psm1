function Test-SettingsSchema {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings
    )

    $errors = [System.Collections.Generic.List[string]]::new()

    # tempCleanerセクション
    if (-not $Settings.ContainsKey('tempCleaner')) {
        $errors.Add("Missing required section: 'tempCleaner'")
    }
    else {
        $tc = $Settings.tempCleaner
        if ($tc.targets -is [System.Collections.IEnumerable]) {
            for ($i = 0; $i -lt $tc.targets.Count; $i++) {
                $t = $tc.targets[$i]
                foreach ($field in @('category', 'path', 'pattern', 'recurse')) {
                    if (-not $t.ContainsKey($field)) {
                        $errors.Add("tempCleaner.targets[$i]: missing required field '$field'")
                    }
                }
            }
        }
    }

    # registryCleanerセクション
    if (-not $Settings.ContainsKey('registryCleaner')) {
        $errors.Add("Missing required section: 'registryCleaner'")
    }
    else {
        $rc = $Settings.registryCleaner
        $validRules = @('invalidFileReference', 'invalidAppPath', 'invalidCOMReference', 'invalidTypeLib', 'invalidFileAssociation', 'invalidStartupEntry', 'invalidMUICache')
        if ($rc.targets -is [System.Collections.IEnumerable]) {
            for ($i = 0; $i -lt $rc.targets.Count; $i++) {
                $t = $rc.targets[$i]
                foreach ($field in @('category', 'keyPath', 'rule')) {
                    if (-not $t.ContainsKey($field)) {
                        $errors.Add("registryCleaner.targets[$i]: missing required field '$field'")
                    }
                }
                if ($t.ContainsKey('rule') -and $t.rule -notin $validRules) {
                    $errors.Add("registryCleaner.targets[$i]: invalid rule '$($t.rule)' (must be one of: $($validRules -join ', '))")
                }
            }
        }
    }

    if ($errors.Count -gt 0) {
        throw "Settings validation failed:`n  - $($errors -join "`n  - ")"
    }
}

Export-ModuleMember -Function Test-SettingsSchema
