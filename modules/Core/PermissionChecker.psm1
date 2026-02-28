function Test-AdminPrivilege {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-AdminPrivilege {
    param(
        [string]$ModuleName
    )

    if (-not (Test-AdminPrivilege)) {
        Write-Warning "$ModuleName requires administrator privileges."
        Write-Warning "Please run PowerShell as Administrator."
        return $false
    }
    return $true
}

Export-ModuleMember -Function Test-AdminPrivilege, Assert-AdminPrivilege
