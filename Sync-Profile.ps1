<#
.SYNOPSIS
    Synchronizes the active user PowerShell profile with the repository.
.DESCRIPTION
    Creates or updates the $PROFILE script with a lightweight dot-sourcing shim
    pointing directly to the repository's PowerShellProfile.ps1. This ensures all profile
    modifications made in the repository take effect immediately in new terminal sessions
    without requiring manual file copying.
    Also stops and removes any legacy background jobs named 'Prevent-Idle'.
.PARAMETER ProfilePath
    The path to the source PowerShellProfile.ps1 file. Defaults to PowerShellProfile.ps1
    located in the same folder as this script.
.EXAMPLE
    .\Sync-Profile.ps1
    Connects the current user's $PROFILE to the repository's PowerShellProfile.ps1.
.EXAMPLE
    .\Sync-Profile.ps1 -ProfilePath 'C:\Custom\PowerShellProfile.ps1'
    Configures $PROFILE to dot-source a specific profile path.
#>
[CmdletBinding()]
Param (
    [Parameter()]
    [ValidateScript({
        Test-Path -LiteralPath $PSItem
    })]
    [String]
    $ProfilePath = "$PSScriptRoot\PowerShellProfile.ps1"
)
Begin {
    $ResolvedPath = (Resolve-Path -LiteralPath $ProfilePath).Path
    $ProfileDirectory = Split-Path -Path $PROFILE -Parent

    If (-not (Test-Path -LiteralPath $ProfileDirectory)) {
        New-Item -ItemType Directory -Path $ProfileDirectory -Force | Out-Null
    }
}
Process {
    $ShimContent = @"
If (Test-Path -LiteralPath '$ResolvedPath') {
    . '$ResolvedPath'
}
"@

    $ContentParameters = @{
        LiteralPath = $PROFILE
        Value       = $ShimContent
        Encoding    = 'UTF8'
        Force       = $True
    }
    Set-Content @ContentParameters
}
End {
    Get-Job -Name 'Prevent-Idle' -ErrorAction SilentlyContinue | Stop-Job -PassThru | Remove-Job -Force -ErrorAction SilentlyContinue
}
