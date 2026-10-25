<#
.SYNOPSIS
    Digital Forensics and Incident Response (DFIR) utilities for the PowerShell profile.
.DESCRIPTION
    Provides pipeline-oriented filters and functions for host triage, artifact analysis,
    encoding/decoding, URI defanging, JWT inspection, epoch timestamp conversion,
    Shannon entropy and multi-hash calculation, YARA-X scanning, Windows Event Log triage,
    and network-to-process correlation.
#>

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

Filter Get-FileSummary (
    [Parameter(
        Mandatory,
        ValueFromPipeline,
        ValueFromPipelineByPropertyName
    )]
    [Alias('FullName')]
    [ValidateScript({ Test-Path -LiteralPath $PSItem -PathType Leaf })]
    [String]
    $Path
) {
    <#
    .SYNOPSIS
        Computes hashes, Shannon byte entropy, and Authenticode signature status for a file.
    .DESCRIPTION
        Performs a single-pass forensic inspection of a target file, calculating MD5, SHA1,
        and SHA256 cryptographic digests, Shannon byte entropy (0.0 to 8.0) with packed/encrypted
        payload flagging (> 7.2), and Authenticode digital signature status.
    .PARAMETER Path
        The file path or piped FileSystemInfo object to inspect.
    .EXAMPLE
        Get-FileSummary -Path 'C:\Windows\System32\cmd.exe'
        Returns hashes, entropy, and signature details for cmd.exe.
    .EXAMPLE
        Get-ChildItem -Path 'C:\Windows\Temp' -File | fsum
        Pipes all files in C:\Windows\Temp through Get-FileSummary.
    #>
    $Item = Get-Item -LiteralPath $Path -Force
    $Bytes = [System.IO.File]::ReadAllBytes($Item.FullName)
    $Length = $Bytes.Length
    $Entropy = 0.0

    If ($Length -gt 0) {
        $Counts = [Int[]]::new(256)
        ForEach ($Byte in $Bytes) {
            $Counts[$Byte]++
        }
        ForEach ($Count in $Counts) {
            If ($Count -gt 0) {
                $Probability = $Count / $Length
                $Entropy -= $Probability * [Math]::Log($Probability, 2)
            }
        }
    }

    $Signature = Get-AuthenticodeSignature -LiteralPath $Item.FullName -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        Name          = $Item.Name
        Path          = $Item.FullName
        SizeBytes     = $Length
        Entropy       = [Math]::Round($Entropy, 4)
        HighEntropy   = ($Entropy -gt 7.2)
        SHA256        = (Get-FileHash -LiteralPath $Item.FullName -Algorithm SHA256).Hash
        SHA1          = (Get-FileHash -LiteralPath $Item.FullName -Algorithm SHA1).Hash
        MD5           = (Get-FileHash -LiteralPath $Item.FullName -Algorithm MD5).Hash
        SignStatus    = If ($Signature) { [String]$Signature.Status } Else { 'Unknown' }
        SignerSubject = If ($Signature.SignerCertificate) { $Signature.SignerCertificate.Subject } Else { $Null }
    }
}

Filter ConvertFrom-Jwt (
    [Parameter(
        Mandatory,
        ValueFromPipeline
    )]
    [ValidateNotNullOrEmpty()]
    [String]
    $Token
) {
    <#
    .SYNOPSIS
        Decodes and inspects a JSON Web Token (JWT).
    .DESCRIPTION
        Splits a JWT into header, payload, and signature segments, Base64Url-decodes
        the header and payload into PowerShell objects, and translates standard numeric
        epoch claims (iat, nbf, exp) into UTC DateTime properties and expiration state.
    .PARAMETER Token
        The raw JWT string (header.payload.signature).
    .EXAMPLE
        $BearerToken | ConvertFrom-Jwt
        Outputs decoded header, payload, timestamps, and expiration boolean.
    .EXAMPLE
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c' | jwt
        Uses the profile alias to decode a JWT.
    #>
    $CleanToken = $Token.Trim() -replace '^Bearer\s+', ''
    $Segments = $CleanToken -split '\.'
    If ($Segments.Count -lt 2) {
        Throw 'Invalid JWT format. Expected at least header and payload segments separated by dots.'
    }

    $HeaderJson = $Segments[0] | ConvertFrom-Base64
    $PayloadJson = $Segments[1] | ConvertFrom-Base64
    $HeaderObj = $HeaderJson | ConvertFrom-Json
    $PayloadObj = $PayloadJson | ConvertFrom-Json

    $IssuedAtUtc = If ($Null -ne $PayloadObj.iat) {
        [DateTimeOffset]::FromUnixTimeSeconds([Long]$PayloadObj.iat).UtcDateTime
    }
    Else {
        $Null
    }

    $NotBeforeUtc = If ($Null -ne $PayloadObj.nbf) {
        [DateTimeOffset]::FromUnixTimeSeconds([Long]$PayloadObj.nbf).UtcDateTime
    }
    Else {
        $Null
    }

    $ExpiresAtUtc = If ($Null -ne $PayloadObj.exp) {
        [DateTimeOffset]::FromUnixTimeSeconds([Long]$PayloadObj.exp).UtcDateTime
    }
    Else {
        $Null
    }

    $IsExpired = If ($Null -ne $ExpiresAtUtc) {
        ([DateTime]::UtcNow -gt $ExpiresAtUtc)
    }
    Else {
        $Null
    }

    [PSCustomObject]@{
        Header       = $HeaderObj
        Payload      = $PayloadObj
        IssuedAtUtc  = $IssuedAtUtc
        NotBeforeUtc = $NotBeforeUtc
        ExpiresAtUtc = $ExpiresAtUtc
        IsExpired    = $IsExpired
        Signature    = If ($Segments.Count -ge 3) { $Segments[2] } Else { $Null }
    }
}

Filter ConvertFrom-EpochTime (
    [Parameter(
        Mandatory,
        ValueFromPipeline
    )]
    [Long]
    $Epoch
) {
    <#
    .SYNOPSIS
        Converts a Unix epoch timestamp into UTC and local DateTime objects.
    .DESCRIPTION
        Automatically detects whether the input Unix timestamp is expressed in
        seconds (<= 11 digits), milliseconds (12-14 digits), or microseconds (15+ digits)
        and returns structured UTC, LocalTime, and ISO 8601 representations.
    .PARAMETER Epoch
        The numeric Unix timestamp to convert.
    .EXAMPLE
        1700000000 | ConvertFrom-EpochTime
        Converts Unix seconds into UTC and local DateTime values.
    .EXAMPLE
        1700000000000 | epd
        Uses the profile alias to convert Unix milliseconds.
    #>
    $AbsValue = [Math]::Abs($Epoch)
    If ($AbsValue -ge 100000000000000L) {
        $Unit = 'Microseconds'
        $Seconds = [Long]($Epoch / 1000000L)
        $RemainderMicros = $Epoch % 1000000L
        $Offset = [DateTimeOffset]::FromUnixTimeSeconds($Seconds).AddTicks($RemainderMicros * 10L)
    }
    ElseIf ($AbsValue -ge 100000000000L) {
        $Unit = 'Milliseconds'
        $Offset = [DateTimeOffset]::FromUnixTimeMilliseconds($Epoch)
    }
    Else {
        $Unit = 'Seconds'
        $Offset = [DateTimeOffset]::FromUnixTimeSeconds($Epoch)
    }

    [PSCustomObject]@{
        EpochInput = $Epoch
        Unit       = $Unit
        UtcTime    = $Offset.UtcDateTime
        LocalTime  = $Offset.LocalDateTime
        Iso8601    = $Offset.UtcDateTime.ToString('o')
    }
}

Filter ConvertTo-EpochTime (
    [Parameter(ValueFromPipeline)]
    [DateTime]
    $DateTime = [DateTime]::UtcNow
) {
    <#
    .SYNOPSIS
        Converts a DateTime value into Unix epoch seconds and milliseconds.
    .DESCRIPTION
        Normalizes the provided DateTime (or current UTC time when invoked with no input)
        to UTC and outputs both Unix epoch seconds and milliseconds.
    .PARAMETER DateTime
        The DateTime object to convert. Defaults to [DateTime]::UtcNow.
    .EXAMPLE
        ConvertTo-EpochTime
        Outputs the current time in Unix epoch seconds and milliseconds.
    .EXAMPLE
        (Get-Date).AddDays(-1) | epe
        Converts yesterday's timestamp into Unix epoch representations.
    #>
    $UtcDateTime = $DateTime.ToUniversalTime()
    $Offset = [DateTimeOffset]::new($UtcDateTime)
    [PSCustomObject]@{
        UtcTime           = $UtcDateTime
        EpochSeconds      = $Offset.ToUnixTimeSeconds()
        EpochMilliseconds = $Offset.ToUnixTimeMilliseconds()
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

Function Invoke-YaraScan {
    <#
    .SYNOPSIS
        Scans files or directories using VirusTotal YARA-X (yr).
    .DESCRIPTION
        Wraps the YARA-X CLI ('yr scan') to scan a target file or directory against
        one or more YARA rule files, parsing matching rules and paths into structured
        PowerShell objects for pipeline filtering.
    .PARAMETER RulePath
        Path to the .yar or .yara rule file.
    .PARAMETER TargetPath
        Path to the target file or directory to scan. Defaults to current directory.
    .PARAMETER Recursive
        Recursively scans subdirectories when TargetPath is a directory.
    .EXAMPLE
        Invoke-YaraScan -RulePath '.\rules\malware.yar' -TargetPath 'C:\Users\Public' -Recursive
        Scans C:\Users\Public recursively against malware.yar.
    .EXAMPLE
        yara '.\rules.yar' '.\sample.exe'
        Uses the profile alias to scan sample.exe.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory,
            Position = 0
        )]
        [ValidateScript({ Test-Path -LiteralPath $PSItem })]
        [String]
        $RulePath,
        [Parameter(
            Position = 1,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias('FullName')]
        [ValidateScript({ Test-Path -LiteralPath $PSItem })]
        [String]
        $TargetPath = '.',
        [Parameter()]
        [Switch]
        $Recursive
    )
    Begin {
        If (-not (Get-Command -Name 'yr' -ErrorAction SilentlyContinue)) {
            Throw 'YARA-X CLI (yr) is not installed or not on PATH.'
        }
        $ResolvedRule = (Resolve-Path -LiteralPath $RulePath).Path
    }
    Process {
        $ResolvedTarget = (Resolve-Path -LiteralPath $TargetPath).Path
        $Arguments = @('scan')
        If ($Recursive.IsPresent) {
            $Arguments += '--recursive'
        }
        $Arguments += @($ResolvedRule, $ResolvedTarget)

        $ScanOutput = & yr @Arguments
        ForEach ($Line in $ScanOutput) {
            If ($Line -match '^(?<Rule>\S+)\s+(?<Target>.+)$') {
                [PSCustomObject]@{
                    Rule       = $Matches.Rule
                    TargetPath = $Matches.Target.Trim()
                    RuleFile   = $ResolvedRule
                }
            }
        }
    }
    End {
    }
}

Function Get-ForensicEventLog {
    <#
    .SYNOPSIS
        Queries high-signal Windows Security, PowerShell, and Sysmon event logs for triage.
    .DESCRIPTION
        Uses FilterHashtable queries via Get-WinEvent to rapidly retrieve critical DFIR
        events across Security (4624, 4625, 4688, 4698, 4720, 1102), PowerShell Operational
        (4104), and Sysmon Operational (1, 3, 11, 22) within a specified lookback window.
    .PARAMETER EventId
        Array of Event IDs to query. Defaults to standard high-signal DFIR Event IDs.
    .PARAMETER HoursBack
        Number of hours to look back from the current time. Defaults to 24.
    .PARAMETER MaxEvents
        Maximum number of events to return per log channel. Defaults to 200.
    .EXAMPLE
        Get-ForensicEventLog -HoursBack 12
        Retrieves high-signal forensic events from the past 12 hours.
    .EXAMPLE
        fevt -EventId @(4104, 4688) -HoursBack 4
        Uses the profile alias to inspect PowerShell script blocks and process creations.
    #>
    [CmdletBinding()]
    Param (
        [Parameter()]
        [Int[]]
        $EventId = @(4624, 4625, 4688, 4698, 4720, 1102, 4104, 1, 3, 11, 22),
        [Parameter()]
        [Int]
        $HoursBack = 24,
        [Parameter()]
        [Int]
        $MaxEvents = 200
    )
    Begin {
        $StartTime = (Get-Date).AddHours(-$HoursBack)
        $Channels = @(
            'Security',
            'Microsoft-Windows-PowerShell/Operational',
            'Microsoft-Windows-Sysmon/Operational'
        )
    }
    Process {
        ForEach ($Channel in $Channels) {
            $FilterTable = @{
                LogName   = $Channel
                Id        = $EventId
                StartTime = $StartTime
            }
            $EventParameters = @{
                FilterHashtable = $FilterTable
                MaxEvents       = $MaxEvents
                ErrorAction     = 'SilentlyContinue'
            }
            Get-WinEvent @EventParameters | Select-Object -Property TimeCreated, Id, LogName, ProviderName, LevelDisplayName, Message
        }
    }
    End {
    }
}

Function Get-NetworkConnectionProcess {
    <#
    .SYNOPSIS
        Correlates active TCP network connections with owning processes, command lines, and signatures.
    .DESCRIPTION
        Retrieves active TCP connections via Get-NetTCPConnection and enriches each entry
        with process metadata from Win32_Process (ProcessName, ExecutablePath, CommandLine)
        and Authenticode signature status for rapid live-host network triage.
    .PARAMETER State
        Filters connections by TCP state (e.g. 'Established', 'Listen'). Defaults to 'Established'.
    .EXAMPLE
        Get-NetworkConnectionProcess
        Lists all Established TCP connections with full process command lines and signature status.
    .EXAMPLE
        netp -State Listen
        Uses the profile alias to inspect all listening TCP ports and their backing binaries.
    #>
    [CmdletBinding()]
    Param (
        [Parameter()]
        [String[]]
        $State = @('Established')
    )
    Begin {
        $ProcessMap = @{}
        Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue | ForEach-Object {
            $ProcessMap[[Int]$PSItem.ProcessId] = $PSItem
        }
        $SignatureCache = @{}
    }
    Process {
        $TcpParameters = @{
            State       = $State
            ErrorAction = 'SilentlyContinue'
        }
        $Connections = Get-NetTCPConnection @TcpParameters
        ForEach ($Connection in $Connections) {
            $PidValue = [Int]$Connection.OwningProcess
            $ProcInfo = $ProcessMap[$PidValue]
            $ExePath = If ($ProcInfo) { $ProcInfo.ExecutablePath } Else { $Null }

            $SignStatus = If ($ExePath -and (Test-Path -LiteralPath $ExePath)) {
                If (-not $SignatureCache.ContainsKey($ExePath)) {
                    $Sig = Get-AuthenticodeSignature -LiteralPath $ExePath -ErrorAction SilentlyContinue
                    $SignatureCache[$ExePath] = If ($Sig) { [String]$Sig.Status } Else { 'Unknown' }
                }
                $SignatureCache[$ExePath]
            }
            Else {
                'Unavailable'
            }

            [PSCustomObject]@{
                LocalAddress   = $Connection.LocalAddress
                LocalPort      = $Connection.LocalPort
                RemoteAddress  = $Connection.RemoteAddress
                RemotePort     = $Connection.RemotePort
                State          = [String]$Connection.State
                PID            = $PidValue
                ProcessName    = If ($ProcInfo) { $ProcInfo.Name } Else { (Get-Process -Id $PidValue -ErrorAction SilentlyContinue).Name }
                ExecutablePath = $ExePath
                CommandLine    = If ($ProcInfo) { $ProcInfo.CommandLine } Else { $Null }
                SignStatus     = $SignStatus
            }
        }
    }
    End {
    }
}
