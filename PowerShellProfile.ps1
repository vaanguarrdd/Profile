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

ForEach ($ModuleName in @('DFIR.ps1', 'Data.ps1', 'Cloud.ps1')) {
    $ModulePath = Join-Path -Path $ProfileRoot -ChildPath "modules\$ModuleName"
    If (Test-Path -LiteralPath $ModulePath) {
        . $ModulePath
    }
}

$WslcCompleter = Join-Path -Path $ProfileRoot -ChildPath 'completions\wslc.ps1'
If (Test-Path -LiteralPath $WslcCompleter) {
    . $WslcCompleter
}

$Aliases = @{
    scf       = 'Stop-ComputerForce'
    rcf       = 'Restart-ComputerForce'
    lsf       = 'Get-ChildItemForce'
    lsa       = 'Get-ChildItemAll'
    eo        = 'Expand-Object'
    fla       = 'Format-ListAll'
    b64e      = 'ConvertTo-Base64'
    b64d      = 'ConvertFrom-Base64'
    rf        = 'ConvertTo-DangerousURI'
    df        = 'ConvertTo-SafeURI'
    fsum      = 'Get-FileSummary'
    jwt       = 'ConvertFrom-Jwt'
    epd       = 'ConvertFrom-EpochTime'
    epe       = 'ConvertTo-EpochTime'
    yara      = 'Invoke-YaraScan'
    fevt      = 'Get-ForensicEventLog'
    netp      = 'Get-NetworkConnectionProcess'
    fromjsonl = 'ConvertFrom-JsonLines'
    tojsonl   = 'ConvertTo-JsonLines'
    dql       = 'Invoke-DuckDbQuery'
    dschema   = 'Show-DataSchema'
    toparquet = 'ConvertTo-Parquet'
    gproj     = 'Switch-GcpProject'
    gcb       = 'Watch-CloudBuild'
    kctx      = 'Switch-KubeContext'
    kns       = 'Switch-KubeNamespace'
    chef      = 'Start-LocalCyberChef'
    rsp       = 'Restart-Profile'
    cat       = 'bat'
    vi        = 'nvim'
    vim       = 'nvim'
    ghd       = 'GithubDesktop'
    s         = 'Set-Clipboard'
    docker    = 'wslc'
    gj        = 'Get-Job'
    rcj       = 'Receive-Job'
    sj        = 'Stop-Job'
    rj        = 'Remove-Job'
    wc        = 'wslc'
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

ForEach ($LazyCommand in @('minikube', 'kubectl', 'helm', 'gh', 'cosign', 'crane', 'skaffold')) {
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
                $CompletionScript = If ($BaseName -eq 'gh') {
                    (& gh completion -s powershell) | Out-String
                }
                Else {
                    (& $BaseName completion powershell) | Out-String
                }

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

$HasPSReadLine = [Boolean](Get-Module -Name PSReadLine -ErrorAction SilentlyContinue)

If ($HasPSReadLine) {
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

If ($HasPSReadLine -and (Get-Command -Name 'fzf' -ErrorAction SilentlyContinue)) {
    Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ScriptBlock {
        $HistoryPath = (Get-PSReadLineOption).HistorySavePath
        If (-not (Test-Path -LiteralPath $HistoryPath)) {
            Return
        }

        $HistoryLines = [System.IO.File]::ReadAllLines($HistoryPath)
        [Array]::Reverse($HistoryLines)
        $SelectedCommand = $HistoryLines | & fzf --height=40% --reverse --no-sort --prompt='History> '
        If ([String]::IsNullOrWhiteSpace($SelectedCommand)) {
            Return
        }

        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($SelectedCommand)
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
