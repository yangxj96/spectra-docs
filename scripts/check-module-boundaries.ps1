[CmdletBinding()]
param([string]$RootPath = (Get-Location).Path)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($RootPath)
$rules = @{
    common = @('com.devops00.spectra.framework.', 'com.devops00.spectra.core.', 'com.devops00.spectra.workflow.', 'com.devops00.spectra.oa.')
    framework = @('com.devops00.spectra.core.', 'com.devops00.spectra.workflow.', 'com.devops00.spectra.oa.')
    core = @('com.devops00.spectra.workflow.', 'com.devops00.spectra.oa.')
    workflow = @('com.devops00.spectra.oa.')
    oa = @()
}
$violations = [System.Collections.Generic.List[string]]::new()
foreach ($module in $rules.Keys) {
    $moduleRoot = switch ($module) {
        common { Join-Path $root 'spectra-admin/spectra-common/src/main/java' }
        framework { Join-Path $root 'spectra-admin/spectra-framework/src/main/java' }
        core { Join-Path $root 'spectra-admin/spectra-modules/spectra-core/src/main/java' }
        workflow { Join-Path $root 'spectra-admin/spectra-modules/spectra-workflow/src/main/java' }
        oa { Join-Path $root 'spectra-admin/spectra-modules/spectra-oa/src/main/java' }
    }
    if (-not (Test-Path -LiteralPath $moduleRoot -PathType Container)) { continue }
    Get-ChildItem -LiteralPath $moduleRoot -Recurse -Filter '*.java' | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($root, $_.FullName).Replace('\','/')
        $lines = Get-Content -LiteralPath $_.FullName
        foreach ($line in $lines) {
            if ($line -match '^\s*import\s+([^;]+);') {
                $import = $Matches[1].Trim()
                foreach ($forbidden in $rules[$module]) {
                    if ($import.StartsWith($forbidden, [StringComparison]::Ordinal)) {
                        [void]$violations.Add("${module}: $relative imports $import")
                    }
                }
            }
        }
    }
}
if ($violations.Count -gt 0) {
    $violations | ForEach-Object { "ERROR: $_" }
    Write-Output "FAIL: module boundary check found $($violations.Count) violation(s)"
    exit 1
}
Write-Output 'PASS: module boundary check'
exit 0
