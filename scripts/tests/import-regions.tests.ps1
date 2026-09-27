$ErrorActionPreference = 'Stop'

$testScriptDirectory = $PSScriptRoot
$importScript = Join-Path $testScriptDirectory '..\import-regions.ps1'
$projectRoot = (Resolve-Path (Join-Path $testScriptDirectory '..\..')).Path
$backendRoot = Join-Path $projectRoot 'spectra-admin'
$testPreviousLocation = (Get-Location).Path
$testOriginalImportFlag = [Environment]::GetEnvironmentVariable('SPECTRA_REGION_IMPORT', 'Process')
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryRoot "spectra-import-regions-$([guid]::NewGuid().ToString('N'))"
$script:MockMiseExitCode = 0
$script:CapturedMiseCallCount = 0
$script:CapturedMiseArguments = @()
$script:CapturedImportFlag = $null
$script:CapturedMiseLocation = $null

function Assert-Equal {
    param(
        [Parameter(Mandatory)] [object] $Expected,
        [Parameter(Mandatory)] [object] $Actual,
        [Parameter(Mandatory)] [string] $Message
    )

    if ($Expected -cne $Actual) {
        throw "ASSERTION FAILED: $Message; expected '$Expected', got '$Actual'"
    }
}

function Assert-StringArrayEqual {
    param(
        [Parameter(Mandatory)] [string[]] $Expected,
        [Parameter(Mandatory)] [string[]] $Actual,
        [Parameter(Mandatory)] [string] $Message
    )

    if ($Expected.Count -ne $Actual.Count) {
        throw "ASSERTION FAILED: $Message; expected $($Expected.Count) arguments, got $($Actual.Count)"
    }

    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($Expected[$index] -cne $Actual[$index]) {
            throw "ASSERTION FAILED: $Message; argument $index expected '$($Expected[$index])', got '$($Actual[$index])'"
        }
    }
}

function mise {
    $script:CapturedMiseCallCount++
    $script:CapturedMiseArguments = @($args | ForEach-Object { [string] $_ })
    $script:CapturedImportFlag = $env:SPECTRA_REGION_IMPORT
    $script:CapturedMiseLocation = (Get-Location).Path
    $global:LASTEXITCODE = $script:MockMiseExitCode
    Write-Output 'mock Maven output'
}

try {
    . $importScript

    $env:SPECTRA_REGION_IMPORT = 'restore-this-value'
    $script:MockMiseExitCode = 0
    $successExitCode = Invoke-SpectraRegionImport

    $expectedArguments = @(
        'exec', '--', '.\mvnw.cmd',
        '-Pmanual-integration',
        '-pl', 'spectra-launch', '-am',
        '-Dgroups=manual-integration',
        '-Dspectra.test.groups.exclude=',
        '-Dtest=RegionServiceTest',
        '-Dsurefire.failIfNoSpecifiedTests=false',
        '-Dlogging.level.com.devops00.spectra=INFO',
        '-Dstyle.color=never',
        'test'
    )

    Assert-Equal -Expected 0 -Actual $successExitCode -Message 'successful mocked import returns zero'
    if ($successExitCode -is [array]) {
        throw 'ASSERTION FAILED: Maven output must not contaminate the importer exit code'
    }
    Assert-Equal -Expected 'true' -Actual $script:CapturedImportFlag -Message 'import flag is set for mise'
    Assert-Equal -Expected $backendRoot -Actual $script:CapturedMiseLocation -Message 'mise runs from spectra-admin'
    Assert-StringArrayEqual -Expected $expectedArguments -Actual $script:CapturedMiseArguments -Message 'mise receives the complete Maven command'
    Assert-Equal -Expected 'restore-this-value' -Actual $env:SPECTRA_REGION_IMPORT -Message 'prior import flag is restored after success'
    Assert-Equal -Expected $testPreviousLocation -Actual (Get-Location).Path -Message 'prior location is restored after success'

    $script:MockMiseExitCode = 23
    $failureExitCode = Invoke-SpectraRegionImport
    Assert-Equal -Expected 23 -Actual $failureExitCode -Message 'Maven failure status is preserved'
    Assert-Equal -Expected 'restore-this-value' -Actual $env:SPECTRA_REGION_IMPORT -Message 'prior import flag is restored after failure'
    Assert-Equal -Expected $testPreviousLocation -Actual (Get-Location).Path -Message 'prior location is restored after failure'

    $brokenScriptsDirectory = Join-Path $testRoot 'scripts'
    New-Item -ItemType Directory -Path $brokenScriptsDirectory -Force | Out-Null
    $brokenImportScript = Join-Path $brokenScriptsDirectory 'import-regions.ps1'
    Copy-Item -LiteralPath $importScript -Destination $brokenImportScript
    . $brokenImportScript

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $pathFailureThrown = $false
    try {
        $null = Invoke-SpectraRegionImport
    }
    catch {
        $pathFailureThrown = $true
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    Assert-Equal -Expected $true -Actual $pathFailureThrown -Message 'missing backend directory stops the importer'
    Assert-Equal -Expected 2 -Actual $script:CapturedMiseCallCount -Message 'mise is not invoked if changing to the backend directory fails'
    Assert-Equal -Expected 'restore-this-value' -Actual $env:SPECTRA_REGION_IMPORT -Message 'prior import flag is restored after location failure'
    Assert-Equal -Expected $testPreviousLocation -Actual (Get-Location).Path -Message 'prior location is restored after location failure'

    Write-Output 'PASS: import-regions preserves the manual Maven arguments, environment, location, and exit status'
}
finally {
    if ($null -eq $testOriginalImportFlag) {
        Remove-Item Env:SPECTRA_REGION_IMPORT -ErrorAction SilentlyContinue
    }
    else {
        $env:SPECTRA_REGION_IMPORT = $testOriginalImportFlag
    }

    Set-Location -LiteralPath $testPreviousLocation

    $testRootFullPath = [IO.Path]::GetFullPath($testRoot)
    $temporaryRootPrefix = $temporaryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($testRootFullPath.StartsWith($temporaryRootPrefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $testRootFullPath)) {
        Remove-Item -LiteralPath $testRootFullPath -Recurse -Force
    }
}
