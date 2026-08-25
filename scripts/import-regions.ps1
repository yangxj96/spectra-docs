#requires -Version 7.6

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# 该命令只用于显式初始化隔离开发库；普通测试和应用启动不会导入行政区划数据。
$previousRegionImport = $env:SPECTRA_REGION_IMPORT
$env:SPECTRA_REGION_IMPORT = 'true'

Push-Location $projectRoot
try {
    . .\scripts\agent-runtime.ps1
    Set-Location .\spectra-admin

    & .\mvnw.cmd -q -pl spectra-modules/spectra-core -am `
        '-Dtest=RegionServiceTest' `
        '-Dsurefire.failIfNoSpecifiedTests=false' `
        test

    if ($LASTEXITCODE -ne 0) {
        throw "行政区划数据导入失败，Maven exit code: $LASTEXITCODE"
    }
}
finally {
    if ($null -eq $previousRegionImport) {
        Remove-Item Env:SPECTRA_REGION_IMPORT -ErrorAction SilentlyContinue
    } else {
        $env:SPECTRA_REGION_IMPORT = $previousRegionImport
    }
    Pop-Location
}
