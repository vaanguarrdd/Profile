<#
.SYNOPSIS
    Registers native argument completion for wslc and docker container commands.
.DESCRIPTION
    Provides dynamic contextual tab completion for wslc, wslc.exe, docker, and wc commands,
    including primary commands, subcommands, flags, active container names and IDs,
    and local image tags and IDs.
.EXAMPLE
    wslc <Tab>
    Displays all available top-level commands (e.g. attach, build, container, exec, image, run).
.EXAMPLE
    docker container <Tab>
    Displays container subcommands (e.g. attach, create, exec, logs, start, stop).
.EXAMPLE
    wslc logs <Tab>
    Dynamically completes with currently active container names or IDs.
#>

Register-ArgumentCompleter -Native -CommandName 'wslc', 'wslc.exe', 'docker', 'wc' -ScriptBlock {
    Param (
        $WordToComplete,
        $CommandAst,
        $CursorPosition
    )

    $RootCommands = @{
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

    $SubCommands = @{
        'container' = @('attach', 'cp', 'create', 'exec', 'export', 'inspect', 'kill', 'list', 'logs', 'prune', 'remove', 'run', 'start', 'stats', 'stop')
        'image'     = @('build', 'import', 'inspect', 'list', 'load', 'prune', 'pull', 'push', 'remove', 'save', 'tag')
        'network'   = @('connect', 'create', 'disconnect', 'inspect', 'list', 'prune', 'remove')
        'volume'    = @('create', 'inspect', 'list', 'prune', 'remove')
        'system'    = @('info', 'session')
        'registry'  = @('login', 'logout')
    }

    $Elements = @($CommandAst.CommandElements)
    If ($Elements.Count -eq 0) {
        Return
    }

    If ($CursorPosition -gt $Elements[-1].Extent.EndOffset) {
        $ArgIndex = $Elements.Count
        $PrevArgs = @(If ($Elements.Count -gt 1) { $Elements[1..($Elements.Count - 1)] | ForEach-Object { $PSItem.Extent.Text } })
    }
    Else {
        $ArgIndex = $Elements.Count - 1
        $PrevArgs = @(If ($Elements.Count -gt 2) { $Elements[1..($Elements.Count - 2)] | ForEach-Object { $PSItem.Extent.Text } })
    }

    $GetContainers = {
        $Raw = wslc list -a --format json 2>$Null
        If ($Raw) {
            ForEach ($Line in $Raw) {
                Try {
                    $Container = $Line | ConvertFrom-Json
                    If ($Container.Names -and $Container.Names -like "$WordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new(
                            $Container.Names,
                            $Container.Names,
                            'ParameterValue',
                            "Container: $($Container.Names) ($($Container.Image)) [$($Container.State)]"
                        )
                    }
                    If ($Container.ID -and $Container.ID -like "$WordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new(
                            $Container.ID,
                            $Container.ID,
                            'ParameterValue',
                            "Container: $($Container.ID) ($($Container.Names)) [$($Container.State)]"
                        )
                    }
                }
                Catch {
                }
            }
        }
    }

    $GetImages = {
        $Raw = wslc images --format json 2>$Null
        If ($Raw) {
            ForEach ($Line in $Raw) {
                Try {
                    $Image = $Line | ConvertFrom-Json
                    $Tag = If ($Image.Repository -and $Image.Tag) { "$($Image.Repository):$($Image.Tag)" } Else { $Null }
                    If ($Tag -and $Tag -like "$WordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new(
                            $Tag,
                            $Tag,
                            'ParameterValue',
                            "Image: $Tag ($($Image.ID))"
                        )
                    }
                    If ($Image.ID -and $Image.ID -like "$WordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new(
                            $Image.ID,
                            $Image.ID,
                            'ParameterValue',
                            "Image ID: $($Image.ID) ($Tag)"
                        )
                    }
                }
                Catch {
                }
            }
        }
    }

    If ($ArgIndex -eq 1) {
        $RootCommands.GetEnumerator() |
        Where-Object { $PSItem.Key -like "$WordToComplete*" } |
        Sort-Object -Property Key |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $PSItem.Key,
                $PSItem.Key,
                'Command',
                $PSItem.Value
            )
        }
        Return
    }

    $Primary = $PrevArgs[0]

    If ($ArgIndex -eq 2) {
        If ($SubCommands.ContainsKey($Primary)) {
            $SubCommands[$Primary] |
            Where-Object { $PSItem -like "$WordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $PSItem,
                    $PSItem,
                    'ParameterValue',
                    "$Primary $PSItem"
                )
            }
            Return
        }

        If ($Primary -in @('attach', 'exec', 'kill', 'logs', 'remove', 'start', 'stop', 'inspect')) {
            & $GetContainers
            Return
        }

        If ($Primary -in @('run', 'rmi', 'tag', 'push')) {
            & $GetImages
            Return
        }
    }

    If ($ArgIndex -eq 3) {
        $SubCommand = $PrevArgs[1]
        If ($Primary -eq 'container' -and $SubCommand -in @('attach', 'exec', 'kill', 'logs', 'remove', 'start', 'stop', 'inspect')) {
            & $GetContainers
            Return
        }

        If ($Primary -eq 'image' -and $SubCommand -in @('remove', 'inspect', 'tag', 'push')) {
            & $GetImages
            Return
        }
    }
}
