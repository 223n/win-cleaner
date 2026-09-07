class CleanerResult {
    [int]$ItemCount
    [long]$FreedBytes
    [string[]]$Errors
    # 削除前の控えの保存先。取得しないモジュールでは空のまま
    [string]$BackupPath

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
    [string]$PropertyName
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
