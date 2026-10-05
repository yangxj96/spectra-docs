$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$validator = Join-Path $root 'scripts/check-governance-exceptions.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "spectra-governance-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

function Invoke-Case {
    param([string]$Name, [object]$Ledger, [string]$JavaText, [int]$ExpectedExit)
    $caseRoot = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path (Join-Path $caseRoot 'src') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $caseRoot 'src/Sample.java') -Value $JavaText -Encoding utf8
    $ledgerPath = Join-Path $caseRoot 'ledger.json'
    $Ledger | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $ledgerPath -Encoding utf8
    & pwsh -NoProfile -File $validator -RootPath $caseRoot -LedgerPath $ledgerPath -SourceRoot 'src'
    if ($LASTEXITCODE -ne $ExpectedExit) {
        throw "$Name expected exit $ExpectedExit, got $LASTEXITCODE"
    }
}

try {
    $validEvidence = [pscustomobject]@{ id = 'EV-1'; result = 'passed' }
    $validException = [pscustomobject]@{
        id = 'EX-1'; path = 'src/Sample.java'; symbol = 'Sample.run'; rule = 'PMD.ExcessiveParameterList'
        measured_value = 6; tool_version = 'PMD 7.17.0'; necessity = 'legacy boundary'; risk = 'parameter coupling'
        verification = 'refactor review'; owner_area = 'test'; reevaluate_when = 'method changes'; state = 'active'; evidence_ids = @('EV-1')
    }
    $validLedger = [pscustomobject]@{ exceptions = @($validException); evidence = @($validEvidence) }
    Invoke-Case 'valid' $validLedger '@SuppressWarnings("PMD.ExcessiveParameterList") class Sample { void run() {} }' 0

    $missingField = $validException | Select-Object *
    $missingField.rule = $null
    Invoke-Case 'missing-field' ([pscustomobject]@{ exceptions = @($missingField); evidence = @($validEvidence) }) 'class Sample {}' 1

    $stalePath = $validException | Select-Object *
    $stalePath.path = 'src/Missing.java'
    Invoke-Case 'stale-path' ([pscustomobject]@{ exceptions = @($stalePath); evidence = @($validEvidence) }) 'class Sample {}' 1

    $staleEvidence = $validException | Select-Object *
    $staleEvidence.evidence_ids = @('EV-MISSING')
    Invoke-Case 'stale-evidence' ([pscustomobject]@{ exceptions = @($staleEvidence); evidence = @($validEvidence) }) 'class Sample {}' 1

    Invoke-Case 'unregistered-suppression' ([pscustomobject]@{ exceptions = @(); evidence = @($validEvidence) }) '@SuppressWarnings("PMD.ExcessiveParameterList") class Sample {}' 1
    Write-Output 'PASS: governance exception reconciliation cases'
}
finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
