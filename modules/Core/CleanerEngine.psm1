using module .\ICleanerModule.psm1

class CleanerEngine {
    [System.Collections.Generic.List[ICleanerModule]]$Modules

    CleanerEngine() {
        $this.Modules = [System.Collections.Generic.List[ICleanerModule]]::new()
    }

    [void] Register([ICleanerModule]$module) {
        $this.Modules.Add($module)
    }

    [hashtable[]] GetModuleList() {
        $list = @()
        for ($i = 0; $i -lt $this.Modules.Count; $i++) {
            $m = $this.Modules[$i]
            $list += @{
                Index       = $i + 1
                Name        = $m.GetName()
                Description = $m.GetDescription()
                Admin       = $m.RequiresAdmin()
            }
        }
        return $list
    }

    [CleanerItem[]] AnalyzeModule([int]$index) {
        if ($index -lt 0 -or $index -ge $this.Modules.Count) {
            throw "Invalid module index: $index"
        }
        return $this.Modules[$index].Analyze()
    }

    [CleanerResult] CleanModule([int]$index, [CleanerItem[]]$items) {
        if ($index -lt 0 -or $index -ge $this.Modules.Count) {
            throw "Invalid module index: $index"
        }
        return $this.Modules[$index].Clean($items)
    }
}

Export-ModuleMember -Function @()
