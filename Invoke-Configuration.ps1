[CmdletBinding()]
Param (
    [Parameter()]
    [String[]]
    $WindowsCapabilities = @(
        "Microsoft.Windows.PowerShell.ISE~~~~0.0.1.0",
        "Microsoft.Windows.WordPad~~~~0.0.1.0",
        "Media.WindowsMediaPlayer~~~~0.0.12.0"
    ),
    [Parameter()]
    [String[]]
    $EnableWindowsOptionalFeatures = @(
        "HostGuardian",
        "HypervisorPlatform",
        "VirtualMachinePlatform",
        "Containers-DisposableClientVM",
        "Microsoft-Hyper-V-All",
        "Microsoft-Hyper-V",
        "Microsoft-Hyper-V-Tools-All",
        "Microsoft-Hyper-V-Management-PowerShell",
        "Microsoft-Hyper-V-Hypervisor",
        "Microsoft-Hyper-V-Services",
        "Microsoft-Hyper-V-Management-Clients",
        "Windows-Defender-ApplicationGuard"
    ),
    [Parameter()]
    [String[]]
    $DisableWindowsOptionalFeatures = @(
        "Printing-XPSServices-Features",
        "TelnetClient",
        "TIFFIFilter",
        "LegacyComponents",
        "DirectPlay",
        "MSRDC-Infrastructure",
        "Windows-Identity-Foundation",
        "MicrosoftWindowsPowerShellV2Root",
        "MicrosoftWindowsPowerShellV2",
        "SimpleTCP",
        "SMB1Protocol-Deprecation",
        "WCF-HTTP-Activation",
        "WCF-NonHTTP-Activation",
        "WCF-HTTP-Activation45",
        "WCF-TCP-Activation45",
        "WCF-Pipe-Activation45",
        "WCF-MSMQ-Activation45",
        "MediaPlayback",
        "AppServerClient",
        "Printing-Foundation-Features",
        "Printing-Foundation-InternetPrinting-Client",
        "Printing-Foundation-LPDPrintService",
        "Printing-Foundation-LPRPortMonitor",
        "DataCenterBridging",
        "ServicesForNFS-ClientOnly",
        "ClientForNFS-Infrastructure",
        "NFS-Administration",
        "SMB1Protocol",
        "SMB1Protocol-Client",
        "SMB1Protocol-Server",
        "MultiPoint-Connector",
        "MultiPoint-Connector-Services",
        "MultiPoint-Tools",
        "TFTP",
        "Microsoft-RemoteDesktopConnection",
        "Microsoft-Windows-Subsystem-Linux",
        "Client-ProjFS",
        "Client-DeviceLockdown",
        "Client-EmbeddedShellLauncher",
        "Client-EmbeddedBootExp",
        "Client-EmbeddedLogon",
        "Client-KeyboardFilter",
        "Client-UnifiedWriteFilter",
        "DirectoryServices-ADAM-Client",
        "IIS-WebServerRole",
        "IIS-WebServer",
        "IIS-CommonHttpFeatures",
        "IIS-HttpErrors",
        "IIS-HttpRedirect",
        "IIS-ApplicationDevelopment",
        "IIS-Security",
        "IIS-RequestFiltering",
        "IIS-NetFxExtensibility",
        "IIS-NetFxExtensibility45",
        "IIS-HealthAndDiagnostics",
        "IIS-HttpLogging",
        "IIS-LoggingLibraries",
        "IIS-RequestMonitor",
        "IIS-HttpTracing",
        "IIS-URLAuthorization",
        "IIS-IPSecurity",
        "IIS-Performance",
        "IIS-HttpCompressionDynamic",
        "IIS-WebServerManagementTools",
        "IIS-ManagementScriptingTools",
        "IIS-IIS6ManagementCompatibility",
        "IIS-Metabase",
        "WAS-WindowsActivationService",
        "WAS-ProcessModel",
        "WAS-NetFxEnvironment",
        "WAS-ConfigurationAPI",
        "IIS-HostableWebCore",
        "IIS-StaticContent",
        "IIS-DefaultDocument",
        "IIS-DirectoryBrowsing",
        "IIS-WebDAV",
        "IIS-WebSockets",
        "IIS-ApplicationInit",
        "IIS-ISAPIFilter",
        "IIS-ISAPIExtensions",
        "IIS-ASPNET",
        "IIS-ASPNET45",
        "IIS-ASP",
        "IIS-CGI",
        "IIS-ServerSideIncludes",
        "IIS-CustomLogging",
        "IIS-BasicAuthentication",
        "IIS-HttpCompressionStatic",
        "IIS-ManagementConsole",
        "IIS-ManagementService",
        "IIS-WMICompatibility",
        "IIS-LegacyScripts",
        "IIS-LegacySnapIn",
        "IIS-FTPServer",
        "IIS-FTPSvc",
        "IIS-FTPExtensibility",
        "MSMQ-Container",
        "MSMQ-DCOMProxy",
        "MSMQ-Server",
        "MSMQ-ADIntegration",
        "MSMQ-HTTP",
        "MSMQ-Multicast",
        "MSMQ-Triggers",
        "IIS-CertProvider",
        "IIS-WindowsAuthentication",
        "IIS-DigestAuthentication",
        "IIS-ClientCertificateMappingAuthentication",
        "IIS-IISCertificateMappingAuthentication",
        "IIS-ODBCLogging",
        "NetFx4Extended-ASPNET45",
        "Containers",
        "Containers-HNS",
        "Containers-SDN"
    )
)
Begin {

}
Process {
    Get-Content -Path $PSScriptRoot\winget_profile.txt | Invoke-Expression

    Write-Output $PSScriptRoot
    
    $WindowsCapabilities | ForEach-Object -Process {
        Remove-WindowsCapability -Name $PSItem -Online
    }

    $EnableWindowsOptionalFeatures | ForEach-Object {
        Enable-WindowsOptionalFeature -FeatureName $PSItem -Online
    }

    $DisableWindowsOptionalFeatures | ForEach-Object {
        Disable-WindowsOptionalFeature -FeatureName $PSItem -Online
    }
}
End {

}