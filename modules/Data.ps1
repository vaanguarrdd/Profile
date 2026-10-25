<#
.SYNOPSIS
    Data processing and analytical pipeline utilities for the PowerShell profile.
.DESCRIPTION
    Provides streaming newline-delimited JSON (JSONL/NDJSON) pipeline filters and
    in-process DuckDB SQL wrappers for querying, inspecting schemas, and converting
    Parquet, CSV, and JSONL datasets directly into PowerShell objects.
#>

Filter ConvertFrom-JsonLines (
    [Parameter(
        Mandatory,
        ValueFromPipeline,
        ValueFromPipelineByPropertyName
    )]
    [Alias('FullName')]
    [ValidateNotNullOrEmpty()]
    [String]
    $InputObject
) {
    <#
    .SYNOPSIS
        Streams and parses JSON Lines (JSONL / NDJSON) from a file path or string pipeline.
    .DESCRIPTION
        If InputObject resolves to an existing file on disk, streams the file line-by-line
        using [System.IO.File]::ReadLines to avoid loading large files into memory at once.
        Otherwise, parses the incoming string directly as a single JSON line.
    .PARAMETER InputObject
        Path to a .jsonl/.ndjson file, or an individual JSON line string from the pipeline.
    .EXAMPLE
        ConvertFrom-JsonLines -InputObject '.\events.jsonl' | Where-Object { $PSItem.status -eq 500 }
        Streams events.jsonl and filters records in the PowerShell pipeline.
    .EXAMPLE
        Get-Content -Path '.\logs.jsonl' | fromjsonl
        Uses the profile alias to parse piped JSON lines into PowerShell objects.
    #>
    If (Test-Path -LiteralPath $InputObject -PathType Leaf) {
        $ResolvedFile = (Resolve-Path -LiteralPath $InputObject).Path
        ForEach ($Line in [System.IO.File]::ReadLines($ResolvedFile)) {
            If (-not [String]::IsNullOrWhiteSpace($Line)) {
                $Line | ConvertFrom-Json
            }
        }
    }
    Else {
        ForEach ($Line in ($InputObject -split '\r?\n')) {
            If (-not [String]::IsNullOrWhiteSpace($Line)) {
                $Line | ConvertFrom-Json
            }
        }
    }
}

Filter ConvertTo-JsonLines (
    [Parameter(
        Mandatory,
        ValueFromPipeline
    )]
    $InputObject,
    [Parameter()]
    [Int]
    $Depth = 10
) {
    <#
    .SYNOPSIS
        Serializes pipeline objects into single-line JSON Lines (JSONL / NDJSON) format.
    .DESCRIPTION
        Converts each incoming pipeline object into a single-line compressed JSON string
        suitable for streaming to .jsonl files or analytical ingestion pipelines.
    .PARAMETER InputObject
        The PowerShell object to serialize.
    .PARAMETER Depth
        Maximum serialization depth for nested objects. Defaults to 10.
    .EXAMPLE
        Get-Process | Select-Object -Property Name, Id, WorkingSet64 | ConvertTo-JsonLines
        Outputs each process as a single-line JSON record.
    .EXAMPLE
        Get-Service | tojsonl | Set-Content -Path '.\services.jsonl'
        Writes all services to a newline-delimited JSON file.
    #>
    $JsonParameters = @{
        InputObject = $InputObject
        Compress    = $True
        Depth       = $Depth
    }
    ConvertTo-Json @JsonParameters
}

Function Invoke-DuckDbQuery {
    <#
    .SYNOPSIS
        Executes an in-process SQL query over Parquet, CSV, or JSONL files via DuckDB.
    .DESCRIPTION
        Invokes the DuckDB CLI with JSON output ('duckdb -json -c') and deserializes
        the result set into native PowerShell objects for seamless pipeline composition.
    .PARAMETER Query
        The SQL query string to execute in DuckDB.
    .EXAMPLE
        Invoke-DuckDbQuery -Query "SELECT status, count(*) AS total FROM 'logs.parquet' GROUP BY status"
        Aggregates status counts from logs.parquet and outputs PSCustomObjects.
    .EXAMPLE
        dql "SELECT * FROM 'dataset.csv' LIMIT 5" | fla
        Uses the profile alias to query a CSV and format all columns as a list.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Query
    )
    Begin {
        If (-not (Get-Command -Name 'duckdb' -ErrorAction SilentlyContinue)) {
            Throw 'DuckDB CLI (duckdb) is not installed or not on PATH.'
        }
    }
    Process {
        $RawJson = (& duckdb -json -c $Query) | Out-String
        If (-not [String]::IsNullOrWhiteSpace($RawJson)) {
            $RawJson | ConvertFrom-Json
        }
    }
    End {
    }
}

Function Show-DataSchema {
    <#
    .SYNOPSIS
        Inspects column names and data types of a Parquet, CSV, or JSONL file using DuckDB.
    .DESCRIPTION
        Runs a DuckDB DESCRIBE query against the target file and returns the schema
        metadata (column_name, column_type, null) as PowerShell objects.
    .PARAMETER Path
        Path to the target .parquet, .csv, .json, or .jsonl file.
    .EXAMPLE
        Show-DataSchema -Path '.\telemetry.parquet'
        Displays all column names and types for telemetry.parquet.
    .EXAMPLE
        dschema '.\events.jsonl'
        Uses the profile alias to inspect the inferred schema of events.jsonl.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias('FullName')]
        [ValidateScript({ Test-Path -LiteralPath $PSItem -PathType Leaf })]
        [String]
        $Path
    )
    Begin {
        If (-not (Get-Command -Name 'duckdb' -ErrorAction SilentlyContinue)) {
            Throw 'DuckDB CLI (duckdb) is not installed or not on PATH.'
        }
    }
    Process {
        $ResolvedPath = (Resolve-Path -LiteralPath $Path).Path.Replace("'", "''")
        $SqlQuery = "DESCRIBE SELECT * FROM '$ResolvedPath';"
        Invoke-DuckDbQuery -Query $SqlQuery
    }
    End {
    }
}

Function ConvertTo-Parquet {
    <#
    .SYNOPSIS
        Converts a CSV, JSON, or JSONL file into a ZSTD-compressed Apache Parquet file.
    .DESCRIPTION
        Uses DuckDB's vectorized execution engine to read the source dataset and write
        an optimized ZSTD-compressed Parquet file. Defaults to replacing the input file
        extension with '.parquet' when OutputPath is omitted.
    .PARAMETER InputPath
        Path to the source .csv, .json, or .jsonl file.
    .PARAMETER OutputPath
        Destination path for the generated .parquet file.
    .EXAMPLE
        ConvertTo-Parquet -InputPath '.\access_logs.jsonl'
        Creates .\access_logs.parquet compressed with ZSTD.
    .EXAMPLE
        toparquet '.\raw_export.csv' '.\clean_export.parquet'
        Uses the profile alias to convert CSV data to Parquet.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [Alias('FullName')]
        [ValidateScript({ Test-Path -LiteralPath $PSItem -PathType Leaf })]
        [String]
        $InputPath,
        [Parameter(Position = 1)]
        [String]
        $OutputPath
    )
    Begin {
        If (-not (Get-Command -Name 'duckdb' -ErrorAction SilentlyContinue)) {
            Throw 'DuckDB CLI (duckdb) is not installed or not on PATH.'
        }
    }
    Process {
        $ResolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
        $TargetOutput = If ([String]::IsNullOrWhiteSpace($OutputPath)) {
            [System.IO.Path]::ChangeExtension($ResolvedInput, '.parquet')
        }
        Else {
            $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
        }

        $EscapedInput = $ResolvedInput.Replace("'", "''")
        $EscapedOutput = $TargetOutput.Replace("'", "''")
        $SqlCommand = "COPY (SELECT * FROM '$EscapedInput') TO '$EscapedOutput' (FORMAT PARQUET, COMPRESSION ZSTD);"
        & duckdb -c $SqlCommand
        If (Test-Path -LiteralPath $TargetOutput) {
            Get-Item -LiteralPath $TargetOutput
        }
    }
    End {
    }
}
