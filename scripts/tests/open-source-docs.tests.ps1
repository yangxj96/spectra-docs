$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Assert-File {
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "ASSERTION FAILED: missing file $Path"
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Needle
    )

    $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if (-not $content.Contains($Needle)) {
        throw "ASSERTION FAILED: $Path does not contain '$Needle'"
    }
}

$requiredFiles = @(
    'README.md',
    'LICENSE',
    'CONTRIBUTING.md',
    'CODE_OF_CONDUCT.md',
    'SECURITY.md',
    'CHANGELOG.md',
    '.github/ISSUE_TEMPLATE/bug_report.md',
    '.github/ISSUE_TEMPLATE/feature_request.md',
    '.github/pull_request_template.md',
    'docs/00-项目总览.md',
    'docs/01-快速开始.md',
    'docs/使用指南/00-使用指南.md',
    'docs/参考文档/00-版本与支持范围.md',
    'docs/参与贡献/00-贡献指南.md'
)

foreach ($relativePath in $requiredFiles) {
    Assert-File -Path (Join-Path $projectRoot $relativePath)
}

$readmePath = Join-Path $projectRoot 'README.md'
$readme = Get-Content -LiteralPath $readmePath -Raw -Encoding utf8
if ([regex]::IsMatch($readme, 'docs/(02-使用指南|60-参考文档|70-参与贡献)/')) {
    throw 'ASSERTION FAILED: README contains numbered public directory paths'
}

$manifestPath = Join-Path $projectRoot 'scripts/website-docs-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8
if ([regex]::IsMatch($manifest, '(?m)^\s*[-+].*AI速查|sourceRoot.*AI速查')) {
    throw 'ASSERTION FAILED: AI quick-reference entered website manifest'
}

Assert-Contains -Path $manifestPath -Needle '"sourceRoot": "使用指南"'
Assert-Contains -Path $manifestPath -Needle '"sourceRoot": "参考文档"'
Assert-Contains -Path $manifestPath -Needle '"sourceRoot": "参与贡献"'
Assert-Contains -Path (Join-Path $projectRoot 'docs/00-项目总览.md') -Needle '系统业务使用'
Assert-Contains -Path (Join-Path $projectRoot 'docs/参与贡献/01-提交与分支规范.md') -Needle 'Conventional Commits'

Write-Output 'PASS: open-source documentation assertions'
