#requires -Version 7.6

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$globalAgent = Join-Path $env:USERPROFILE '.codex/AGENTS.md'

$targets = @(
    [pscustomobject]@{ Scope = 'global'; Path = $globalAgent; Limit = 3072 }
    [pscustomobject]@{ Scope = 'root'; Path = (Join-Path $projectRoot 'AGENTS.md'); Limit = 6144 }
    [pscustomobject]@{ Scope = 'backend'; Path = (Join-Path $projectRoot 'spectra-admin/AGENTS.md'); Limit = 4096 }
    [pscustomobject]@{ Scope = 'web'; Path = (Join-Path $projectRoot 'spectra-ui/AGENTS.md'); Limit = 4096 }
    [pscustomobject]@{ Scope = 'plugin'; Path = (Join-Path $projectRoot 'logicflow-plugin-flowable/AGENTS.md'); Limit = 3072 }
)

$results = foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target.Path)) {
        [pscustomobject]@{ Scope = $target.Scope; Bytes = 0; Limit = $target.Limit; Status = 'MISSING'; Path = $target.Path }
        continue
    }

    $item = Get-Item -LiteralPath $target.Path
    $status = if ($item.Length -le $target.Limit) { 'OK' } else { 'TOO_LARGE' }
    [pscustomobject]@{ Scope = $target.Scope; Bytes = $item.Length; Limit = $target.Limit; Status = $status; Path = $target.Path }
}

$results | Format-Table -AutoSize

$rootText = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'AGENTS.md')
$forbidden = @(
    '必读 `docs/00-项目总览.md`',
    '后端任务再读 `docs/40-规范/15-后端开发规范.md`',
    '每次.*读取.*docs/'
)
$matches = foreach ($pattern in $forbidden) {
    if ($rootText -match $pattern) { $pattern }
}
if ($matches) {
    throw "根 AGENTS 包含无条件文档加载规则: $($matches -join ', ')"
}

$failures = @($results | Where-Object { $_.Status -ne 'OK' })
if ($failures.Count -gt 0) {
    throw "Agent 指令审计失败：$($failures.Scope -join ', ')"
}

Write-Output 'Agent context audit passed.'
