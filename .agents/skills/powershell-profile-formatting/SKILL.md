---
name: powershell-profile-formatting
description: >-
  Formats and structures all generated PowerShell scripts, functions, filters, and commands to match
  the author's PowerShell profile conventions. Use this skill whenever generating, writing, editing,
  refactoring, or reviewing any PowerShell (pwsh / powershell) code.
---

# PowerShell Profile Formatting & Style Guide

This skill governs the exact formatting, syntax conventions, and structural idioms used across the author's PowerShell profile (`PowerShellProfile.ps1`, `modules/*.ps1`, `Invoke-Configuration.ps1`, `Sync-Profile.ps1`). Whenever generating, writing, refactoring, or reviewing PowerShell code, strictly apply these conventions.

---

## 1. Keyword & Language Construct Casing (Strict PascalCase)

PowerShell keywords, special variables, and built-in constants must use **PascalCase** instead of all-lowercase:

* **Control Flow & Blocks**:
  * `If`, `Else`, `ElseIf` (never `if`, `else`, `elseif`)
  * `Return` (never `return`)
  * `While`, `For`, `ForEach` (never `while`, `for`, `foreach`)
  * `Begin`, `Process`, `End`
  * `Param`, `Filter`, `Function`
* **Booleans & Constants**:
  * `$True`, `$False`, `$Null` (never `$true`, `$false`, `$null`)
* **Automatic Variables**:
  * `$PSItem` (or `$_`), `$PROFILE` / `$Profile`, `$PSScriptRoot`, `$Env:<VarName>` (e.g., `$Env:UserName`, `$Env:OneDrive`, `$Env:LocalAppData`)
* **Logical & Bitwise Operators**:
  * `-not`, `-or`, `-and`, `-eq`, `-ne`, `-like`, `-notmatch`, `-bor`

---

## 2. Bracing and Layout (OTBS / One True Brace Style)

* **Opening brace `{`**: Placed on the same line as the statement or function declaration, separated by a single space:
  ```powershell
  If (...) {
      ...
  }
  Else {
      ...
  }
  ```
* **One-Liner Functions**: Simple wrappers are written on a single line with spaces inside braces:
  ```powershell
  Function Stop-ComputerForce { Stop-Computer -Force }
  Function Restart-ComputerForce { Restart-Computer -Force }
  ```
* **Indentation**: 4 spaces per indent level (never tabs).

---

## 3. Function & Filter Architecture

* **Use `Filter` for Pipeline Processors**:
  When creating pipeline-oriented utility commands that operate on incoming objects one-by-one, prefer `Filter` over `Function`:
  ```powershell
  Filter Format-ListAll (
      [Parameter(ValueFromPipeline)]
      $InputObject
  ) {
      $InputObject | Format-List *
  }
  ```
* **Advanced Functions**:
  Use `[CmdletBinding()]`, `Param (...)`, and explicit pipeline blocks (`Begin`, `Process`, `End`):
  ```powershell
  Function Get-CustomAsset {
      [CmdletBinding()]
      Param (
          [Parameter(Mandatory)]
          [String]
          $Path,
          [Parameter()]
          [Switch]
          $Force
      )
      Begin {
          ...
      }
      Process {
          ...
      }
      End {
          ...
      }
  }
  ```

---

## 4. Parameter Blocks & Attribute Formatting

* Attribute brackets, types, and parameter names are stacked vertically on separate lines:
  ```powershell
  [Parameter(
      Mandatory,
      ValueFromPipeline
  )]
  [ValidateScript({ Test-Path -Path $PSItem })]
  [String]
  $Path
  ```
* Type constraints should always be explicitly specified (e.g., `[String]`, `[Switch]`, `[String[]]`, `[Int]`, `[Hashtable]`).
* Multiple parameters are separated with trailing commas on the variable line:
  ```powershell
  Param (
      [Parameter()]
      [String]
      $PrimaryDirectory = "C:\Users\$Env:UserName\Data\",
      [Parameter()]
      [Switch]
      $AsDefault
  )
  ```

---

## 5. Hashtables & Alignment (Aligned Assignment Operators)

When defining multiline hashtables, **vertically align the equals signs (`=`)** by padding keys with spaces:

```powershell
$Parameters = @{
    Headers = @{
        Accept = 'application/octet-stream'
    }
    Uri     = $LatestReleaseInformation.assets.url
    OutFile = $TargetDirectory + 'Package.zip'
}

$Aliases = @{
    scf  = 'Stop-ComputerForce'
    rcf  = 'Restart-ComputerForce'
    lsf  = 'Get-ChildItemForce'
    b64e = 'ConvertTo-Base64'
    chef = 'Start-LocalCyberChef'
}
```

* **Colors / Configuration Hashtables**:
  ```powershell
  Set-PSReadLineOption -Colors @{
      Number             = "`e[39m"
      ContinuationPrompt = "`e[39m"
      Member             = "`e[39m"
      Type               = "`e[39m"
  }
  ```

---

## 6. Splatting Pattern

For cmdlets taking multiple parameters (especially web requests, process executions, or complex queries), construct a hashtable and use splatting (`@Parameters`):

```powershell
$RequestParameters = @{
    Headers = @{
        Accept = 'application/octet-stream'
    }
    Uri     = (Invoke-RestMethod -Uri $ReleaseUrl).assets.Where({ $_.Name -eq 'asset.tar.gz' }).url
    OutFile = $DestinationPath
}
Invoke-RestMethod @RequestParameters
```

---

## 7. Command & Parameter Names

* **Full Cmdlet Names**: Do not use cryptic PowerShell aliases (`ls`, `dir`, `gc`, `sc`, `iex`, `select`, `where`) inside generated scripts or functions. Use full PascalCase cmdlet names:
  * `Get-ChildItem` (not `ls` or `dir`)
  * `Get-Content` (not `cat` or `gc`)
  * `Select-Object` (not `select`)
  * `Where-Object` (not `where` or `?`)
  * `ForEach-Object` (not `foreach` or `%`)
  * `Invoke-Expression` (not `iex`)
  * `Invoke-RestMethod` (not `irm`)
* **Explicit Parameter Names**: Always specify explicit parameter flags in PascalCase:
  * `Get-ChildItem -Path $Path -Force`
  * `Start-Process wsl -ArgumentList "..." -Wait -NoNewWindow`
  * `Set-Alias -Name $Key -Value $Value`

---

## 8. Pipeline Chaining & Formatting

* Place spaces around pipeline pipes: `$InputObject | Select-Object -ExpandProperty $Property`.
* When breaking long pipelines across multiple lines, break after the pipe character (`|`), keeping the pipe on the preceding line or aligned at the start:
  ```powershell
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
  ```

---

## 9. String Literals vs. String Interpolation

* **Single quotes (`'...'`)**: Use for static strings, URLs, regexes, and literals without expansion:
  ```powershell
  $LatestRelease = 'https://api.github.com/repos/nix-community/NixOS-WSL/releases/latest'
  $Item = 'Stop-ComputerForce'
  ```
* **Double quotes (`"..."`)**: Use when interpolating variables or ANSI escape codes:
  ```powershell
  $FilePath = "C:\Users\$Env:UserName\CyberChef\"
  $Message = "A release already exists at $FilePath"
  $EscapeCode = "`e[39m"
  ```

---

## 10. Flattened Conditionals & Early-Exit Guard Clauses

Avoid deep nesting and pyramid-of-doom conditionals. Code should remain flat and readable by using early-exit guard clauses and decoupled top-level checks.

* **Early-Exit Guard Clauses (Functions & ScriptBlocks)**:
  Invert validation checks and return immediately (`Return`) when preconditions, files, or inputs are missing or invalid. Keep the main happy path at the root indentation level:
  ```powershell
  # Preferred: Flat with guard clauses
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
  ```

* **Decoupled Top-Level & Configuration Checks**:
  In script bodies and top-level profile configuration, do not nest dependent feature checks inside outer blocks. Cache module/command detection in cleanly typed variables or use compound `-and` conditions:
  ```powershell
  # Preferred: Cached flag and decoupled conditional blocks
  $HasPSReadLine = [Boolean](Get-Module -Name PSReadLine -ErrorAction SilentlyContinue)

  If ($HasPSReadLine) {
      Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
      Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
  }

  If ($HasPSReadLine -and (Get-Command -Name 'fzf' -ErrorAction SilentlyContinue)) {
      Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ScriptBlock { ... }
  }
  ```

---

## 11. Complete Reference Example

```powershell
[CmdletBinding()]
Param (
    [Parameter(
        Mandatory,
        ValueFromPipeline
    )]
    [ValidateNotNullOrEmpty()]
    [String]
    $InputDirectory,
    [Parameter()]
    [Switch]
    $Force
)
Begin {
    If (-not (Test-Path -Path $InputDirectory)) {
        Write-Warning -Message "Directory $InputDirectory does not exist."
        Return
    }
}
Process {
    $ArchiveParameters = @{
        Path            = $InputDirectory
        DestinationPath = "$InputDirectory.zip"
        Force           = $Force.IsPresent
    }
    Compress-Archive @ArchiveParameters
}
End {
    Get-ChildItem -Path "$InputDirectory.zip" | Format-ListAll
}
```
