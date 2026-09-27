$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testRoot = Join-Path $temporaryRoot "spectra-doc-sync-$([guid]::NewGuid().ToString('N'))"
$sourceRoot = Join-Path $testRoot 'spectra-docs'
$defaultWebsiteRoot = Join-Path $testRoot 'yangxj96-website'
$websiteRoot = Join-Path $testRoot 'website with spaces'
$fixtureEncoding = [Text.UTF8Encoding]::new($false)

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

function Assert-File {
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "ASSERTION FAILED: missing file $Path"
    }
}

function Assert-Absent {
    param([Parameter(Mandatory)] [string] $Path)
    if (Test-Path -LiteralPath $Path) {
        throw "ASSERTION FAILED: unexpected path $Path"
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)] [string] $Content,
        [Parameter(Mandatory)] [string] $Needle,
        [Parameter(Mandatory)] [string] $Message
    )

    if (-not $Content.Contains($Needle)) {
        throw "ASSERTION FAILED: $Message; missing '$Needle'"
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory)] [string] $Content,
        [Parameter(Mandatory)] [string] $Needle,
        [Parameter(Mandatory)] [string] $Message
    )

    if ($Content.Contains($Needle)) {
        throw "ASSERTION FAILED: $Message; unexpected '$Needle'"
    }
}

function Write-FixtureFile {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Content
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Content, $fixtureEncoding)
}

function Invoke-WebsiteSync {
    param(
        [Parameter(Mandatory)] [string] $WorkingDirectory,
        [Parameter(Mandatory)] [string[]] $ScriptArguments
    )

    $powerShellCommand = Get-Command -Name pwsh -CommandType Application -ErrorAction Stop
    $processInfo = [Diagnostics.ProcessStartInfo]::new($powerShellCommand.Source)
    $processInfo.WorkingDirectory = $WorkingDirectory
    $processInfo.UseShellExecute = $false
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
    $processInfo.StandardErrorEncoding = [Text.Encoding]::UTF8
    $processInfo.Environment['PYTHONUTF8'] = '1'
    [void] $processInfo.ArgumentList.Add('-NoProfile')
    [void] $processInfo.ArgumentList.Add('-File')
    [void] $processInfo.ArgumentList.Add((Join-Path $sourceRoot 'scripts\sync-website-docs.ps1'))
    foreach ($argument in $ScriptArguments) {
        [void] $processInfo.ArgumentList.Add($argument)
    }

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $processInfo
    try {
        [void] $process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = $stdoutTask.GetAwaiter().GetResult()
            Error = $stderrTask.GetAwaiter().GetResult()
        }
    }
    finally {
        $process.Dispose()
    }
}

try {
    New-Item -ItemType Directory -Path $sourceRoot, $defaultWebsiteRoot, $websiteRoot -Force | Out-Null
    $sourceScripts = Join-Path $sourceRoot 'scripts'
    New-Item -ItemType Directory -Path $sourceScripts -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts\sync-website-docs.ps1') -Destination $sourceScripts
    Copy-Item -LiteralPath (Join-Path $projectRoot 'scripts\sync-website-docs.py') -Destination $sourceScripts

    $manifest = [ordered]@{
        version = 2
        source = [ordered]@{ docsRoot = 'docs'; excludeGlobs = @('superpowers/**') }
        sections = @(
            [ordered]@{ id = 'overview'; sourceFiles = @('00-项目总览.md'); target = 'docs/pages/spectra'; routePrefix = 'spectra'; sidebar = 'overviewSidebar'; routeOverrides = [ordered]@{ '00-项目总览.md' = 'index.md' } }
            [ordered]@{ id = 'quickstart'; sourceFiles = @('01-快速开始.md'); target = 'docs/pages/spectra-quickstart'; routePrefix = 'spectra-quickstart'; sidebar = 'quickstartSidebar'; routeOverrides = [ordered]@{ '01-快速开始.md' = 'index.md' } }
            [ordered]@{ id = 'user-guide'; sourceRoot = '使用指南'; target = 'docs/pages/spectra-user-guide'; routePrefix = 'spectra-user-guide'; sidebar = 'userGuideSidebar'; routeOverrides = [ordered]@{ '00-使用指南.md' = 'index.md' } }
            [ordered]@{ id = 'frontend'; sourceRoot = '前端'; target = 'docs/pages/spectra-ui'; routePrefix = 'spectra-ui'; sidebar = 'frontendSidebar'; routeOverrides = [ordered]@{ '00-前端说明.md' = 'index.md' } }
            [ordered]@{ id = 'backend'; sourceRoot = '后端'; target = 'docs/pages/spectra-admin'; routePrefix = 'spectra-admin'; sidebar = 'backendSidebar'; routeOverrides = [ordered]@{ '10-后端模块/00-后端总览.md' = 'index.md'; '40-配置说明/00-配置项说明.md' = 'spectra-config.md' } }
            [ordered]@{ id = 'guide'; sourceRoot = '开发指南'; target = 'docs/pages/spectra-guide'; routePrefix = 'spectra-guide'; sidebar = 'guideSidebar' }
            [ordered]@{ id = 'operations'; sourceRoot = '部署运维'; target = 'docs/pages/spectra-ops'; routePrefix = 'spectra-ops'; sidebar = 'operationsSidebar'; sidebarTitleOverrides = [ordered]@{ '05-运维应急速查.md' = '运维应急速查' } }
            [ordered]@{ id = 'designer'; sourceRoot = '流程设计器'; target = 'docs/pages/logicflow-flowable'; routePrefix = 'logicflow-flowable'; sidebar = 'designerSidebar'; routeOverrides = [ordered]@{ '00-流程设计器.md' = 'index.md' } }
            [ordered]@{ id = 'reference'; sourceRoot = '参考文档'; target = 'docs/pages/spectra-reference'; routePrefix = 'spectra-reference'; sidebar = 'referenceSidebar'; routeOverrides = [ordered]@{ '00-版本与支持范围.md' = 'index.md' } }
            [ordered]@{ id = 'contributing'; sourceRoot = '参与贡献'; target = 'docs/pages/spectra-contributing'; routePrefix = 'spectra-contributing'; sidebar = 'contributingSidebar'; routeOverrides = [ordered]@{ '00-贡献指南.md' = 'index.md' } }
        )
        attachments = @([ordered]@{ source = '后端/10-后端模块/permission-catalog.yaml'; target = 'permission-catalog.yaml'; section = 'backend' })
    }
    $manifestPath = Join-Path $sourceScripts 'website-docs-manifest.json'
    [IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 12) + "`n"), $fixtureEncoding)

    $fixtureFiles = [ordered]@{
        'docs/00-项目总览.md' = "# 项目总览`n`n参见 [[00-前端说明]]、[[00-后端总览]]、[[00-贡献指南]] 和 [[流程设计器]]。`n"
        'docs/01-快速开始.md' = '# 快速开始'
        'docs/使用指南/00-使用指南.md' = '# 使用指南'
        'docs/后端/10-后端模块/00-后端总览.md' = "# 后端总览`n`n参见 [[00-前端说明]] 和 [[开发指南]]。`n"
        'docs/前端/00-前端说明.md' = "# 前端说明`n`n参见 [[00-后端总览]]。`n"
        'docs/流程设计器/00-流程设计器.md' = "# 流程设计器`n`n参见 [[00-后端总览]]。`n"
        'docs/开发指南/00-开发指南.md' = '# 开发指南'
        'docs/部署运维/00-部署运维.md' = '# 部署运维'
        'docs/参考文档/00-版本与支持范围.md' = '# 版本与支持范围'
        'docs/参与贡献/00-贡献指南.md' = '# 贡献指南'
        'docs/部署运维/05-运维应急速查.md' = '# DEV_OPS Break-glass Runbook'
        'docs/后端/40-配置说明/00-配置项说明.md' = '# 配置项说明'
        'docs/后端/10-后端模块/old.md' = '# 旧页面'
        'docs/后端/10-后端模块/permission-catalog.yaml' = "version: 1`nitems:`n  - code: demo.read`n"
        'docs/.env' = 'TOKEN=must-not-copy'
        'docs/AI速查/05-配置清单.md' = '# AI 内部速查不应发布'
    }
    foreach ($entry in $fixtureFiles.GetEnumerator()) {
        Write-FixtureFile -Path (Join-Path $sourceRoot $entry.Key) -Content $entry.Value
    }

    $websitePageRoots = @(
        'docs/pages/blogs', 'docs/pages/spectra', 'docs/pages/spectra-ui', 'docs/pages/spectra-admin',
        'docs/pages/spectra-guide', 'docs/pages/spectra-ops', 'docs/pages/logicflow-flowable',
        'docs/pages/spectra-quickstart', 'docs/pages/spectra-user-guide', 'docs/pages/spectra-reference',
        'docs/pages/spectra-contributing'
    )
    foreach ($website in @($defaultWebsiteRoot, $websiteRoot)) {
        foreach ($relativePath in $websitePageRoots) {
            New-Item -ItemType Directory -Path (Join-Path $website $relativePath) -Force | Out-Null
        }
        New-Item -ItemType Directory -Path (Join-Path $website '.vitepress') -Force | Out-Null
        Write-FixtureFile -Path (Join-Path $website 'package.json') -Content '{"scripts":{"docs:build":"true"}}'
        Write-FixtureFile -Path (Join-Path $website 'docs/pages/blogs/keep.md') -Content '# Keep my blog'
        Write-FixtureFile -Path (Join-Path $website 'docs/pages/spectra-admin/legacy-ai.md') -Content '# Legacy AI page'
        Write-FixtureFile -Path (Join-Path $website 'docs/pages/spectra-admin/legacy-frontend.md') -Content '# Legacy frontend page'
        Write-FixtureFile -Path (Join-Path $website 'docs/pages/spectra-guide/legacy-guide.md') -Content '# Legacy guide page'
        Write-FixtureFile -Path (Join-Path $website 'docs/pages/logicflow-flowable/legacy.md') -Content '# Legacy designer page'
    }

    $defaultPreview = Invoke-WebsiteSync -WorkingDirectory $sourceRoot -ScriptArguments @('--source-root', $sourceRoot, '--mode', 'Preview')
    Assert-Equal -Expected 0 -Actual $defaultPreview.ExitCode -Message 'default Preview succeeds'
    Assert-Contains -Content $defaultPreview.Output -Needle 'Preview 完成，未修改 website。' -Message 'default mode reports a preview'
    Assert-File -Path (Join-Path $defaultWebsiteRoot 'docs/pages/spectra-admin/legacy-ai.md')
    Assert-Absent -Path (Join-Path $defaultWebsiteRoot 'docs/pages/spectra/index.md')
    Assert-Absent -Path (Join-Path $defaultWebsiteRoot '.vitepress/generated/project-sidebar.mts')

    $preview = Invoke-WebsiteSync -WorkingDirectory $sourceRoot -ScriptArguments @('--source-root', $sourceRoot, '--website-root', $websiteRoot, '--mode', 'Preview')
    Assert-Equal -Expected 0 -Actual $preview.ExitCode -Message 'explicit Preview succeeds with a spaced website path'
    Assert-File -Path (Join-Path $websiteRoot 'docs/pages/spectra-admin/legacy-ai.md')
    Assert-Absent -Path (Join-Path $websiteRoot 'docs/pages/spectra/index.md')
    Assert-Absent -Path (Join-Path $websiteRoot '.vitepress/generated/project-sidebar.mts')

    $apply = Invoke-WebsiteSync -WorkingDirectory $sourceRoot -ScriptArguments @('--source-root', $sourceRoot, '--website-root', $websiteRoot, '--mode', 'Apply', '--prune-legacy')
    Assert-Equal -Expected 0 -Actual $apply.ExitCode -Message 'Apply succeeds with a spaced website path'

    foreach ($relativePath in @(
        'docs/pages/spectra/index.md',
        'docs/pages/spectra-quickstart/index.md',
        'docs/pages/spectra-user-guide/index.md',
        'docs/pages/spectra-ui/index.md',
        'docs/pages/spectra-admin/index.md',
        'docs/pages/spectra-guide/00-开发指南.md',
        'docs/pages/spectra-ops/00-部署运维.md',
        'docs/pages/logicflow-flowable/index.md',
        'docs/pages/spectra-reference/index.md',
        'docs/pages/spectra-contributing/index.md',
        'docs/pages/spectra-admin/spectra-config.md',
        'docs/public/spectra-admin/permission-catalog.yaml',
        '.vitepress/generated/project-sidebar.mts'
    )) {
        Assert-File -Path (Join-Path $websiteRoot $relativePath)
    }

    foreach ($relativePath in @(
        'docs/pages/spectra-admin/legacy-ai.md',
        'docs/pages/spectra-admin/legacy-frontend.md',
        'docs/pages/spectra-guide/legacy-guide.md',
        'docs/pages/logicflow-flowable/legacy.md'
    )) {
        Assert-Absent -Path (Join-Path $websiteRoot $relativePath)
    }

    Assert-Contains -Content (Get-Content -Raw -Encoding utf8 (Join-Path $websiteRoot 'docs/pages/blogs/keep.md')) -Needle '# Keep my blog' -Message 'Apply preserves the blog directory'
    $generatedManifest = Get-Content -Raw -Encoding utf8 (Join-Path $websiteRoot '.vitepress/generated/spectra-docs-sync.json')
    Assert-Contains -Content $generatedManifest -Needle 'permission-catalog.yaml' -Message 'generated manifest lists the public attachment'
    Assert-NotContains -Content $generatedManifest -Needle '.env' -Message 'generated manifest excludes secret files'
    Assert-NotContains -Content $generatedManifest -Needle 'TOKEN' -Message 'generated manifest excludes secret content'
    if ([regex]::IsMatch($generatedManifest, '(?i)\.env|token|password|secret|AI速查')) {
        throw 'ASSERTION FAILED: sensitive path entered generated manifest'
    }

    $sidebar = Get-Content -Raw -Encoding utf8 (Join-Path $websiteRoot '.vitepress/generated/project-sidebar.mts')
    foreach ($sidebarName in @('frontendSidebar', 'quickstartSidebar', 'userGuideSidebar', 'guideSidebar', 'operationsSidebar', 'referenceSidebar', 'contributingSidebar')) {
        Assert-Contains -Content $sidebar -Needle "export const $sidebarName" -Message "generated sidebar contains $sidebarName"
    }
    Assert-Contains -Content $sidebar -Needle '运维应急速查' -Message 'operations sidebar title override is applied'
    Assert-NotContains -Content $sidebar -Needle 'DEV_OPS Break-glass Runbook' -Message 'operations sidebar hides the sensitive runbook title'

    $publishedDocs = Get-ChildItem -LiteralPath (Join-Path $websiteRoot 'docs') -File -Recurse | ForEach-Object { Get-Content -Raw -Encoding utf8 $_.FullName }
    Assert-NotContains -Content ($publishedDocs -join "`n") -Needle 'AI 内部速查不应发布' -Message 'AI quick-reference content is not published'

    $repeatApply = Invoke-WebsiteSync -WorkingDirectory $sourceRoot -ScriptArguments @('--source-root', $sourceRoot, '--website-root', $websiteRoot, '--mode', 'Apply', '--prune-legacy')
    Assert-Equal -Expected 0 -Actual $repeatApply.ExitCode -Message 'repeat Apply succeeds'
    Assert-Contains -Content $repeatApply.Output -Needle '删除: 0' -Message 'repeat Apply is idempotent'

    $invalidBuildPreview = Invoke-WebsiteSync -WorkingDirectory $sourceRoot -ScriptArguments @('--source-root', $sourceRoot, '--website-root', $websiteRoot, '--build', '--mode', 'Preview')
    if ($invalidBuildPreview.ExitCode -eq 0) {
        throw 'ASSERTION FAILED: --build --mode Preview must return a nonzero status'
    }

    Remove-Item -LiteralPath (Join-Path $sourceRoot 'docs/后端/10-后端模块/old.md') -Force
    $prunedApply = Invoke-WebsiteSync -WorkingDirectory $sourceRoot -ScriptArguments @('--source-root', $sourceRoot, '--website-root', $websiteRoot, '--mode', 'Apply')
    Assert-Equal -Expected 0 -Actual $prunedApply.ExitCode -Message 'Apply removes stale generated docs'
    Assert-Absent -Path (Join-Path $websiteRoot 'docs/pages/spectra-admin/old.md')

    Write-Output 'PASS: sync-website-docs fixture assertions'
}
finally {
    $testRootFullPath = [IO.Path]::GetFullPath($testRoot)
    $temporaryRootPrefix = $temporaryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($testRootFullPath.StartsWith($temporaryRootPrefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $testRootFullPath)) {
        Remove-Item -LiteralPath $testRootFullPath -Recurse -Force
    }
}
