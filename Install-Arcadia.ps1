#Requires -Version 5.1
<#
.SYNOPSIS
    Merges ArcadiaProject content into an existing Reforged Eden 2 scenario copy.

.DESCRIPTION
    Automates steps 4-11 from Installation Instructions.md. Requires a fresh copy of
    Reforged Eden 2 already placed in Empyrion\Content\Scenarios.

.PARAMETER ScenarioPath
    Path to the RE2 scenario folder (e.g. ...\Content\Scenarios\MyRE2Scenario).

.PARAMETER ModPath
    Path to this ArcadiaProject repo. Defaults to the script directory.

.PARAMETER WhatIf
    Log planned actions without writing files.

.EXAMPLE
    .\Install-ArcadiaMod.ps1 -ScenarioPath "D:\Steam\...\Content\Scenarios\MyRE2Scenario"
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$ScenarioPath,

    [string]$ModPath = $PSScriptRoot,

    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DryRun = $PSBoundParameters.ContainsKey('WhatIf') -and [bool]$WhatIf

$MergeAnchors = @{
    DialoguesEcf = '\{ \+Dialogue Name: Trader_DialogueSwitch_Start'
    SectorsYaml  = "Alpha \[Sun Back\].*SpaceWarpTargetFixed"
    PdaYaml      = '^\s*Chapters:\s*$'
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step {
    param(
        [int]$Number,
        [string]$Message
    )
    Write-Host ("[{0}] {1}" -f $Number, $Message)
}

function Read-TextFile {
    param([string]$Path)
    [System.IO.File]::ReadAllText($Path, $Utf8NoBom)
}

function Write-TextFile {
    param(
        [string]$Path,
        [string]$Content
    )

    if ($DryRun) {
        Write-Host "  [WhatIf] Would write: $Path"
        return
    }

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrEmpty($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Test-RequiredPath {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing required $Description`: $Path"
    }
}

function Test-AnchorPresent {
    param(
        [string]$FilePath,
        [string]$Pattern,
        [string]$Description
    )

    $lines = (Read-TextFile -Path $FilePath) -split "`r?`n"
    $found = $false
    foreach ($line in $lines) {
        if ($line -match $Pattern) {
            $found = $true
            break
        }
    }

    if (-not $found) {
        throw "Anchor not found in $Description ($FilePath): expected pattern matching '$Pattern'. Wrong scenario folder or RE2 version drift."
    }
}

function Test-ArcadiaInstalled {
    param([string]$Root)

    $warnings = @()

    $sectorsPath = Join-Path $Root 'Sectors\Sectors.yaml'
    if (Test-Path -LiteralPath $sectorsPath) {
        $sectors = Read-TextFile -Path $sectorsPath
        if ($sectors -match '_ARC_ARCADIASTATION|Arcadia Station') {
            $warnings += 'Sectors.yaml already contains Arcadia Station entries.'
        }
    }

    $tokenPath = Join-Path $Root 'Content\Configuration\TokenConfig.ecf'
    if (Test-Path -LiteralPath $tokenPath) {
        $tokens = Read-TextFile -Path $tokenPath
        if ($tokens -match 'Token Id: 7238|CacheKey') {
            $warnings += 'TokenConfig.ecf already contains Arcadia CacheKey token (7238).'
        }
    }

    $traderPath = Join-Path $Root 'Content\Configuration\TraderNPCConfig.ecf'
    if (Test-Path -LiteralPath $traderPath) {
        $traders = Read-TextFile -Path $traderPath
        if ($traders -match 'Trader Name: ARC_Goods') {
            $warnings += 'TraderNPCConfig.ecf already contains ARC_Goods trader.'
        }
    }

    return $warnings
}

function Merge-CsvAfterHeader {
    param(
        [string]$TargetPath,
        [string]$SourcePath
    )

    $source = (Read-TextFile -Path $SourcePath).TrimEnd("`r", "`n")
    $target = Read-TextFile -Path $TargetPath
    $lines = $target -split "`r?`n", -1

    if ([string]::IsNullOrWhiteSpace($source)) {
        Write-Host "  Skipping empty source: $SourcePath"
        return
    }

    if ($lines.Count -lt 1 -or [string]::IsNullOrWhiteSpace($lines[0])) {
        throw "Target CSV has no header row: $TargetPath"
    }

    $header = $lines[0]
    $body = if ($lines.Count -gt 1) {
        ($lines[1..($lines.Count - 1)] -join [Environment]::NewLine).TrimEnd("`r", "`n")
    }
    else {
        ''
    }

    $merged = $header + [Environment]::NewLine + $source
    if (-not [string]::IsNullOrEmpty($body)) {
        $merged += [Environment]::NewLine + $body
    }
    $merged += [Environment]::NewLine

    Write-TextFile -Path $TargetPath -Content $merged
}

function Merge-TextBeforeAnchor {
    param(
        [string]$TargetPath,
        [string]$SourcePath,
        [string]$AnchorPattern
    )

    $source = Read-TextFile -Path $SourcePath
    $target = Read-TextFile -Path $TargetPath
    $lines = $target -split "`r?`n", -1

    $anchorIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $AnchorPattern) {
            $anchorIndex = $i
            break
        }
    }

    if ($anchorIndex -lt 0) {
        throw "Anchor not found in $TargetPath"
    }

    $prefix = ($lines[0..($anchorIndex - 1)] -join [Environment]::NewLine)
    $suffix = ($lines[$anchorIndex..($lines.Count - 1)] -join [Environment]::NewLine)

    $sourceTrimmed = $source.TrimEnd("`r", "`n")
    $prefixTrimmed = $prefix.TrimEnd("`r", "`n")

    $merged = if ([string]::IsNullOrEmpty($prefixTrimmed)) {
        $sourceTrimmed + [Environment]::NewLine + $suffix
    }
    else {
        $prefixTrimmed + [Environment]::NewLine + $sourceTrimmed + [Environment]::NewLine + $suffix
    }

    Write-TextFile -Path $TargetPath -Content $merged
}

function Merge-TextAfterAnchor {
    param(
        [string]$TargetPath,
        [string]$SourcePath,
        [string]$AnchorPattern
    )

    $source = (Read-TextFile -Path $SourcePath).TrimEnd("`r", "`n")
    $target = Read-TextFile -Path $TargetPath
    $lines = $target -split "`r?`n", -1

    $anchorIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $AnchorPattern) {
            $anchorIndex = $i
            break
        }
    }

    if ($anchorIndex -lt 0) {
        throw "Anchor not found in $TargetPath"
    }

    $before = ($lines[0..$anchorIndex] -join [Environment]::NewLine)
    $after = if ($anchorIndex + 1 -lt $lines.Count) {
        ($lines[($anchorIndex + 1)..($lines.Count - 1)] -join [Environment]::NewLine)
    }
    else {
        ''
    }

    $merged = $before + [Environment]::NewLine + $source
    if (-not [string]::IsNullOrEmpty($after)) {
        $merged += [Environment]::NewLine + $after
    }
    $merged += [Environment]::NewLine

    Write-TextFile -Path $TargetPath -Content $merged
}

function Merge-TextAppend {
    param(
        [string]$TargetPath,
        [string]$SourcePath
    )

    $source = Read-TextFile -Path $SourcePath
    $target = Read-TextFile -Path $TargetPath

    $targetTrimmed = $target.TrimEnd("`r", "`n")
    $sourceTrimmed = $source.TrimStart("`r", "`n").TrimEnd("`r", "`n")

    if ([string]::IsNullOrWhiteSpace($sourceTrimmed)) {
        Write-Host "  Skipping empty source: $SourcePath"
        return
    }

    $merged = if ([string]::IsNullOrEmpty($targetTrimmed)) {
        $sourceTrimmed + [Environment]::NewLine
    }
    else {
        $targetTrimmed + [Environment]::NewLine + $sourceTrimmed + [Environment]::NewLine
    }

    Write-TextFile -Path $TargetPath -Content $merged
}

function Copy-ModPlayfields {
    param(
        [string]$SourceRoot,
        [string]$TargetRoot
    )

    $sourcePlayfields = Join-Path $SourceRoot 'Playfields'
    $targetPlayfields = Join-Path $TargetRoot 'Playfields'

    if (-not (Test-Path -LiteralPath $targetPlayfields)) {
        if ($DryRun) {
            Write-Host "  [WhatIf] Would create: $targetPlayfields"
        }
        else {
            New-Item -ItemType Directory -Path $targetPlayfields -Force | Out-Null
        }
    }

    $folders = Get-ChildItem -LiteralPath $sourcePlayfields -Directory
    foreach ($folder in $folders) {
        $destination = Join-Path $targetPlayfields $folder.Name
        if ($DryRun) {
            Write-Host "  [WhatIf] Would copy folder: $($folder.Name) -> $destination"
            continue
        }

        if (Test-Path -LiteralPath $destination) {
            Remove-Item -LiteralPath $destination -Recurse -Force
        }

        Copy-Item -LiteralPath $folder.FullName -Destination $destination -Recurse -Force

        Get-ChildItem -LiteralPath $destination -Recurse -File -Filter '*.oldprevious' -ErrorAction SilentlyContinue |
            Remove-Item -Force
    }
}

function Copy-ModPrefabs {
    param(
        [string]$SourceRoot,
        [string]$TargetRoot
    )

    $sourcePrefabs = Join-Path $SourceRoot 'Prefabs'
    $targetPrefabs = Join-Path $TargetRoot 'Prefabs'

    if (-not (Test-Path -LiteralPath $targetPrefabs)) {
        if ($DryRun) {
            Write-Host "  [WhatIf] Would create: $targetPrefabs"
        }
        else {
            New-Item -ItemType Directory -Path $targetPrefabs -Force | Out-Null
        }
    }

    $prefabFiles = Get-ChildItem -LiteralPath $sourcePrefabs -File
    if ($prefabFiles.Count -eq 0) {
        Write-Host '  No prefab files found in mod Prefabs folder.'
        return
    }

    foreach ($prefabFile in $prefabFiles) {
        $destination = Join-Path $targetPrefabs $prefabFile.Name
        if ($DryRun) {
            Write-Host "  [WhatIf] Would copy file: $($prefabFile.Name) -> $destination"
            continue
        }

        Copy-Item -LiteralPath $prefabFile.FullName -Destination $destination -Force
    }
}

function Copy-ModSharedData {
    param(
        [string]$SourceRoot,
        [string]$TargetRoot
    )

    $sourceSharedData = Join-Path $SourceRoot 'SharedData'
    if (-not (Test-Path -LiteralPath $sourceSharedData)) {
        Write-Host '  SharedData not present in mod - skipped.'
        return
    }

    $sharedFiles = @(Get-ChildItem -LiteralPath $sourceSharedData -File -Recurse)
    if ($sharedFiles.Count -eq 0) {
        Write-Host '  SharedData folder is empty - skipped.'
        return
    }

    $targetSharedData = Join-Path $TargetRoot 'SharedData'
    foreach ($sharedFile in $sharedFiles) {
        $relativePath = $sharedFile.FullName.Substring($sourceSharedData.Length).TrimStart('\', '/')
        if ($relativePath -like 'Extras\PDA*') {
            $relativePath = Join-Path 'Content' $relativePath
        }

        $destination = Join-Path $targetSharedData $relativePath
        $destinationDirectory = [System.IO.Path]::GetDirectoryName($destination)

        if ($DryRun) {
            Write-Host "  [WhatIf] Would copy file: $relativePath -> $destination"
            continue
        }

        if (-not [string]::IsNullOrEmpty($destinationDirectory) -and -not (Test-Path -LiteralPath $destinationDirectory)) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        }

        Copy-Item -LiteralPath $sharedFile.FullName -Destination $destination -Force
    }
}

function Write-InstallSummary {
    param([string]$ScenarioPath)

    Write-Host ''
    Write-Host 'Arcadia mod install complete.'
    if ($DryRun) {
        Write-Host '(Dry run only - no files were modified.)'
    }
    Write-Host ''
    Write-Host 'Next steps:'
    Write-Host "  1. Select this scenario in Empyrion: $ScenarioPath"
    Write-Host '  2. Confirm Arcadia Station appears on the galaxy map near [90, 0, -45]'
    Write-Host ''
    Write-Host 'Note: Re-running this script on the same scenario may duplicate merged rows/blocks.'
    Write-Host '      Keep a fresh RE2 copy if you need to reinstall.'
}

# --- Main ---

$ScenarioPath = (Resolve-Path -LiteralPath $ScenarioPath).Path
$ModPath = if (Test-Path -LiteralPath $ModPath) {
    (Resolve-Path -LiteralPath $ModPath).Path
}
else {
    throw "Mod path not found: $ModPath"
}

Write-Host 'Arcadia Mod Installer for Reforged Eden 2'
Write-Host "  Mod:      $ModPath"
Write-Host "  Scenario: $ScenarioPath"
if ($DryRun) {
    Write-Host '  Mode:     WhatIf (dry run)'
}
Write-Host ''

Write-Step 1 'Validating mod and scenario paths'

Test-RequiredPath -Path (Join-Path $ModPath 'Content\Configuration\Dialogues.Arcadia.ecf') -Description 'mod file'
Test-RequiredPath -Path (Join-Path $ModPath 'Sectors\Sectors.Arcadia.yaml') -Description 'mod file'
Test-RequiredPath -Path (Join-Path $ScenarioPath 'Content\Configuration\Dialogues.ecf') -Description 'RE2 scenario file'
Test-RequiredPath -Path (Join-Path $ScenarioPath 'Content\Configuration\Dialogues.csv') -Description 'RE2 scenario file'
Test-RequiredPath -Path (Join-Path $ScenarioPath 'Content\Configuration\TokenConfig.ecf') -Description 'RE2 scenario file'
Test-RequiredPath -Path (Join-Path $ScenarioPath 'Content\Configuration\TraderNPCConfig.ecf') -Description 'RE2 scenario file'
Test-RequiredPath -Path (Join-Path $ScenarioPath 'Extras\PDA\PDA.csv') -Description 'RE2 scenario file'
Test-RequiredPath -Path (Join-Path $ScenarioPath 'Extras\PDA\PDA.yaml') -Description 'RE2 scenario file'
Test-RequiredPath -Path (Join-Path $ScenarioPath 'Sectors\Sectors.yaml') -Description 'RE2 scenario file'
Test-RequiredPath -Path (Join-Path $ScenarioPath 'Playfields') -Description 'RE2 scenario folder'
Test-RequiredPath -Path (Join-Path $ScenarioPath 'Prefabs') -Description 'RE2 scenario folder'

Write-Step 2 'Validating merge anchors in target scenario'

Test-AnchorPresent -FilePath (Join-Path $ScenarioPath 'Content\Configuration\Dialogues.ecf') `
    -Pattern $MergeAnchors.DialoguesEcf -Description 'Dialogues.ecf'
Test-AnchorPresent -FilePath (Join-Path $ScenarioPath 'Sectors\Sectors.yaml') `
    -Pattern $MergeAnchors.SectorsYaml -Description 'Sectors.yaml'
Test-AnchorPresent -FilePath (Join-Path $ScenarioPath 'Extras\PDA\PDA.yaml') `
    -Pattern $MergeAnchors.PdaYaml -Description 'PDA.yaml'

$installWarnings = @(Test-ArcadiaInstalled -Root $ScenarioPath)
if ($installWarnings.Count -gt 0) {
    Write-Host ''
    Write-Warning 'Arcadia content may already be installed in this scenario:'
    foreach ($warning in $installWarnings) {
        Write-Warning "  - $warning"
    }
    Write-Warning 'Continuing will duplicate merged content. Use a fresh RE2 copy to reinstall cleanly.'
    Write-Host ''
}

$configPath = Join-Path $ScenarioPath 'Content\Configuration'
$pdaPath = Join-Path $ScenarioPath 'Extras\PDA'
$sectorsPath = Join-Path $ScenarioPath 'Sectors\Sectors.yaml'

Write-Step 3 'Merging Dialogues.csv (insert Arcadia rows after header)'
Merge-CsvAfterHeader `
    -TargetPath (Join-Path $configPath 'Dialogues.csv') `
    -SourcePath (Join-Path $ModPath 'Content\Configuration\Dialogues.Arcadia.csv')

Write-Step 4 'Merging Dialogues.ecf (insert before Trader_DialogueSwitch_Start)'
Merge-TextBeforeAnchor `
    -TargetPath (Join-Path $configPath 'Dialogues.ecf') `
    -SourcePath (Join-Path $ModPath 'Content\Configuration\Dialogues.Arcadia.ecf') `
    -AnchorPattern $MergeAnchors.DialoguesEcf

Write-Step 5 'Merging TokenConfig.ecf (append)'
Merge-TextAppend `
    -TargetPath (Join-Path $configPath 'TokenConfig.ecf') `
    -SourcePath (Join-Path $ModPath 'Content\Configuration\TokenConfig.Arcadia.ecf')

Write-Step 6 'Merging TraderNPCConfig.ecf (append)'
Merge-TextAppend `
    -TargetPath (Join-Path $configPath 'TraderNPCConfig.ecf') `
    -SourcePath (Join-Path $ModPath 'Content\Configuration\TraderNPCConfig.Arcadia.ecf')

Write-Step 7 'Merging PDA.csv (insert Arcadia rows after header)'
Merge-CsvAfterHeader `
    -TargetPath (Join-Path $pdaPath 'PDA.csv') `
    -SourcePath (Join-Path $ModPath 'Extras\PDA\PDA.Arcadia.csv')

Write-Step 8 'Merging PDA.yaml (insert after Chapters:)'
Merge-TextAfterAnchor `
    -TargetPath (Join-Path $pdaPath 'PDA.yaml') `
    -SourcePath (Join-Path $ModPath 'Extras\PDA\PDA.Arcadia.yaml') `
    -AnchorPattern $MergeAnchors.PdaYaml

Write-Step 9 'Merging Sectors.yaml (insert after Alpha [Sun Back] anchor)'
Merge-TextAfterAnchor `
    -TargetPath $sectorsPath `
    -SourcePath (Join-Path $ModPath 'Sectors\Sectors.Arcadia.yaml') `
    -AnchorPattern $MergeAnchors.SectorsYaml

Write-Step 10 'Copying Playfields folders'
Copy-ModPlayfields -SourceRoot $ModPath -TargetRoot $ScenarioPath

Write-Step 11 'Copying Prefabs files (.epb, .decals, etc.)'
Copy-ModPrefabs -SourceRoot $ModPath -TargetRoot $ScenarioPath

Write-Step 12 'Copying SharedData files (additive)'
Copy-ModSharedData -SourceRoot $ModPath -TargetRoot $ScenarioPath

Write-InstallSummary -ScenarioPath $ScenarioPath
