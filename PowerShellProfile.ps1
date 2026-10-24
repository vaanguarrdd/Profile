If (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
    Return
}

$ProfileRoot = If ($PSScriptRoot) {
    $PSScriptRoot
}
ElseIf ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent -Path $MyInvocation.MyCommand.Path
}
Else {
    "$Env:OneDrive\SourceControl\Profile"
}

Function Stop-ComputerForce {
    <#
    .SYNOPSIS
        Immediately shuts down the local computer without confirmation.
    .DESCRIPTION
        Wraps the Stop-Computer cmdlet with the -Force parameter to initiate
        an immediate system shutdown.
    .EXAMPLE
        Stop-ComputerForce
        Shuts down the machine immediately.
    .EXAMPLE
        scf
        Uses the profile alias to shut down the machine.
    #>
    Stop-Computer -Force
}

Function Restart-ComputerForce {
    <#
    .SYNOPSIS
        Immediately restarts the local computer without confirmation.
    .DESCRIPTION
        Wraps the Restart-Computer cmdlet with the -Force parameter to initiate
        an immediate system reboot.
    .EXAMPLE
        Restart-ComputerForce
        Restarts the machine immediately.
    .EXAMPLE
        rcf
        Uses the profile alias to reboot the machine.
    #>
    Restart-Computer -Force
}

Function Restart-Profile {
    <#
    .SYNOPSIS
        Reloads the active PowerShell profile in the current session.
    .DESCRIPTION
        Ensures the profile dot-sourcing shim exists by calling Sync-Profile.ps1
        if needed, then dot-sources $PROFILE to refresh aliases, functions,
        and environment settings without opening a new window.
    .EXAMPLE
        Restart-Profile
        Reloads the profile into the current PowerShell session.
    .EXAMPLE
        rsp
        Uses the profile alias to reload the profile.
    #>
    $SyncScript = Join-Path -Path $ProfileRoot -ChildPath 'Sync-Profile.ps1'
    If (-not (Test-Path -LiteralPath $PROFILE) -and (Test-Path -LiteralPath $SyncScript)) {
        & $SyncScript
    }
    . $PROFILE
}

Filter Format-ListAll (
    [Parameter(ValueFromPipeline)]
    $InputObject
) {
    <#
    .SYNOPSIS
        Formats pipeline input objects as a list showing all properties.
    .DESCRIPTION
        Passes incoming pipeline objects directly to Format-List -Property *
        to inspect complete object metadata and hidden properties.
    .PARAMETER InputObject
        The object or collection of objects piped into the filter.
    .EXAMPLE
        Get-Process explorer | Format-ListAll
        Displays all properties of the explorer process in list format.
    .EXAMPLE
        Get-Item .\file.txt | fla
        Uses the profile alias to display all file attributes and timestamps.
    #>
    $InputObject | Format-List -Property *
}

Filter Expand-Object (
    [Parameter(Mandatory)]
    [String]
    $Property,
    [Parameter(ValueFromPipeline)]
    $InputObject
) {
    <#
    .SYNOPSIS
        Extracts and unwraps a specific property from incoming pipeline objects.
    .DESCRIPTION
        Pipes incoming objects to Select-Object -ExpandProperty to yield the raw,
        unwrapped value of the specified property instead of a PSObject wrapper.
    .PARAMETER Property
        The name of the property to expand from each object.
    .PARAMETER InputObject
        The object or collection of objects piped into the filter.
    .EXAMPLE
        Get-Service | Expand-Object -Property Name
        Outputs an array of service name strings.
    .EXAMPLE
        Get-ChildItem | eo FullName
        Uses the profile alias to extract full path strings.
    #>
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
    <#
    .SYNOPSIS
        Encodes a UTF-8 string into standard or URL-safe Base64.
    .DESCRIPTION
        Converts the incoming string to UTF-8 bytes and generates a Base64-encoded
        string. When -UrlSafe is supplied, replaces '+' with '-', '/' with '_',
        and removes trailing '=' padding characters.
    .PARAMETER InputObject
        The string to encode into Base64.
    .PARAMETER UrlSafe
        Produces a URL-safe Base64 string compliant with RFC 4648 §5.
    .EXAMPLE
        'Hello World' | ConvertTo-Base64
        Outputs: SGVsbG8gV29ybGQ=
    .EXAMPLE
        'Hello World' | b64e -UrlSafe
        Outputs: SGVsbG8gV29ybGQ
    #>
    $EncodedString = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($InputObject))
    If ($UrlSafe.IsPresent) {
        $EncodedString = $EncodedString.TrimEnd('=').Replace('+', '-').Replace('/', '_')
    }
    $EncodedString
}

Filter ConvertFrom-Base64 (
    [Parameter(ValueFromPipeline)]
    [String]
    $InputObject
) {
    <#
    .SYNOPSIS
        Decodes a standard or URL-safe Base64 string into UTF-8 text.
    .DESCRIPTION
        Normalizes URL-safe characters ('-' to '+', '_' to '/') and restores
        any stripped '=' padding before decoding the Base64 payload back into
        a UTF-8 string.
    .PARAMETER InputObject
        The Base64 string to decode.
    .EXAMPLE
        'SGVsbG8gV29ybGQ=' | ConvertFrom-Base64
        Outputs: Hello World
    .EXAMPLE
        'SGVsbG8gV29ybGQ' | b64d
        Outputs: Hello World
    #>
    $Normalized = $InputObject.Replace('-', '+').Replace('_', '/')
    $PaddingNeeded = (4 - ($Normalized.Length % 4)) % 4
    If ($PaddingNeeded -gt 0) {
        $Normalized = $Normalized + ('=' * $PaddingNeeded)
    }
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Normalized))
}

Filter Get-ChildItemForce (
    [Parameter(
        ValueFromPipeline,
        ValueFromPipelineByPropertyName
    )]
    [String]
    $Path = '.'
) {
    <#
    .SYNOPSIS
        Lists directory contents including hidden and system items.
    .DESCRIPTION
        Invokes Get-ChildItem with -Force. Defaults to the current working
        directory when called with no arguments.
    .PARAMETER Path
        The target folder path. Defaults to '.' (current directory).
    .EXAMPLE
        Get-ChildItemForce
        Lists all items including hidden files in the current folder.
    .EXAMPLE
        lsf C:\Windows
        Uses the profile alias to list C:\Windows with hidden files visible.
    #>
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
    <#
    .SYNOPSIS
        Recursively searches for files or directories matching a pattern.
    .DESCRIPTION
        Recursively searches the specified root path using wildcard matching
        (*$InputObject*) with errors silently suppressed.
    .PARAMETER InputObject
        The name substring or pattern to locate.
    .PARAMETER Path
        The starting directory path for the search. Defaults to 'C:\'.
    .EXAMPLE
        Get-ChildItemAll -InputObject 'hosts' -Path 'C:\Windows'
        Finds all files in C:\Windows matching *hosts*.
    .EXAMPLE
        lsa 'settings.json'
        Uses the profile alias to search for settings.json across C:\.
    #>
    Get-ChildItem -Path $Path -Recurse -Filter "*$InputObject*" -ErrorAction SilentlyContinue
}

Filter ConvertTo-DangerousURI (
    [Parameter(ValueFromPipeline)]
    [String]
    $InputObject
) {
    <#
    .SYNOPSIS
        Restores a defanged URI into a live, actionable URL.
    .DESCRIPTION
        Converts defanged representations ('[.]', '[d]', '[dot]') into standard
        dots and restores 'hxxp://' / 'hxxps://' prefixes to 'http://' / 'https://'
        using boundary-aware regular expressions.
    .PARAMETER InputObject
        The defanged URI string.
    .EXAMPLE
        'hxxps://example[.]com/api' | ConvertTo-DangerousURI
        Outputs: https://example.com/api
    .EXAMPLE
        'hxxp://127.0.0.1' | rf
        Uses the profile alias (re-fang) to restore the URI.
    #>
    $InputObject -replace '\[\.\]|\[d\]|\[dot\]', '.' -replace '^hxxp(s?)://', 'http$1://'
}

Filter ConvertTo-SafeURI (
    [Parameter(ValueFromPipeline)]
    [String]
    $InputObject
) {
    <#
    .SYNOPSIS
        Defangs a live URI to prevent accidental navigation or automated clicking.
    .DESCRIPTION
        Replaces 'http://' and 'https://' prefixes with 'hxxp://' and 'hxxps://'
        and replaces '.' with '[.]' to safely display suspicious links.
    .PARAMETER InputObject
        The live URI string to defang.
    .EXAMPLE
        'https://malicious.example.com/path' | ConvertTo-SafeURI
        Outputs: hxxps://malicious[.]example[.]com/path
    .EXAMPLE
        'http://test.com' | df
        Uses the profile alias (de-fang) to safely format the URI.
    #>
    $InputObject -replace '^http(s?)://', 'hxxp$1://' -replace '\.', '[.]'
}

Filter Hide-Item (
    [Parameter(
        Mandatory,
        ValueFromPipeline
    )]
    [ValidateScript({ Test-Path -LiteralPath $PSItem })]
    $Path
) {
    <#
    .SYNOPSIS
        Sets the Hidden file attribute on a file or folder.
    .DESCRIPTION
        Resolves the target file or folder via Get-Item -LiteralPath and applies
        the Hidden attribute using a bitwise OR operation. Supports string paths
        and piped FileSystemInfo items.
    .PARAMETER Path
        The path of the file or folder to hide.
    .EXAMPLE
        Hide-Item -Path '.\secret.env'
        Hides the secret.env file in the current directory.
    .EXAMPLE
        Get-ChildItem -Filter *.tmp | Hide-Item
        Pipes temporary files into Hide-Item to mark them as hidden.
    #>
    $TargetItem = Get-Item -LiteralPath $Path -Force
    $TargetItem.Attributes = $TargetItem.Attributes -bor [System.IO.FileAttributes]::Hidden
}

Function Get-NixOSWSL {
    <#
    .SYNOPSIS
        Downloads and imports the latest NixOS-WSL distribution into WSL 2.
    .DESCRIPTION
        Queries the GitHub API for the latest release of nix-community/NixOS-WSL,
        downloads the nixos-wsl.tar.gz rootfs archive, and imports it into WSL 2
        using 'wsl --import'.
    .PARAMETER NixOSPath
        Target local file path for saving the downloaded tarball archive.
    .PARAMETER NixOSLatestRelease
        GitHub API releases endpoint for the NixOS-WSL project.
    .PARAMETER AsDefault
        Configures NixOS as the default WSL distribution upon completion.
    .EXAMPLE
        Get-NixOSWSL
        Imports NixOS into WSL 2 using the default archive location.
    .EXAMPLE
        Get-NixOSWSL -AsDefault
        Imports NixOS and configures it as the default WSL distribution.
    #>
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
        $NixOSDirectory = Split-Path -Path $NixOSPath -Parent
        If (-not (Test-Path -LiteralPath $NixOSDirectory)) {
            New-Item -ItemType Directory -Path $NixOSDirectory -Force | Out-Null
        }

        If (Test-Path -LiteralPath $NixOSPath) {
            Write-Warning -Message "A NixOS archive already exists as $NixOSPath"
            $UseLocal = $True
        }
    }
    Process {
        If (-not $UseLocal) {
            $ReleaseResponse = Invoke-RestMethod -Uri $NixOSLatestRelease
            $DownloadUrl = $ReleaseResponse.assets.Where({ $PSItem.name -eq 'nixos-wsl.tar.gz' })[0].url
            $NixOSParameters = @{
                Headers = @{
                    Accept = 'application/octet-stream'
                }
                Uri     = $DownloadUrl
                OutFile = $NixOSPath
            }
            Invoke-RestMethod @NixOSParameters
        }
    }
    End {
        $ImportParameters = @{
            FilePath     = 'wsl'
            ArgumentList = "--import NixOS $NixOSDirectory $NixOSPath --version 2"
            Wait         = $True
            NoNewWindow  = $True
        }
        Start-Process @ImportParameters

        If ($AsDefault.IsPresent) {
            $DefaultParameters = @{
                FilePath     = 'wsl'
                ArgumentList = '--set-default NixOS'
                Wait         = $True
                NoNewWindow  = $True
            }
            Start-Process @DefaultParameters
        }
    }
}

Function Start-LocalCyberChef {
    <#
    .SYNOPSIS
        Downloads and opens a local offline copy of CyberChef.
    .DESCRIPTION
        Checks the local CyberChef directory against the latest GitHub release
        of GCHQ CyberChef. If a new version is available, downloads and extracts
        it, then opens the offline HTML interface in the default browser.
    .PARAMETER CyberChefLatestRelease
        The GitHub API endpoint for latest CyberChef release information.
    .PARAMETER CyberChefDirectory
        Local directory where CyberChef HTML and assets are extracted.
    .EXAMPLE
        Start-LocalCyberChef
        Launches the local CyberChef interface, downloading updates if required.
    .EXAMPLE
        chef
        Uses the profile alias to launch CyberChef.
    #>
    [CmdletBinding()]
    Param (
        [Parameter()]
        [String]
        $CyberChefLatestRelease = 'https://api.github.com/repos/gchq/CyberChef/releases/latest',
        [Parameter()]
        [String]
        $CyberChefDirectory = "C:\Users\$Env:UserName\CyberChef\"
    )
    Begin {
        New-Item -ItemType Directory -Path $CyberChefDirectory -Force | Out-Null
        $LatestReleaseInformation = Invoke-RestMethod -Uri $CyberChefLatestRelease
    }
    Process {
        $ExistingHtml = Get-ChildItem -Path "$CyberChefDirectory*.html" -Name -ErrorAction SilentlyContinue
        If ("$ExistingHtml" -notmatch [Regex]::Escape($LatestReleaseInformation.tag_name)) {
            $ZipPath = Join-Path -Path $CyberChefDirectory -ChildPath 'CyberChef.zip'
            $AssetUrl = $LatestReleaseInformation.assets.Where({ $PSItem.name -like '*.zip' })[0].url
            $CyberChefParameters = @{
                Headers = @{
                    Accept = 'application/octet-stream'
                }
                Uri     = $AssetUrl
                OutFile = $ZipPath
            }
            Invoke-RestMethod @CyberChefParameters

            $ExpandParameters = @{
                Path            = $ZipPath
                DestinationPath = $CyberChefDirectory
                Force           = $True
            }
            Expand-Archive @ExpandParameters
        }
        Invoke-Item -Path "$CyberChefDirectory*.html"
    }
    End {
    }
}

Function Enable-PreventIdle {
    <#
    .SYNOPSIS
        Prevents Windows from entering sleep or turning off displays.
    .DESCRIPTION
        Uses a precompiled native Win32 library (bin\IdleState.dll) to invoke
        kernel32!SetThreadExecutionState with ES_CONTINUOUS | ES_SYSTEM_REQUIRED |
        ES_DISPLAY_REQUIRED. Coordinates across processes via a named global mutex
        without spawning background jobs or simulating keystrokes.
    .EXAMPLE
        Enable-PreventIdle
        Enables system and display keep-awake in the current session.
    #>
    [CmdletBinding()]
    Param ()
    Begin {
        If (-not ('PowerShellProfile.IdleState' -as [Type])) {
            $RepoAssembly = Join-Path -Path $ProfileRoot -ChildPath 'bin\IdleState.dll'
            $CacheDirectory = "$Env:LocalAppData\PowerShell\CompletionCache"
            $CachedAssembly = Join-Path -Path $CacheDirectory -ChildPath 'IdleState.dll'

            If (Test-Path -LiteralPath $RepoAssembly) {
                Add-Type -LiteralPath $RepoAssembly
            }
            ElseIf (Test-Path -LiteralPath $CachedAssembly) {
                Add-Type -LiteralPath $CachedAssembly
            }
            Else {
                If (-not (Test-Path -LiteralPath $CacheDirectory)) {
                    New-Item -ItemType Directory -Path $CacheDirectory -Force | Out-Null
                }
                $TypeDefinition = @'
using System;
using System.Runtime.InteropServices;

namespace PowerShellProfile {
    public static class IdleState {
        private const uint ES_CONTINUOUS = 0x80000000;
        private const uint ES_SYSTEM_REQUIRED = 0x00000001;
        private const uint ES_DISPLAY_REQUIRED = 0x00000002;

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern uint SetThreadExecutionState(uint esFlags);

        public static uint PreventIdle() {
            return SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
        }

        public static uint AllowIdle() {
            return SetThreadExecutionState(ES_CONTINUOUS);
        }
    }
}
'@
                Add-Type -TypeDefinition $TypeDefinition -OutputAssembly $CachedAssembly
                Add-Type -LiteralPath $CachedAssembly
            }
        }
    }
    Process {
        If (-not $Global:PreventIdleMutex) {
            $Global:PreventIdleMutex = [System.Threading.Mutex]::new($False, 'Global\PowerShellProfile_PreventIdle')
        }
        [PowerShellProfile.IdleState]::PreventIdle() | Out-Null
    }
    End {
    }
}

Function Disable-PreventIdle {
    <#
    .SYNOPSIS
        Restores default Windows sleep and idle behavior.
    .DESCRIPTION
        Calls kernel32!SetThreadExecutionState with ES_CONTINUOUS to clear keep-awake
        flags and disposes the named global mutex.
    .EXAMPLE
        Disable-PreventIdle
        Allows Windows to sleep normally according to active power plan.
    #>
    [CmdletBinding()]
    Param ()
    Begin {
    }
    Process {
        If ('PowerShellProfile.IdleState' -as [Type]) {
            [PowerShellProfile.IdleState]::AllowIdle() | Out-Null
        }
        If ($Global:PreventIdleMutex) {
            $Global:PreventIdleMutex.Dispose()
            $Global:PreventIdleMutex = $Null
        }
    }
    End {
    }
}

$WslcCompleter = Join-Path -Path $ProfileRoot -ChildPath 'completions\wslc.ps1'
If (Test-Path -LiteralPath $WslcCompleter) {
    . $WslcCompleter
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
    Set-Alias -Name $PSItem.Key -Value $PSItem.Value
}

$CompletionCacheDirectory = "$Env:LocalAppData\PowerShell\CompletionCache"
If (-not (Test-Path -LiteralPath $CompletionCacheDirectory)) {
    New-Item -ItemType Directory -Path $CompletionCacheDirectory -Force | Out-Null
}

Function Get-CachedCommandInit {
    <#
    .SYNOPSIS
        Retrieves or generates a disk-cached initialization script for CLI tools.
    .DESCRIPTION
        Checks if a cached initialization script exists under LocalAppData and
        compares its modification timestamp against the binary executable.
        If missing or stale, executes the generator ScriptBlock, saves the script,
        and returns the cache file path for dot-sourcing.
    .PARAMETER CommandName
        The name of the CLI tool (e.g. 'starship', 'zoxide').
    .PARAMETER InitGenerator
        The ScriptBlock used to produce the initialization script.
    .EXAMPLE
        Get-CachedCommandInit -CommandName 'starship' -InitGenerator { starship init powershell }
        Returns the path to the cached starship initialization script.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String]
        $CommandName,
        [Parameter(Mandatory)]
        [ScriptBlock]
        $InitGenerator
    )
    Begin {
        $CommandInfo = Get-Command -Name $CommandName -ErrorAction SilentlyContinue
    }
    Process {
        If (-not $CommandInfo) {
            Return
        }

        $CacheFile = Join-Path -Path $CompletionCacheDirectory -ChildPath "$CommandName-init.ps1"
        $BinaryItem = Get-Item -LiteralPath $CommandInfo.Source -ErrorAction SilentlyContinue
        $CacheItem = Get-Item -LiteralPath $CacheFile -ErrorAction SilentlyContinue

        If (-not $CacheItem -or ($BinaryItem -and $BinaryItem.LastWriteTimeUtc -gt $CacheItem.LastWriteTimeUtc)) {
            $GeneratedScript = (& $InitGenerator) | Out-String
            If (-not [String]::IsNullOrWhiteSpace($GeneratedScript)) {
                $CacheParameters = @{
                    LiteralPath = $CacheFile
                    Value       = $GeneratedScript
                    Encoding    = 'UTF8'
                    Force       = $True
                }
                Set-Content @CacheParameters
            }
        }
    }
    End {
        If ($CommandInfo -and (Test-Path -LiteralPath $CacheFile)) {
            $CacheFile
        }
    }
}

$StarshipInitCache = Get-CachedCommandInit -CommandName 'starship' -InitGenerator { starship init powershell }
If ($StarshipInitCache) {
    . $StarshipInitCache
}

$ZoxideInitCache = Get-CachedCommandInit -CommandName 'zoxide' -InitGenerator { zoxide init powershell --cmd cd }
If ($ZoxideInitCache) {
    . $ZoxideInitCache
}

ForEach ($LazyCommand in @('minikube', 'kubectl', 'helm')) {
    If (Get-Command -Name $LazyCommand -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -Native -CommandName $LazyCommand -ScriptBlock ({
            Param (
                $WordToComplete,
                $CommandAst,
                $CursorPosition
            )
            $TargetCommand = $CommandAst.CommandElements[0].Value
            $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($TargetCommand)
            $CacheFile = Join-Path -Path "$Env:LocalAppData\PowerShell\CompletionCache" -ChildPath "$BaseName-completion.ps1"
            $CommandInfo = Get-Command -Name $BaseName -ErrorAction SilentlyContinue
            $BinaryItem = If ($CommandInfo) { Get-Item -LiteralPath $CommandInfo.Source -ErrorAction SilentlyContinue } Else { $Null }
            $CacheItem = Get-Item -LiteralPath $CacheFile -ErrorAction SilentlyContinue

            If (-not $CacheItem -or ($BinaryItem -and $BinaryItem.LastWriteTimeUtc -gt $CacheItem.LastWriteTimeUtc)) {
                $CompletionScript = (& $BaseName completion powershell) | Out-String
                If (-not [String]::IsNullOrWhiteSpace($CompletionScript)) {
                    $CacheParameters = @{
                        LiteralPath = $CacheFile
                        Value       = $CompletionScript
                        Encoding    = 'UTF8'
                        Force       = $True
                    }
                    Set-Content @CacheParameters
                }
            }

            If (Test-Path -LiteralPath $CacheFile) {
                . $CacheFile
            }
        }.GetNewClosure())
    }
}

$TerminalSettingsPath = "$Env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
If ((Test-Path -LiteralPath $TerminalSettingsPath) -and (Select-String -Path $TerminalSettingsPath -Pattern '"colorScheme": "Solarized Light"' -Quiet)) {
    Set-PSReadLineOption -Colors @{
        Number             = "`e[39m"
        ContinuationPrompt = "`e[39m"
        Member             = "`e[39m"
        Type               = "`e[39m"
    }
}

Enable-PreventIdle
