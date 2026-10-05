[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RootPath,
    [Parameter(Mandatory)] [string] $LedgerPath,
    [string[]] $SourceRoot = @(),
    [string[]] $SuppressionFile = @()
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($RootPath)
$ledgerFullPath = [IO.Path]::GetFullPath($LedgerPath)
$ledger = Get-Content -LiteralPath $ledgerFullPath -Raw | ConvertFrom-Json -DateKind String
$exceptions = @($ledger.exceptions)
$evidence = @($ledger.evidence)
$evidenceIds = @($evidence | ForEach-Object { [string]$_.id })
$findings = [System.Collections.Generic.List[string]]::new()
$required = @('id','path','symbol','rule','measured_value','tool_version','necessity','risk','verification','owner_area','reevaluate_when','state','evidence_ids')

function Add-Finding([string]$Message) { [void]$findings.Add($Message) }
function Relative-Normalized([string]$Path) {
    $full = [IO.Path]::GetFullPath((Join-Path $root $Path))
    $prefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $null }
    return $full.Substring($prefix.Length).Replace('\','/')
}

$ids = @{}
foreach ($exception in $exceptions) {
    foreach ($field in $required) {
        $property = $exception.PSObject.Properties[$field]
        if ($null -eq $property -or $null -eq $property.Value -or ([string]$property.Value).Trim() -eq '') {
            Add-Finding "exception '$($exception.id)' missing required field '$field'"
        }
    }
    $id = [string]$exception.id
    if ($ids.ContainsKey($id)) { Add-Finding "duplicate exception id '$id'" } else { $ids[$id] = $true }
    $relative = Relative-Normalized ([string]$exception.path)
    if ($null -eq $relative) {
        Add-Finding "exception '$id' path escapes root: '$($exception.path)'"
    } elseif (-not (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf)) {
        Add-Finding "exception '$id' path does not exist: '$relative'"
    } else {
        $content = Get-Content -LiteralPath (Join-Path $root $relative) -Raw
        $symbolName = ([string]$exception.symbol -split '[.#:]')[-1]
        $symbolCandidates = @($symbolName, (($symbolName -split '\$')[0])) | Select-Object -Unique
        if (-not (@($symbolCandidates | Where-Object { $content.Contains($_) }).Count -gt 0)) { Add-Finding "exception '$id' symbol is stale: '$($exception.symbol)'" }
    }
    foreach ($evidenceId in @($exception.evidence_ids)) {
        if ([string]$evidenceId -notin $evidenceIds) { Add-Finding "exception '$id' references missing evidence '$evidenceId'" }
    }
    if ([string]$exception.state -eq 'active' -and @($exception.evidence_ids).Count -eq 0) {
        Add-Finding "active exception '$id' must reference evidence"
    }
}

$scanFiles = [System.Collections.Generic.List[string]]::new()
foreach ($source in $SourceRoot) {
    $sourcePath = Join-Path $root $source
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) { Add-Finding "source root does not exist: '$source'"; continue }
    Get-ChildItem -LiteralPath $sourcePath -Recurse -File -Include '*.java','*.xml','*.yml','*.yaml','*.properties','pom.xml' | ForEach-Object { [void]$scanFiles.Add($_.FullName) }
}
foreach ($file in $SuppressionFile) {
    $filePath = Join-Path $root $file
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { Add-Finding "suppression file does not exist: '$file'"; continue }
    [void]$scanFiles.Add((Get-Item -LiteralPath $filePath).FullName)
}

foreach ($filePath in @($scanFiles | Select-Object -Unique)) {
    $relative = [IO.Path]::GetRelativePath($root, $filePath).Replace('\','/')
    $content = Get-Content -LiteralPath $filePath -Raw
    $matches = [regex]::Matches($content, 'PMD\.([A-Za-z][A-Za-z0-9]+)')
    foreach ($match in $matches) {
        $rule = $match.Value
        $registered = @($exceptions | Where-Object { ([string]$_.path).Replace('\','/') -eq $relative -and [string]$_.rule -eq $rule })
        if ($registered.Count -eq 0) { Add-Finding "unregistered suppression '$rule' in '$relative'" }
    }

    $omitMatches = [regex]::Matches($content, '<omitVisitors>\s*([^<]+?)\s*</omitVisitors>')
    foreach ($omit in $omitMatches) {
        $rule = "SpotBugs.$($omit.Groups[1].Value.Trim())"
        $registered = @($exceptions | Where-Object { ([string]$_.path).Replace('\','/') -eq $relative -and [string]$_.rule -eq $rule -and [string]$_.symbol -eq 'omitVisitors' })
        if ($registered.Count -eq 0) { Add-Finding "unregistered global suppression '$rule' in '$relative'" }
    }
}

foreach ($file in $SuppressionFile) {
    $filePath = Join-Path $root $file
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { continue }
    $relative = [IO.Path]::GetRelativePath($root, (Get-Item -LiteralPath $filePath).FullName).Replace('\','/')
    [xml]$filter = Get-Content -LiteralPath $filePath -Raw
    foreach ($match in @($filter.SelectNodes('//*[local-name()="Match"]'))) {
        $class = $match.SelectSingleNode('./*[local-name()="Class"]')
        $bug = $match.SelectSingleNode('./*[local-name()="Bug"]')
        if ($null -eq $class -or $null -eq $bug) { Add-Finding "incomplete SpotBugs Match in '$relative'"; continue }
        $className = [string]$class.GetAttribute('name')
        $pattern = [string]$bug.GetAttribute('pattern')
        $rule = "SpotBugs.$pattern"
        $simpleName = ($className -split '\.')[-1] -replace '\$.*$',''
        $sourceCandidates = @($SourceRoot | ForEach-Object {
            Get-ChildItem -LiteralPath (Join-Path $root $_) -Recurse -File -Filter "$simpleName.java" -ErrorAction SilentlyContinue
        })
        $candidatePaths = @($sourceCandidates | ForEach-Object { [IO.Path]::GetRelativePath($root, $_.FullName).Replace('\','/') })
        $registered = @($exceptions | Where-Object {
            [string]$_.rule -eq $rule -and [string]$_.symbol -eq $className -and
            ($candidatePaths -contains ([string]$_.path).Replace('\','/'))
        })
        if ($registered.Count -eq 0) { Add-Finding "unregistered SpotBugs suppression '$rule' for '$className' in '$relative'" }
    }
}

if ($findings.Count -eq 0) {
    Write-Output "PASS: governance exception reconciliation ($($exceptions.Count) exceptions, $($scanFiles.Count) files scanned)"
    exit 0
}

$findings | ForEach-Object { Write-Output "ERROR: $_" }
Write-Output "FAIL: governance exception reconciliation found $($findings.Count) issue(s)"
exit 1
