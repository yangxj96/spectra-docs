$ErrorActionPreference = 'Stop'
$temp = Join-Path $env:TEMP ('spectra-boundary-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path "$temp/spectra-admin/spectra-common/src/main/java/com/example" -Force | Out-Null
Set-Content -LiteralPath "$temp/spectra-admin/spectra-common/src/main/java/com/example/Bad.java" -Value 'import com.devops00.spectra.core.User;'
$script = Join-Path (Get-Location).Path 'scripts/check-module-boundaries.ps1'
& pwsh -NoProfile -File $script -RootPath $temp | Out-Null
if ($LASTEXITCODE -ne 1) { throw 'expected forbidden dependency failure' }
Remove-Item -LiteralPath $temp -Recurse -Force
Write-Output 'PASS: module boundary cases'
