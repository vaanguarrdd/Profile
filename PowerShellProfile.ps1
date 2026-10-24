If (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
    Return
}
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
                Uri     = $LatestReleaseInformation.assets.url
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

Register-ArgumentCompleter -Native -CommandName 'wslc', 'wslc.exe', 'docker', 'wc' -ScriptBlock {
    Param(
        $wordToComplete,
        $commandAst,
        $cursorPosition
    )

    $rootCommands = @{
        'attach'    = 'Attach to a container'
        'build'     = 'Build an image from a Dockerfile'
        'container' = 'Manage containers'
        'create'    = 'Create a container'
        'exec'      = 'Execute a command in a running container'
        'export'    = 'Export a container filesystem as a tar archive'
        'image'     = 'Manage images'
        'images'    = 'List images'
        'import'    = 'Import an image from a tarball'
        'info'      = 'Display system information'
        'inspect'   = 'Inspect objects'
        'kill'      = 'Kill one or more running containers'
        'list'      = 'List containers'
        'load'      = 'Load images'
        'login'     = 'Log in to a registry'
        'logout'    = 'Log out from a registry'
        'logs'      = 'View container logs'
        'network'   = 'Manage networks'
        'pull'      = 'Pull images'
        'push'      = 'Upload an image to a registry'
        'registry'  = 'Manage registry credentials'
        'remove'    = 'Remove containers'
        'rmi'       = 'Remove images'
        'run'       = 'Run a container'
        'save'      = 'Save images'
        'settings'  = 'Open the settings file in default editor'
        'start'     = 'Start a container'
        'stats'     = 'Display container resource usage statistics'
        'stop'      = 'Stop containers'
        'system'    = 'System-level commands'
        'tag'       = 'Tag an image'
        'version'   = 'Show version information'
        'volume'    = 'Manage volumes'
    }

    $subCommands = @{
        'container' = @('attach', 'cp', 'create', 'exec', 'export', 'inspect', 'kill', 'list', 'logs', 'prune', 'remove', 'run', 'start', 'stats', 'stop')
        'image'     = @('build', 'import', 'inspect', 'list', 'load', 'prune', 'pull', 'push', 'remove', 'save', 'tag')
        'network'   = @('connect', 'create', 'disconnect', 'inspect', 'list', 'prune', 'remove')
        'volume'    = @('create', 'inspect', 'list', 'prune', 'remove')
        'system'    = @('info', 'session')
        'registry'  = @('login', 'logout')
    }

    $elements = @($commandAst.CommandElements)
    if ($elements.Count -eq 0) {
        return
    }

    if ($cursorPosition -gt $elements[-1].Extent.EndOffset) {
        $argIndex = $elements.Count
        $prevArgs = @(if ($elements.Count -gt 1) { $elements[1..($elements.Count - 1)] | ForEach-Object { $_.Extent.Text } })
    }
    else {
        $argIndex = $elements.Count - 1
        $prevArgs = @(if ($elements.Count -gt 2) { $elements[1..($elements.Count - 2)] | ForEach-Object { $_.Extent.Text } })
    }

    $getContainers = {
        $raw = wslc list -a --format json 2>$null
        if ($raw) {
            foreach ($line in $raw) {
                try {
                    $c = $line | ConvertFrom-Json
                    if ($c.Names -and $c.Names -like "$wordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new(
                            $c.Names,
                            $c.Names,
                            'ParameterValue',
                            "Container: $($c.Names) ($($c.Image)) [$($c.State)]"
                        )
                    }
                    if ($c.ID -and $c.ID -like "$wordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new(
                            $c.ID,
                            $c.ID,
                            'ParameterValue',
                            "Container: $($c.ID) ($($c.Names)) [$($c.State)]"
                        )
                    }
                }
                catch {}
            }
        }
    }

    $getImages = {
        $raw = wslc images --format json 2>$null
        if ($raw) {
            foreach ($line in $raw) {
                try {
                    $img = $line | ConvertFrom-Json
                    $tag = if ($img.Repository -and $img.Tag) { "$($img.Repository):$($img.Tag)" } else { $null }
                    if ($tag -and $tag -like "$wordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new(
                            $tag,
                            $tag,
                            'ParameterValue',
                            "Image: $tag ($($img.ID))"
                        )
                    }
                    if ($img.ID -and $img.ID -like "$wordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new(
                            $img.ID,
                            $img.ID,
                            'ParameterValue',
                            "Image ID: $($img.ID) ($tag)"
                        )
                    }
                }
                catch {}
            }
        }
    }

    if ($argIndex -eq 1) {
        $rootCommands.GetEnumerator() |
        Where-Object { $_.Key -like "$wordToComplete*" } |
        Sort-Object Key |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_.Key,
                $_.Key,
                'Command',
                $_.Value
            )
        }
        return
    }

    $primary = $prevArgs[0]

    if ($argIndex -eq 2) {
        if ($subCommands.ContainsKey($primary)) {
            $subCommands[$primary] |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_,
                    $_,
                    'ParameterValue',
                    "$primary $_"
                )
            }
            return
        }

        if ($primary -in @('attach', 'exec', 'kill', 'logs', 'remove', 'start', 'stop', 'inspect')) {
            & $getContainers
            return
        }

        if ($primary -in @('run', 'rmi', 'tag', 'push')) {
            & $getImages
            return
        }
    }

    if ($argIndex -eq 3) {
        $sub = $prevArgs[1]
        if ($primary -eq 'container' -and $sub -in @('attach', 'exec', 'kill', 'logs', 'remove', 'start', 'stop', 'inspect')) {
            & $getContainers
            return
        }

        if ($primary -eq 'image' -and $sub -in @('remove', 'inspect', 'tag', 'push')) {
            & $getImages
            return
        }
    }
}

$Aliases = @{
    scf    = 'Stop-ComputerForce'
    rcf    = 'Restart-ComputerForce'
    lsf    = 'Get-ChildItemForce'
    lsa    = 'Get-ChildItemAll'
    eo     = 'Expand-Object'
    fla    = 'Format-ListAll'
    b64e   = 'ConvertTo-Base64'
    b64d   = 'ConvertFrom-Base64'
    rf     = 'ConvertTo-DangerousURI'
    df     = 'ConvertTo-SafeURI'
    chef   = 'Start-LocalCyberChef'
    rsp    = 'Restart-Profile'
    cat    = 'bat'
    vi     = 'nvim'
    vim    = 'nvim'
    ghd    = 'GithubDesktop'
    s      = 'Set-Clipboard'
    docker = 'wslc'
    gj     = 'Get-Job'
    rcj    = 'Receive-Job'
    sj     = 'Stop-Job'
    rj     = 'Remove-Job'
    wc     = 'wslc'
}

$Aliases.GetEnumerator() | ForEach-Object { 
    Set-Alias -Name $_.Key -Value $_.Value 
}

If (Get-Command -Name 'starship' -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (starship init powershell | Out-String) })
}
If (Get-Command -Name 'zoxide' -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell --cmd cd | Out-String) })
}
If (Get-Command -Name 'minikube' -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (minikube completion powershell | Out-String) })
}
If (Get-Command -Name 'kubectl' -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (kubectl completion powershell | Out-String) })
}
If (Get-Command -Name 'helm' -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (helm completion powershell | Out-String) })
}

If (Select-String -Path "$Env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" -Pattern '"colorScheme": "Solarized Light"' -Quiet) {
    Set-PSReadLineOption -Colors @{
        Number             = "`e[39m"
        ContinuationPrompt = "`e[39m"
        Member             = "`e[39m"
        Type               = "`e[39m"
    }
}

Start-Job -Name Prevent-Idle -ScriptBlock {
    $Shell = New-Object -ComObject Wscript.Shell
    While ($True) {
        $Shell.SendKeys('{SCROLLLOCK}')
        Start-Sleep -Milliseconds 200
        $Shell.SendKeys('{SCROLLLOCK}')
        Start-Sleep -Seconds 240
    }
}