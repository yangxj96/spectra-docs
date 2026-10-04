$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$admin = Join-Path $root 'spectra-admin'
$ui = Join-Path $root 'spectra-ui'
$reportPath = Join-Path $admin 'config/pmd/calibration/target/pmd.xml'
$eslintReport = Join-Path $root '.temp/b00-eslint-calibration.json'

Push-Location $admin
try {
    & mise exec -- .\mvnw.cmd -f config/pmd/calibration/pom.xml pmd:pmd -q
    if ($LASTEXITCODE -ne 0) { throw "PMD calibration failed with exit $LASTEXITCODE" }
}
finally { Pop-Location }

[xml]$pmd = Get-Content -LiteralPath $reportPath -Raw
$violations = @($pmd.SelectNodes('//*[local-name()="violation"]'))
function Assert-Pmd([string]$Method, [string]$Rule, [bool]$Expected) {
    $found = @($violations | Where-Object { $_.GetAttribute('method') -eq $Method -and $_.GetAttribute('rule') -eq $Rule }).Count -gt 0
    if ($found -ne $Expected) { throw "PMD $Method/$Rule expected=$Expected actual=$found" }
}

Assert-Pmd cyclo15 CyclomaticComplexity $false
Assert-Pmd cyclo16 CyclomaticComplexity $true
Assert-Pmd npath200 NPathComplexity $false
Assert-Pmd npath201 NPathComplexity $true
Assert-Pmd ifNested3 AvoidDeeplyNestedIfStmts $false
Assert-Pmd ifNested4 AvoidDeeplyNestedIfStmts $true
Assert-Pmd params5 ExcessiveParameterList $false
Assert-Pmd params6 ExcessiveParameterList $true
Assert-Pmd nested4 AvoidDeeplyNestedIfStmts $false

Push-Location $ui
try {
    Get-Content 'config/complexity-calibration/boundary-samples.txt' -Raw |
        & mise exec -- pnpm exec eslint --stdin --stdin-filename src/main.ts --format json -o $eslintReport
    if ($LASTEXITCODE -ne 1) { throw "ESLint calibration expected exit 1, got $LASTEXITCODE" }
}
finally { Pop-Location }

$eslint = Get-Content -LiteralPath $eslintReport -Raw | ConvertFrom-Json
$messages = @($eslint[0].messages)
$expected = @(
    @{ Rule = 'complexity'; Line = 20 },
    @{ Rule = 'max-depth'; Line = 57 },
    @{ Rule = 'max-params'; Line = 70 }
)
foreach ($item in $expected) {
    if (@($messages | Where-Object { $_.ruleId -eq $item.Rule -and $_.line -eq $item.Line }).Count -ne 1) {
        throw "ESLint missing $($item.Rule) at line $($item.Line)"
    }
}
if ($messages.Count -ne $expected.Count) { throw "ESLint expected $($expected.Count) findings, got $($messages.Count)" }
Write-Output 'PASS: PMD 7.17.0 and ESLint 9.39.2 complexity boundaries'
