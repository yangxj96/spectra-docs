[CmdletBinding()]
param(
    [string]$RootPath = (Get-Location).Path,
    [string]$LedgerPath = 'docs/开发指南/工程治理/ledger.json',
    [string]$SuppressionPath = 'spectra-admin/config/spotbugs/exclude.xml',
    [string]$EvidenceId = 'EV-B00-EXCEPTION-20261005'
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($RootPath)
$ledgerFile = Join-Path $root $LedgerPath
$ledger = Get-Content -LiteralPath $ledgerFile -Raw | ConvertFrom-Json -DateKind String
$exceptions = [System.Collections.Generic.List[object]]::new()
@($ledger.exceptions) | ForEach-Object { [void]$exceptions.Add($_) }
$xml = [xml](Get-Content -LiteralPath (Join-Path $root $SuppressionPath) -Raw)
$sourceRoots = @('spectra-admin')
$next = 1
foreach ($match in @($xml.SelectNodes('//*[local-name()="Match"]'))) {
    $classNode = $match.SelectSingleNode('./*[local-name()="Class"]')
    $bugNode = $match.SelectSingleNode('./*[local-name()="Bug"]')
    if ($null -eq $classNode -or $null -eq $bugNode) { continue }
    $className = [string]$classNode.GetAttribute('name')
    $pattern = [string]$bugNode.GetAttribute('pattern')
    $simpleName = ($className -split '\.')[-1] -replace '\$.*$',''
    $source = Get-ChildItem -LiteralPath (Join-Path $root 'spectra-admin') -Recurse -File -Filter "$simpleName.java" | Select-Object -First 1
    if ($null -eq $source) { continue }
    $relative = [IO.Path]::GetRelativePath($root, $source.FullName).Replace('\','/')
    $rule = "SpotBugs.$pattern"
    $exists = @($exceptions | Where-Object { [string]$_.path -eq $relative -and [string]$_.rule -eq $rule -and [string]$_.symbol -eq $className })
    if ($exists.Count -gt 0) { continue }
    $id = ('EX-B00-SPOTBUGS-{0:D3}' -f $next)
    while (@($exceptions | Where-Object { [string]$_.id -eq $id }).Count -gt 0) { $next++ ; $id = ('EX-B00-SPOTBUGS-{0:D3}' -f $next) }
    $record = [ordered]@{
        id = $id; path = $relative; symbol = $className; rule = $rule
        measured_value = '1 exact SpotBugs filter match'
        tool_version = 'SpotBugs 4.10.3.0'
        necessity = 'Existing fixed SpotBugs filtering is retained for this exact class and rule pending focused remediation review.'
        risk = 'The filtered finding may become valid after implementation or dependency changes.'
        verification = 'The governance checker binds the exception to this exact class, rule, and source path.'
        owner_area = 'spectra-admin/static-analysis'
        reevaluate_when = 'Any implementation, dependency, or SpotBugs rule-set change affecting this class.'
        state = 'active'; evidence_ids = @($EvidenceId)
    }
    [void]$exceptions.Add([pscustomobject]$record)
    $next++
}
$ledger.exceptions = @($exceptions)
$ledger | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ledgerFile -Encoding utf8
Write-Output "registered=$($exceptions.Count)"
