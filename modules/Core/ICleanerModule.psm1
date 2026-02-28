class CleanerResult {
    [int]$ItemCount
    [long]$FreedBytes
    [string[]]$Errors

    CleanerResult() {
        $this.ItemCount = 0
        $this.FreedBytes = 0
        $this.Errors = @()
    }
}

class CleanerItem {
    [string]$Path
    [long]$Size
    [string]$Category
}

class ICleanerModule {
    [string] GetName() {
        throw "GetName() must be overridden"
    }

    [string] GetDescription() {
        throw "GetDescription() must be overridden"
    }

    [bool] RequiresAdmin() {
        throw "RequiresAdmin() must be overridden"
    }

    [CleanerItem[]] Analyze() {
        throw "Analyze() must be overridden"
    }

    [CleanerResult] Clean([CleanerItem[]]$items) {
        throw "Clean() must be overridden"
    }
}

Export-ModuleMember -Function @()
