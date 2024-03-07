[CmdletBinding()]
Param (
    [Parameter()]
    [ValidateScript({
        Test-Path $PSItem
    })]
    [String]
    $ProfilePath = $PSScriptRoot + "\PowerShellProfile.ps1"
)
Begin {

}
Process {
    Copy-Item -Path $ProfilePath -Destination $Profile -Force
}
End {

}