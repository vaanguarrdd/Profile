Function Stop-ComputerForce { Stop-Computer -Force }
Function Restart-ComputerForce { Restart-Computer -Force }
Function Restart-Profile { 
    Copy-Item -Path "$Env:OneDrive\SourceControl\Profile\PowerShellProfile.ps1" -Destination $PROFILE -Force
    .$PROFILE 
}
Filter Format-ListAll (
    [Parameter(ValueFromPipeline)]
    $InputObject
) {
    $InputObject | Format-List *
}
Filter Expand-Object (
    [Parameter(Mandatory)]
    [String]
    $Property,
    [Parameter(ValueFromPipeline)]
    $InputObject 
) { 
    $InputObject | Select-Object -ExpandProperty $Property
}
Filter ConvertTo-Base64 (
    [Parameter(ValueFromPipeline)]
    [String]
    $InputObject,
    [Parameter()]
    [Switch]
    $UrlSafe
) {
    $EncodedString = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($InputObject))
    If ($UrlSafe.IsPresent) {
        $EncodedString = $EncodedString.TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }
    $EncodedString
}
Filter ConvertFrom-Base64 (
    [Parameter(ValueFromPipeline)]
    $InputObject
) {
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($InputObject))
}
Filter Get-ChildItemForce (
    [Parameter(
        ValueFromPipeline,
        ValueFromPipelineByPropertyName
    )]
    [String]
    $Path
) {
    Get-ChildItem -Path $Path -Force
}
Filter Get-ChildItemAll (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [String]
    $InputObject,
    [Parameter()]
    [String]
    $Path = 'C:\'
) {
    Get-ChildItem -Path $Path -Recurse -Filter *$InputObject* -ErrorAction SilentlyContinue
}
Filter ConvertTo-DangerousURI (
    [Parameter(ValueFromPipeline)]
    [String]
    $InputObject
) {
    $InputObject.Replace('[.]', '.').Replace('[d]', '.').Replace('[dot]', '.').Replace('hxxp', 'http')
}
Filter ConvertTo-SafeURI (
    [Parameter(ValueFromPipeline)]
    [String]
    $InputObject
) {
    $InputObject.Replace('.', '[.]').Replace('http', 'hxxp')
}
Filter Hide-Item (
    [Parameter(
        Mandatory,
        ValueFromPipeline
    )]
    [ValidateScript({ Test-Path -Path $PSItem })]
    $Path
) {
    $Path.Attributes = $Path.Attributes -bor "Hidden"
}
Function Get-NixOSWSL {
    [CmdletBinding()]
    Param (
        [Parameter()]
        [String]
        $NixOSPath = "C:\Users\$Env:UserName\NixOS\nixos-wsl.tar.gz",
        [Parameter()]
        [String]
        $NixOSLatestRelease = 'https://api.github.com/repos/nix-community/NixOS-WSL/releases/latest',
        [Parameter()]
        [Switch]
        $AsDefault
    )
    Begin {
        If (Test-Path -Path ($NixOSPath)) {
            Write-Warning -Message "A NixOS archive already exists as $NixOSPath"
            $UseLocal = $True
        }
    }
    Process {
        If (!$UseLocal) {
            $NixOSParameters = @{
                Headers = @{
                    Accept = 'application/octet-stream'
                }
                Uri     = (Invoke-RestMethod -Uri $NixOSLatestRelease).assets.Where({ $_.Name -eq 'nixos-wsl.tar.gz' }).url
                Outfile = $NixOSPath
            }
            Invoke-RestMethod @NixOSParameters
        }
    }
    End {
        Start-Process wsl -ArgumentList "--import NixOS $((Get-Item $NixOSPath).Directory) $NixOSPath --version 2" -Wait -NoNewWindow

        If ($AsDefault.IsPresent) {
            Start-Process wsl -ArgumentList "--set-default NixOS" -Wait -NoNewWindow
        }
    }
}
Function Start-LocalCyberChef {
    [CmdletBinding()]
    Param (
        [Parameter()]
        [String]
        $CyberChefLatestRelease,
        [Parameter()]
        [String]
        $CyberChefDirectory = "C:\Users\$Env:UserName\CyberChef\"
    )
    Begin {
        New-Item -ItemType Directory -Path $CyberChefDirectory -Force | Out-Null

        $LatestReleaseInformation = Invoke-RestMethod -Uri $CyberChefLatestRelease
    }
    Process {
        If ("$(Get-ChildItem $CyberChefDirectory*html -Name)" -notmatch $LatestReleaseInformation.tag_name) {
            $CyberChefParameters = @{
                Headers = @{
                    Accept = 'application/octet-stream'
                }
                Uri = $LatestReleaseInformation.assets.url
                OutFile = $CyberChefDirectory + 'CyberChef.zip'
            }
            Invoke-RestMethod @CyberChefParameters

            Expand-Archive -Path ($CyberChefDirectory + 'CyberChef.zip') -DestinationPath $CyberChefDirectory -Force
        }
        Invoke-Item $CyberChefDirectory*html
    }
    End {

    }
}

Set-Alias -Name scf -Value Stop-ComputerForce
Set-Alias -Name rcf -Value Restart-ComputerForce
Set-Alias -Name lsf -Value Get-ChildItemForce
Set-Alias -Name lsa -Value Get-ChildItemAll
Set-Alias -Name eo -Value Expand-Object
Set-Alias -Name fla -Value Format-ListAll
Set-Alias -Name b64e -Value ConvertTo-Base64
Set-Alias -Name b64d -Value ConvertFrom-Base64
Set-Alias -Name rf -Value ConvertTo-DangerousURI
Set-Alias -Name df -Value ConvertTo-SafeURI
Set-Alias -Name chef -Value Start-LocalCyberChef
Set-Alias -Name rsp -Value Restart-Profile
Set-Alias -Name cat -Value bat
Set-Alias -Name vi -Value nvim
Set-Alias -Name vim -Value nvim
Set-Alias -Name ghd -Value GithubDesktop
Set-Alias -Name s -Value Set-Clipboard

zoxide init powershell --cmd cd | Out-String | Invoke-Expression
starship init powershell --print-full-init | Out-String | Invoke-Expression
If (Select-String -Path "$Env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Pattern '"colorScheme": "Solarized Light"' -Quiet) {
    Set-PSReadLineOption -Colors @{
        Number = $PSStyle.Foreground.Green
    }
}

Start-Job -Name RemoteDesktopFix -ScriptBlock {
    $RemoteDesktopScheduledTask = Get-ScheduledTask -TaskPath \RemoteDesktop* 
    If ($RemoteDesktopScheduledTask.State -ne 'Disabled') {
        $RemoteDesktopScheduledTask | Disable-ScheduledTask
    }
    Start-Sleep -Seconds 300
} | Out-Null
