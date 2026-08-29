Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory)] [bool] $Condition,
        [Parameter(Mandatory)] [string] $Message
    )

    if (-not $Condition) {
        throw "ASSERTION FAILED: $Message"
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory)] $Expected,
        [Parameter(Mandatory)] $Actual,
        [Parameter(Mandatory)] [string] $Message
    )

    if ($Expected -ne $Actual) {
        throw "ASSERTION FAILED: $Message`nExpected: $Expected`nActual: $Actual"
    }
}

function Write-FixtureFile {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Content
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("spectra-doc-sync-{0}" -f ([guid]::NewGuid()))
$sourceRoot = Join-Path $testRoot 'source'
$websiteRoot = Join-Path $testRoot 'website'
$scriptPath = Join-Path $PSScriptRoot '..\sync-website-docs.ps1'

try {
    Write-FixtureFile (Join-Path $sourceRoot 'scripts\website-docs-manifest.json') @'
{
  "version": 1,
  "source": {
    "docsRoot": "docs",
    "excludeGlobs": ["90-计划/**", "99-模板/**", "superpowers/**"]
  },
  "targets": {
    "spectra": "docs/pages/spectra-admin",
    "designer": "docs/pages/logicflow-flowable",
    "assets": "docs/public/spectra-admin",
    "generatedSidebar": "docs/.vitepress/generated/project-sidebar.mts",
    "generatedManifest": "docs/.vitepress/generated/spectra-docs-sync.json"
  },
  "designerSources": ["20-前端/40-流程设计器.md"],
  "attachments": [{"source": "10-后端/permission-catalog.yaml", "target": "permission-catalog.yaml"}],
  "routeOverrides": {"00-项目总览.md": "index.md", "old.md": "old.md"}
}
'@
    Write-FixtureFile (Join-Path $sourceRoot 'docs\00-项目总览.md') @'
---
tags:
  - moc
---

# 项目总览

查看 [[20-前端/40-流程设计器]]。
'@
    Write-FixtureFile (Join-Path $sourceRoot 'docs\20-前端\40-流程设计器.md') @'
---
created: 2026-08-29
---

# 流程设计器

## 安装

`pnpm add @yangxj96/logicflow-plugin-flowable`
'@
    Write-FixtureFile (Join-Path $sourceRoot 'docs\old.md') @'
# 旧页面
'@
    Write-FixtureFile (Join-Path $sourceRoot 'docs\10-后端\permission-catalog.yaml') @'
version: 1
items:
  - code: demo.read
'@
    Write-FixtureFile (Join-Path $sourceRoot 'docs\.env') 'TOKEN=must-not-copy'
    Write-FixtureFile (Join-Path $sourceRoot 'docs\99-模板\ignored.md') '# 模板'

    Write-FixtureFile (Join-Path $websiteRoot 'package.json') '{"scripts":{"docs:build":"vitepress build docs"}}'
    Write-FixtureFile (Join-Path $websiteRoot 'docs\pages\blogs\keep.md') '# Keep my blog'
    Write-FixtureFile (Join-Path $websiteRoot 'docs\pages\spectra-admin\legacy.md') '# Legacy project page'
    Write-FixtureFile (Join-Path $websiteRoot 'docs\pages\logicflow-flowable\legacy.md') '# Legacy designer page'

    $preview = & pwsh -NoProfile -File $scriptPath -SourceRoot $sourceRoot -WebsiteRoot $websiteRoot -Mode Preview 2>&1
    Assert-Equal 0 $LASTEXITCODE 'Preview should succeed'
    Assert-True (Test-Path -LiteralPath (Join-Path $websiteRoot 'docs\pages\spectra-admin\legacy.md')) 'Preview must not delete legacy pages'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $websiteRoot 'docs\.vitepress\generated\project-sidebar.mts'))) 'Preview must not write generated sidebar'

    $firstApply = @(& pwsh -NoProfile -File $scriptPath -SourceRoot $sourceRoot -WebsiteRoot $websiteRoot -Mode Apply -PruneLegacy 2>&1)
    Assert-Equal 0 $LASTEXITCODE 'Apply should succeed'
    $firstApplyText = $firstApply -join "`n"
    Assert-True ($firstApplyText -notmatch '  - docs/pages/(spectra-admin|logicflow-flowable)/index\.md') 'PruneLegacy must not delete pages generated in the same run'
    Assert-True (Test-Path -LiteralPath (Join-Path $websiteRoot 'docs\pages\spectra-admin\index.md')) 'Project index should be generated'
    Assert-True (Test-Path -LiteralPath (Join-Path $websiteRoot 'docs\pages\logicflow-flowable\index.md')) 'Designer index should be generated'
    $projectIndexContent = Get-Content -Raw -LiteralPath (Join-Path $websiteRoot 'docs\pages\spectra-admin\index.md')
    Assert-True (-not ($projectIndexContent.EndsWith("`n`n") -or $projectIndexContent.EndsWith("`r`n`r`n"))) 'Generated pages must end with one newline'
    Assert-True (Test-Path -LiteralPath (Join-Path $websiteRoot 'docs\public\spectra-admin\permission-catalog.yaml')) 'Permission catalog attachment should be generated'
    Assert-True (Test-Path -LiteralPath (Join-Path $websiteRoot 'docs\.vitepress\generated\project-sidebar.mts')) 'Generated sidebar should be written'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $websiteRoot 'docs\pages\spectra-admin\legacy.md'))) 'PruneLegacy should remove old project pages'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $websiteRoot 'docs\pages\logicflow-flowable\legacy.md'))) 'PruneLegacy should remove old designer pages'
    Assert-Equal '# Keep my blog' (Get-Content -Raw -LiteralPath (Join-Path $websiteRoot 'docs\pages\blogs\keep.md')).Trim() 'Blog content must remain unchanged'
    $generatedManifest = Get-Content -Raw -LiteralPath (Join-Path $websiteRoot 'docs\.vitepress\generated\spectra-docs-sync.json') | ConvertFrom-Json
    Assert-True (-not (($generatedManifest.files -join "`n") -match '(?i)(\.env|token|password|secret)')) 'Sensitive files must not enter generated manifest'

    $repeatApply = @(& pwsh -NoProfile -File $scriptPath -SourceRoot $sourceRoot -WebsiteRoot $websiteRoot -Mode Apply -PruneLegacy 2>&1)
    Assert-Equal 0 $LASTEXITCODE 'Repeat Apply should succeed'
    Assert-True ((($repeatApply -join "`n") -match '删除: 0')) 'Repeat Apply should have no stale files'

    Remove-Item -LiteralPath (Join-Path $sourceRoot 'docs\old.md') -Force
    & pwsh -NoProfile -File $scriptPath -SourceRoot $sourceRoot -WebsiteRoot $websiteRoot -Mode Apply
    Assert-Equal 0 $LASTEXITCODE 'Second Apply should succeed'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $websiteRoot 'docs\pages\spectra-admin\old.md'))) 'Removed source pages should be pruned on later runs'

    Write-Output 'PASS: sync-website-docs fixture assertions'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
