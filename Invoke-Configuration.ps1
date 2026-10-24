#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Applies declarative system configuration using WinGet DSC, AppX removal, and DISM.
.DESCRIPTION
    Automates workstation configuration in an idempotent manner:
    1. Validates and applies configuration.winget using 'winget configure'.
    2. Identifies and removes unwanted preinstalled AppX/MSIX bloatware packages.
    3. Removes deprecated Windows Capabilities (ISE, WordPad, Windows Media Player).
    4. Idempotently enables required Windows Optional Features (Hyper-V, WSL, Containers).
    5. Idempotently disables insecure or legacy Windows Optional Features (SMBv1, Telnet, IIS, etc.).
    Supports -WhatIf and -Confirm via SupportsShouldProcess.
.PARAMETER ConfigurationFile
    Path to the WinGet DSC configuration file. Defaults to configuration.winget in the script directory.
.PARAMETER ValidateOnly
    Validates the WinGet DSC configuration and exits without applying changes to the system.
.PARAMETER RemoveAppxPackages
    List of AppX/MSIX PackageFamilyNames to remove if currently installed.
.PARAMETER WindowsCapabilities
    List of Windows Capabilities to remove if currently installed.
.PARAMETER EnableWindowsOptionalFeatures
    List of Windows Optional Features to ensure enabled.
.PARAMETER DisableWindowsOptionalFeatures
    List of Windows Optional Features to ensure disabled.
.EXAMPLE
    .\Invoke-Configuration.ps1 -WhatIf
    Previews all pending WinGet, AppX, Capability, and Optional Feature actions without mutating state.
.EXAMPLE
    .\Invoke-Configuration.ps1 -ValidateOnly
    Validates the syntax and resources in configuration.winget.
.EXAMPLE
    .\Invoke-Configuration.ps1 -Verbose
    Executes the configuration with detailed progress logging.
#>
[CmdletBinding(SupportsShouldProcess)]
Param (
    [Parameter()]
    [ValidateScript({
        Test-Path -LiteralPath $PSItem
    })]
    [String]
    $ConfigurationFile = "$PSScriptRoot\configuration.winget",
    [Parameter()]
    [Switch]
    $ValidateOnly,
    [Parameter()]
    [String[]]
    $RemoveAppxPackages = @(
        'Clipchamp.Clipchamp_yxz26nhyzhsrt',
        'Microsoft.BingWeather_8wekyb3d8bbwe',
        'Microsoft.BingNews_8wekyb3d8bbwe',
        'Microsoft.GamingApp_8wekyb3d8bbwe',
        'Getstarted_8wekyb3d8bbwe',
        'Microsoft.Paint_8wekyb3d8bbwe',
        'Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe',
        'Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe',
        'microsoft.windowscommunicationsapps_8wekyb3d8bbwe',
        'SpotifyAB.SpotifyMusic_zpdnekdrzrea0',
        'Microsoft.ZuneVideo_8wekyb3d8bbwe',
        'Microsoft.ZuneMusic_8wekyb3d8bbwe',
        'Microsoft.XboxSpeechToTextOverlay_8wekyb3d8bbwe',
        'Microsoft.XboxGamingOverlay_8wekyb3d8bbwe',
        'Microsoft.XboxGameOverlay_8wekyb3d8bbwe',
        'Microsoft.Xbox.TCUI_8wekyb3d8bbwe',
        'Microsoft.XboxIdentityProvider_8wekyb3d8bbwe',
        'Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe',
        'Microsoft.WindowsMaps_8wekyb3d8bbwe',
        'Microsoft.People_8wekyb3d8bbwe',
        'Microsoft.PowerAutomateDesktop_8wekyb3d8bbwe'
    ),
    [Parameter()]
    [String[]]
    $WindowsCapabilities = @(
        'Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0',
        'Microsoft.Windows.WordPad~~~~0.0.1.0',
        'Media.WindowsMediaPlayer~~~~0.0.12.0'
    ),
    [Parameter()]
    [String[]]
    $EnableWindowsOptionalFeatures = @(
        'HypervisorPlatform',
        'VirtualMachinePlatform',
        'Microsoft-Windows-Subsystem-Linux',
        'Containers',
        'Containers-DisposableClientVM',
        'Microsoft-Hyper-V-All',
        'Microsoft-Hyper-V',
        'Microsoft-Hyper-V-Tools-All',
        'Microsoft-Hyper-V-Management-PowerShell',
        'Microsoft-Hyper-V-Hypervisor',
        'Microsoft-Hyper-V-Services',
        'Microsoft-Hyper-V-Management-Clients',
        'HostGuardian'
    ),
    [Parameter()]
    [String[]]
    $DisableWindowsOptionalFeatures = @(
        'Printing-XPSServices-Features',
        'TelnetClient',
        'TIFFIFilter',
        'LegacyComponents',
        'DirectPlay',
        'MSRDC-Infrastructure',
        'Windows-Identity-Foundation',
        'MicrosoftWindowsPowerShellV2Root',
        'MicrosoftWindowsPowerShellV2',
        'SimpleTCP',
        'SMB1Protocol-Deprecation',
        'WCF-HTTP-Activation',
        'WCF-NonHTTP-Activation',
        'WCF-HTTP-Activation45',
        'WCF-TCP-Activation45',
        'WCF-Pipe-Activation45',
        'WCF-MSMQ-Activation45',
        'MediaPlayback',
        'AppServerClient',
        'Printing-Foundation-Features',
        'Printing-Foundation-InternetPrinting-Client',
        'Printing-Foundation-LPDPrintService',
        'Printing-Foundation-LPRPortMonitor',
        'DataCenterBridging',
        'ServicesForNFS-ClientOnly',
        'ClientForNFS-Infrastructure',
        'NFS-Administration',
        'SMB1Protocol',
        'SMB1Protocol-Client',
        'SMB1Protocol-Server',
        'MultiPoint-Connector',
        'MultiPoint-Connector-Services',
        'MultiPoint-Tools',
        'TFTP',
        'Client-ProjFS',
        'Client-DeviceLockdown',
        'Client-EmbeddedShellLauncher',
        'Client-EmbeddedBootExp',
        'Client-EmbeddedLogon',
        'Client-KeyboardFilter',
        'Client-UnifiedWriteFilter',
        'DirectoryServices-ADAM-Client',
        'IIS-WebServerRole',
        'IIS-WebServer',
        'IIS-CommonHttpFeatures',
        'IIS-HttpErrors',
        'IIS-HttpRedirect',
        'IIS-ApplicationDevelopment',
        'IIS-Security',
        'IIS-RequestFiltering',
        'IIS-NetFxExtensibility',
        'IIS-NetFxExtensibility45',
        'IIS-HealthAndDiagnostics',
        'IIS-HttpLogging',
        'IIS-LoggingLibraries',
        'IIS-RequestMonitor',
        'IIS-HttpTracing',
        'IIS-URLAuthorization',
        'IIS-IPSecurity',
        'IIS-Performance',
        'IIS-HttpCompressionDynamic',
        'IIS-WebServerManagementTools',
        'IIS-ManagementScriptingTools',
        'IIS-IIS6ManagementCompatibility',
        'IIS-Metabase',
        'WAS-WindowsActivationService',
        'WAS-ProcessModel',
        'WAS-NetFxEnvironment',
        'WAS-ConfigurationAPI',
        'IIS-HostableWebCore',
        'IIS-StaticContent',
        'IIS-DefaultDocument',
        'IIS-DirectoryBrowsing',
        'IIS-WebDAV',
        'IIS-WebSockets',
        'IIS-ApplicationInit',
        'IIS-ISAPIFilter',
        'IIS-ISAPIExtensions',
        'IIS-ASPNET',
        'IIS-ASPNET45',
        'IIS-ASP',
        'IIS-CGI',
        'IIS-ServerSideIncludes',
        'IIS-CustomLogging',
        'IIS-BasicAuthentication',
        'IIS-HttpCompressionStatic',
        'IIS-ManagementConsole',
        'IIS-ManagementService',
        'IIS-WMICompatibility',
        'IIS-LegacyScripts',
        'IIS-FTPServer',
        'IIS-FTPSvc',
        'IIS-FTPExtensibility',
        'MSMQ-Container',
        'MSMQ-DCOMProxy',
        'MSMQ-Server',
        'MSMQ-ADIntegration',
        'MSMQ-HTTP',
        'MSMQ-Multicast',
        'MSMQ-Triggers',
        'IIS-CertProvider',
        'IIS-WindowsAuthentication',
        'IIS-DigestAuthentication',
        'IIS-ClientCertificateMappingAuthentication',
        'IIS-IISCertificateMappingAuthentication',
        'IIS-ODBCLogging',
        'NetFx4Extended-ASPNET45'
    )
)
Begin {
    Write-Verbose -Message "Validating WinGet DSC configuration: $ConfigurationFile"
    & winget configure validate --file $ConfigurationFile --nowarn
    If ($LASTEXITCODE -ne 0) {
        Throw "WinGet DSC configuration validation failed with exit code $LASTEXITCODE."
    }
}
Process {
    If ($ValidateOnly.IsPresent) {
        Return
    }

    $InstalledAppx = Get-AppxPackage -AllUsers | Where-Object { $PSItem.PackageFamilyName -in $RemoveAppxPackages }
    ForEach ($AppxPackage in $InstalledAppx) {
        If ($PSCmdlet.ShouldProcess($AppxPackage.PackageFamilyName, 'Remove-AppxPackage')) {
            Write-Verbose -Message "Removing Appx package $($AppxPackage.PackageFamilyName)"
            & winget uninstall --id $AppxPackage.PackageFamilyName --silent --accept-source-agreements
        }
    }

    If ($PSCmdlet.ShouldProcess($ConfigurationFile, 'Apply WinGet DSC Configuration')) {
        & winget configure --file $ConfigurationFile --accept-configuration-agreements --disable-interactivity
    }

    $OnlineCapabilities = Get-WindowsCapability -Online -ProgressAction SilentlyContinue -Verbose:$False
    $InstalledCapabilities = @(
        $OnlineCapabilities |
        Where-Object { $PSItem.Name -in $WindowsCapabilities -and $PSItem.State -eq 'Installed' } |
        Select-Object -ExpandProperty Name
    )

    ForEach ($CapabilityName in $InstalledCapabilities) {
        If ($PSCmdlet.ShouldProcess($CapabilityName, 'Remove-WindowsCapability')) {
            Write-Verbose -Message "Removing capability $CapabilityName"
            $CapabilityParameters = @{
                Name           = $CapabilityName
                Online         = $True
                ProgressAction = 'SilentlyContinue'
                Verbose        = $False
            }
            Remove-WindowsCapability @CapabilityParameters | Out-Null
        }
    }

    $OnlineFeatures = Get-WindowsOptionalFeature -Online -ProgressAction SilentlyContinue -Verbose:$False

    $FeaturesToEnable = @(
        $OnlineFeatures |
        Where-Object { $PSItem.FeatureName -in $EnableWindowsOptionalFeatures -and $PSItem.State -ne 'Enabled' } |
        Select-Object -ExpandProperty FeatureName
    )

    If ($FeaturesToEnable.Count -gt 0) {
        If ($PSCmdlet.ShouldProcess(($FeaturesToEnable -join ', '), 'Enable-WindowsOptionalFeature')) {
            Write-Verbose -Message "Enabling features: $($FeaturesToEnable -join ', ')"
            $EnableParameters = @{
                FeatureName    = $FeaturesToEnable
                Online         = $True
                All            = $True
                NoRestart      = $True
                ProgressAction = 'SilentlyContinue'
                Verbose        = $False
            }
            Enable-WindowsOptionalFeature @EnableParameters | Out-Null
        }
    }

    $FeaturesToDisable = @(
        $OnlineFeatures |
        Where-Object { $PSItem.FeatureName -in $DisableWindowsOptionalFeatures -and $PSItem.State -eq 'Enabled' } |
        Select-Object -ExpandProperty FeatureName
    )

    If ($FeaturesToDisable.Count -gt 0) {
        If ($PSCmdlet.ShouldProcess(($FeaturesToDisable -join ', '), 'Disable-WindowsOptionalFeature')) {
            Write-Verbose -Message "Disabling features: $($FeaturesToDisable -join ', ')"
            $DisableParameters = @{
                FeatureName    = $FeaturesToDisable
                Online         = $True
                NoRestart      = $True
                ProgressAction = 'SilentlyContinue'
                Verbose        = $False
            }
            Disable-WindowsOptionalFeature @DisableParameters | Out-Null
        }
    }
}
End {
}
