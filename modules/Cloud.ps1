<#
.SYNOPSIS
    Cloud build, Kubernetes, and WSL container utilities for the PowerShell profile.
.DESCRIPTION
    Provides interactive context switchers and build log streamers for Google Cloud
    (gcloud / Cloud Build), Kubernetes (kubectl), and NixOS-WSL provisioning,
    integrating with fzf for fuzzy interactive selection when parameters are omitted.
#>

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

Function Switch-GcpProject {
    <#
    .SYNOPSIS
        Switches the active Google Cloud project in gcloud.
    .DESCRIPTION
        Sets the active gcloud project configuration. When ProjectId is omitted and
        fzf is installed, queries accessible GCP projects and opens an interactive
        fuzzy selector.
    .PARAMETER ProjectId
        The GCP Project ID to activate.
    .EXAMPLE
        Switch-GcpProject -ProjectId 'my-production-project'
        Activates 'my-production-project' in gcloud.
    .EXAMPLE
        gproj
        Uses the profile alias to interactively select a GCP project via fzf.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [String]
        $ProjectId
    )
    Begin {
        If (-not (Get-Command -Name 'gcloud' -ErrorAction SilentlyContinue)) {
            Throw 'Google Cloud SDK (gcloud) is not installed or not on PATH.'
        }
    }
    Process {
        $TargetProject = $ProjectId
        If ([String]::IsNullOrWhiteSpace($TargetProject)) {
            If (-not (Get-Command -Name 'fzf' -ErrorAction SilentlyContinue)) {
                Throw 'Please provide -ProjectId or install fzf for interactive project selection.'
            }
            $ProjectList = & gcloud projects list --format='value(projectId)'
            If ($ProjectList) {
                $TargetProject = ($ProjectList | & fzf --height=40% --reverse --prompt='GCP Project> ')
            }
        }

        If (-not [String]::IsNullOrWhiteSpace($TargetProject)) {
            & gcloud config set project $TargetProject.Trim()
        }
    }
    End {
    }
}

Function Watch-CloudBuild {
    <#
    .SYNOPSIS
        Streams real-time logs or inspects recent executions in Google Cloud Build.
    .DESCRIPTION
        Streams build logs via 'gcloud builds log --stream'. When BuildId is omitted,
        either automatically selects the most recent build (-Latest) or presents recent
        builds in an interactive fzf selector.
    .PARAMETER BuildId
        Specific Cloud Build UUID to stream.
    .PARAMETER Limit
        Maximum number of recent builds to query when selecting interactively. Defaults to 20.
    .PARAMETER Latest
        Immediately streams the most recently created Cloud Build job without prompting.
    .EXAMPLE
        Watch-CloudBuild -Latest
        Streams logs for the latest Cloud Build execution in the active GCP project.
    .EXAMPLE
        gcb
        Uses the profile alias to pick a recent Cloud Build execution via fzf and stream its logs.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [String]
        $BuildId,
        [Parameter()]
        [Int]
        $Limit = 20,
        [Parameter()]
        [Switch]
        $Latest
    )
    Begin {
        If (-not (Get-Command -Name 'gcloud' -ErrorAction SilentlyContinue)) {
            Throw 'Google Cloud SDK (gcloud) is not installed or not on PATH.'
        }
    }
    Process {
        $TargetBuild = $BuildId
        If ([String]::IsNullOrWhiteSpace($TargetBuild)) {
            If ($Latest.IsPresent -or -not (Get-Command -Name 'fzf' -ErrorAction SilentlyContinue)) {
                $TargetBuild = (& gcloud builds list --limit=1 --format='value(id)') | Select-Object -First 1
            }
            Else {
                $BuildCandidates = & gcloud builds list --limit=$Limit --format='value(id,status,createTime,logUrl)'
                If ($BuildCandidates) {
                    $SelectedLine = $BuildCandidates | & fzf --height=40% --reverse --prompt='Cloud Build> '
                    If (-not [String]::IsNullOrWhiteSpace($SelectedLine)) {
                        $TargetBuild = ($SelectedLine -split '\s+')[0]
                    }
                }
            }
        }

        If (-not [String]::IsNullOrWhiteSpace($TargetBuild)) {
            & gcloud builds log $TargetBuild.Trim() --stream
        }
    }
    End {
    }
}

Function Switch-KubeContext {
    <#
    .SYNOPSIS
        Switches the active Kubernetes context in kubectl.
    .DESCRIPTION
        Changes the active kubeconfig context via 'kubectl config use-context'.
        When Context is omitted and fzf is available, opens an interactive fuzzy
        selector populated with all configured contexts.
    .PARAMETER Context
        Name of the Kubernetes context to activate.
    .EXAMPLE
        Switch-KubeContext -Context 'gke_prod_us-central1_cluster-1'
        Switches kubectl to the specified GKE context.
    .EXAMPLE
        kctx
        Uses the profile alias to interactively select a Kubernetes context via fzf.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [String]
        $Context
    )
    Begin {
        If (-not (Get-Command -Name 'kubectl' -ErrorAction SilentlyContinue)) {
            Throw 'kubectl is not installed or not on PATH.'
        }
    }
    Process {
        $TargetContext = $Context
        If ([String]::IsNullOrWhiteSpace($TargetContext)) {
            If (-not (Get-Command -Name 'fzf' -ErrorAction SilentlyContinue)) {
                & kubectl config get-contexts
                Return
            }
            $Contexts = & kubectl config get-contexts -o name
            If ($Contexts) {
                $TargetContext = $Contexts | & fzf --height=40% --reverse --prompt='Kube Context> '
            }
        }

        If (-not [String]::IsNullOrWhiteSpace($TargetContext)) {
            & kubectl config use-context $TargetContext.Trim()
        }
    }
    End {
    }
}

Function Switch-KubeNamespace {
    <#
    .SYNOPSIS
        Switches the default Kubernetes namespace for the active kubectl context.
    .DESCRIPTION
        Updates the current context's default namespace via 'kubectl config set-context --current'.
        When Namespace is omitted and fzf is available, queries cluster namespaces and
        opens an interactive fuzzy selector.
    .PARAMETER Namespace
        Name of the Kubernetes namespace to set as default.
    .EXAMPLE
        Switch-KubeNamespace -Namespace 'kube-system'
        Sets 'kube-system' as the active namespace.
    .EXAMPLE
        kns
        Uses the profile alias to interactively select a Kubernetes namespace via fzf.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Position = 0,
            ValueFromPipeline
        )]
        [String]
        $Namespace
    )
    Begin {
        If (-not (Get-Command -Name 'kubectl' -ErrorAction SilentlyContinue)) {
            Throw 'kubectl is not installed or not on PATH.'
        }
    }
    Process {
        $TargetNamespace = $Namespace
        If ([String]::IsNullOrWhiteSpace($TargetNamespace)) {
            If (-not (Get-Command -Name 'fzf' -ErrorAction SilentlyContinue)) {
                & kubectl get namespaces
                Return
            }
            $RawNamespaces = & kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'
            If (-not [String]::IsNullOrWhiteSpace($RawNamespaces)) {
                $NamespaceList = $RawNamespaces -split '\s+'
                $TargetNamespace = $NamespaceList | & fzf --height=40% --reverse --prompt='Kube Namespace> '
            }
        }

        If (-not [String]::IsNullOrWhiteSpace($TargetNamespace)) {
            & kubectl config set-context --current "--namespace=$($TargetNamespace.Trim())"
        }
    }
    End {
    }
}
