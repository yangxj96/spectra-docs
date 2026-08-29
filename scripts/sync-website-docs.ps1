[CmdletBinding()]
param(
    [string] $SourceRoot,
    [Parameter(Mandatory)]
    [string] $WebsiteRoot,
    [ValidateSet('Preview', 'Apply')]
    [string] $Mode = 'Preview',
    [switch] $PruneLegacy,
    [switch] $AllowDirtyProjectDocs,
    [switch] $Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Warnings = [System.Collections.Generic.List[string]]::new()
$script:SensitivePatterns = @(
    '(?i)^\.env(?:\..*)?$',
    '(?i)^\.mise\.local\.toml$',
    '(?i)\.(?:p12|jks|pem|key)$',
    '(?i)(?:secret|token|password)'
)

function Get-FullPath {
    param([Parameter(Mandatory)] [string] $Path)

    return [IO.Path]::GetFullPath($Path)
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory)] [string] $Root,
        [Parameter(Mandatory)] [string] $Path
    )

    return ([IO.Path]::GetRelativePath((Get-FullPath $Root), (Get-FullPath $Path))).Replace('\', '/')
}

function Resolve-ContainedPath {
    param(
        [Parameter(Mandatory)] [string] $Root,
        [Parameter(Mandatory)] [string] $RelativePath,
        [Parameter(Mandatory)] [string] $Description
    )

    $rootFull = (Get-FullPath $Root).TrimEnd('\') + '\'
    $candidate = Get-FullPath (Join-Path $Root ($RelativePath -replace '/', '\'))
    if (-not $candidate.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Description path escapes its root: $RelativePath"
    }

    return $candidate
}

function Test-SensitivePath {
    param([Parameter(Mandatory)] [string] $RelativePath)

    $leaf = Split-Path -Leaf ($RelativePath -replace '/', '\')
    foreach ($pattern in $script:SensitivePatterns) {
        if (($leaf -match $pattern) -or ($RelativePath -match $pattern)) {
            return $true
        }
    }

    return $false
}

function Test-ExcludedPath {
    param(
        [Parameter(Mandatory)] [string] $RelativePath,
        [Parameter(Mandatory)] $Manifest
    )

    foreach ($pattern in @($Manifest.source.excludeGlobs)) {
        if ($RelativePath -like [string] $pattern) {
            return $true
        }
    }

    return $false
}

function Get-ManifestProperty {
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)] [string] $Name
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return $property.Value
}

function Get-RouteOverride {
    param(
        [Parameter(Mandatory)] $Manifest,
        [Parameter(Mandatory)] [string] $SourceRelativePath
    )

    return Get-ManifestProperty -Object $Manifest.routeOverrides -Name $SourceRelativePath
}

function Get-TitleFromMarkdown {
    param([Parameter(Mandatory)] [string] $Content)

    $match = [regex]::Match($Content, '(?m)^#\s+(.+?)\s*$')
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return $null
}

function ConvertTo-YamlSingleQuoted {
    param([Parameter(Mandatory)] [string] $Value)

    return "'" + $Value.Replace("'", "''") + "'"
}

function Add-VitePressFrontmatter {
    param(
        [Parameter(Mandatory)] [string] $Content,
        [Parameter(Mandatory)] [string] $Title
    )

    $normalized = $Content.TrimStart([char[]]"`r`n")
    $frontMatterMatch = [regex]::Match($normalized, '\A---\r?\n(?<body>.*?)\r?\n---\r?\n?', [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($frontMatterMatch.Success) {
        $frontMatter = $frontMatterMatch.Groups['body'].Value.TrimEnd()
        if ($frontMatter -notmatch '(?m)^layout\s*:') {
            $frontMatter = "layout: doc`n$frontMatter"
        }
        if ($frontMatter -notmatch '(?m)^title\s*:') {
            $frontMatter = "title: $(ConvertTo-YamlSingleQuoted $Title)`n$frontMatter"
        }

        $body = $normalized.Substring($frontMatterMatch.Length).TrimStart([char[]]"`r`n").TrimEnd()
        return "---`n$frontMatter`n---`n`n$body`n"
    }

    return "---`nlayout: doc`ntitle: $(ConvertTo-YamlSingleQuoted $Title)`n---`n`n$($normalized.TrimEnd())`n"
}

function Get-TargetRoute {
    param(
        [Parameter(Mandatory)] [string] $Section,
        [Parameter(Mandatory)] [string] $TargetRelativePath
    )

    $withoutExtension = Remove-MarkdownExtension -Path $TargetRelativePath
    if ($withoutExtension -eq 'index') {
        return "/$Section/"
    }

    return "/$Section/$withoutExtension"
}

function Remove-MarkdownExtension {
    param([Parameter(Mandatory)] [string] $Path)

    $normalized = $Path.Replace('\', '/')
    if ($normalized.EndsWith('.md', [StringComparison]::OrdinalIgnoreCase)) {
        return $normalized.Substring(0, $normalized.Length - 3)
    }

    return $normalized
}

function Add-RouteKey {
    param(
        [Parameter(Mandatory)] [hashtable] $Map,
        [Parameter(Mandatory)] [string] $Key,
        [Parameter(Mandatory)] [string] $Route
    )

    $normalizedKey = $Key.Trim().Replace('\', '/').TrimStart('./').TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($normalizedKey)) {
        return
    }

    if ($Map.ContainsKey($normalizedKey) -and $Map[$normalizedKey] -ne $Route) {
        $Map[$normalizedKey] = $null
        return
    }

    $Map[$normalizedKey] = $Route
}

function Resolve-WikiRoute {
    param(
        [Parameter(Mandatory)] [hashtable] $RouteMap,
        [Parameter(Mandatory)] [string] $Target
    )

    $normalized = $Target.Trim().Replace('\', '/').TrimStart('./').TrimEnd('/')
    $withoutExtension = (Remove-MarkdownExtension -Path $normalized).TrimEnd('/')
    foreach ($key in @($normalized, $withoutExtension)) {
        if ($RouteMap.ContainsKey($key) -and $null -ne $RouteMap[$key]) {
            return $RouteMap[$key]
        }
    }

    return $null
}

function Convert-WikiLinks {
    param(
        [Parameter(Mandatory)] [string] $Content,
        [Parameter(Mandatory)] [hashtable] $RouteMap,
        [Parameter(Mandatory)] [string] $SourceRelativePath
    )

    return [regex]::Replace($Content, '\[\[(?<target>[^\]|#]+)(?:#(?<anchor>[^\]|]+))?(?:\|(?<label>[^\]]+))?\]\]', {
        param($Match)

        $target = $Match.Groups['target'].Value.Trim()
        $route = Resolve-WikiRoute -RouteMap $RouteMap -Target $target
        if ($null -eq $route) {
            $script:Warnings.Add("无法解析内部链接 [$SourceRelativePath]: $target")
            return $Match.Value
        }

        $anchor = if ($Match.Groups['anchor'].Success) { '#' + $Match.Groups['anchor'].Value.Trim() } else { '' }
        $label = if ($Match.Groups['label'].Success) { $Match.Groups['label'].Value } else { $target }
        return "[$label]($route$anchor)"
    })
}

function Get-GroupTitle {
    param([Parameter(Mandatory)] [string] $SourceRelativePath)

    $directory = Split-Path -Parent ($SourceRelativePath -replace '/', '\')
    if ([string]::IsNullOrWhiteSpace($directory) -or $directory -eq '.') {
        return '项目总览'
    }

    $leaf = Split-Path -Leaf $directory
    return ($leaf -replace '^\d+[-_]', '')
}

function ConvertTo-MtsString {
    param([Parameter(Mandatory)] [string] $Value)

    return "'" + $Value.Replace('\', '\\').Replace("'", "\\'").Replace("`r", '').Replace("`n", '\n') + "'"
}

function New-SidebarModule {
    param(
        [Parameter(Mandatory)] [array] $Pages,
        [Parameter(Mandatory)] [string] $Path
    )

    $groups = [ordered] @{}
    $projectPages = @($Pages | Where-Object Section -eq 'spectra-admin')
    foreach ($page in ($projectPages | Sort-Object SourceRelativePath)) {
        if (-not $groups.Contains($page.Group)) {
            $groups[$page.Group] = [System.Collections.Generic.List[object]]::new()
        }

        $groups[$page.Group].Add([ordered] @{
                text = $page.Title
                link = $page.Route
            })
    }

    $projectGroups = [System.Collections.Generic.List[string]]::new()
    foreach ($group in $groups.Keys) {
        $items = $groups[$group] | ForEach-Object {
            "        { text: $(ConvertTo-MtsString $_.text), link: $(ConvertTo-MtsString $_.link) }"
        }
        $projectGroups.Add("    {`n        text: $(ConvertTo-MtsString $group),`n        items: [`n$($items -join ",`n")`n        ]`n    }")
    }

    $designerPage = $Pages | Where-Object Section -eq 'logicflow-flowable' | Sort-Object SourceRelativePath | Select-Object -First 1
    $designerSidebar = if ($null -eq $designerPage) {
        '[]'
    } else {
        "[`n    { text: $(ConvertTo-MtsString $designerPage.Title), link: $(ConvertTo-MtsString $designerPage.Route) }`n]"
    }

    $content = @"
// Generated by scripts/sync-website-docs.ps1. Do not edit manually.
export const projectSidebar = [
$($projectGroups -join ",`n")
]

export const designerSidebar = $designerSidebar
"@

    Write-Utf8NoBom -Path $Path -Content $content
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Content
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Get-FileDigest {
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

function Test-PathChanged {
    param(
        [Parameter(Mandatory)] [string] $ExpectedPath,
        [Parameter(Mandatory)] [string] $ActualPath
    )

    if (-not (Test-Path -LiteralPath $ActualPath -PathType Leaf)) {
        return $true
    }

    return (Get-FileDigest $ExpectedPath) -ne (Get-FileDigest $ActualPath)
}

function Get-GitProjectChanges {
    param(
        [Parameter(Mandatory)] [string] $WebsiteRoot,
        [Parameter(Mandatory)] [string[]] $RelativePaths
    )

    if (-not (Test-Path -LiteralPath (Join-Path $WebsiteRoot '.git'))) {
        return @()
    }

    $safeDirectory = ('safe.directory=' + $WebsiteRoot.Replace('\', '/'))
    $status = git -c $safeDirectory -C $WebsiteRoot status --short -- @RelativePaths 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw '无法读取 website 仓库状态。'
    }

    return @($status | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function New-GeneratedManifest {
    param(
        [Parameter(Mandatory)] [array] $GeneratedFiles,
        [Parameter(Mandatory)] [array] $SourceFiles,
        [Parameter(Mandatory)] [string] $ManifestRelativePath
    )

    $allFiles = @($GeneratedFiles + $ManifestRelativePath | Sort-Object -Unique)
    return [ordered] @{
        version = 1
        files = $allFiles
        sources = @($SourceFiles | Sort-Object -Unique)
    }
}

function Write-JsonNoBom {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] $Value
    )

    $json = $Value | ConvertTo-Json -Depth 8
    Write-Utf8NoBom -Path $Path -Content ($json + "`n")
}

if ($Build -and $Mode -ne 'Apply') {
    throw '-Build 只能与 -Mode Apply 一起使用。'
}

$sourceRootResolved = if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    Get-FullPath (Join-Path $PSScriptRoot '..')
} else {
    Get-FullPath $SourceRoot
}
$websiteRootResolved = Get-FullPath $WebsiteRoot
$manifestPath = Join-Path $sourceRootResolved 'scripts\website-docs-manifest.json'

if (-not (Test-Path -LiteralPath $sourceRootResolved -PathType Container)) {
    throw "源仓库目录不存在: $sourceRootResolved"
}
if (-not (Test-Path -LiteralPath $websiteRootResolved -PathType Container)) {
    throw "网站仓库目录不存在: $websiteRootResolved"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "发布清单不存在: $manifestPath"
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ($manifest.version -ne 1) {
    throw "不支持的发布清单版本: $($manifest.version)"
}

$sourceDocsRoot = Resolve-ContainedPath -Root $sourceRootResolved -RelativePath $manifest.source.docsRoot -Description '源文档'
$websiteDocsRoot = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath 'docs' -Description '网站文档'
$blogRoot = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath 'docs/pages/blogs' -Description '博客'
if (-not (Test-Path -LiteralPath $blogRoot -PathType Container)) {
    throw "网站博客目录不存在: $blogRoot"
}
if (-not (Test-Path -LiteralPath (Join-Path $websiteRootResolved 'package.json') -PathType Leaf)) {
    throw "网站 package.json 不存在: $websiteRootResolved"
}

$spectraTarget = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $manifest.targets.spectra -Description 'Spectra 生成目录'
$designerTarget = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $manifest.targets.designer -Description '流程设计器生成目录'
$assetsTarget = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $manifest.targets.assets -Description '附件生成目录'
$sidebarRelativePath = [string] $manifest.targets.generatedSidebar
$generatedManifestRelativePath = [string] $manifest.targets.generatedManifest
$sidebarPath = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $sidebarRelativePath -Description '侧边栏生成文件'
$generatedManifestPath = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $generatedManifestRelativePath -Description '同步清单生成文件'

$managedRelativeRoots = @(
    [string] $manifest.targets.spectra,
    [string] $manifest.targets.designer,
    [string] $manifest.targets.assets,
    ([IO.Path]::GetDirectoryName($sidebarRelativePath).Replace('\', '/'))
)
$dirtyChanges = @(Get-GitProjectChanges -WebsiteRoot $websiteRootResolved -RelativePaths $managedRelativeRoots)
if ($dirtyChanges.Count -gt 0 -and -not $AllowDirtyProjectDocs) {
    throw "website 项目文档生成区存在未提交修改，请先处理:`n$($dirtyChanges -join "`n")"
}
if ($dirtyChanges.Count -gt 0 -and $AllowDirtyProjectDocs) {
    Write-Warning '已允许覆盖 website 项目文档生成区中的未提交修改。请确认这些修改均为同步脚本生成的内容。'
}

$sourceFiles = [System.Collections.Generic.List[object]]::new()
$pages = [System.Collections.Generic.List[object]]::new()
$routeMap = @{}
$sourceByBaseName = @{}

$markdownFiles = Get-ChildItem -LiteralPath $sourceDocsRoot -Recurse -File -Filter '*.md' | Sort-Object FullName
foreach ($file in $markdownFiles) {
    $sourceRelativePath = Get-RelativePath -Root $sourceDocsRoot -Path $file.FullName
    if ((Test-SensitivePath $sourceRelativePath) -or (Test-ExcludedPath -RelativePath $sourceRelativePath -Manifest $manifest)) {
        continue
    }

    $sourceFiles.Add($sourceRelativePath)
    $isDesigner = @($manifest.designerSources | Where-Object { $_ -eq $sourceRelativePath }).Count -gt 0
    $section = if ($isDesigner) { 'logicflow-flowable' } else { 'spectra-admin' }
    $override = Get-RouteOverride -Manifest $manifest -SourceRelativePath $sourceRelativePath
    if ($isDesigner) {
        $targetRelativePath = if ($null -ne $override) { [string] $override } else { 'index.md' }
        $targetRoot = $designerTarget
    } else {
        $targetRelativePath = if ($null -ne $override) {
            [string] $override
        } else {
            $sourceRelativePath
        }
        $targetRoot = $spectraTarget
    }

    if ([IO.Path]::GetExtension($targetRelativePath) -ne '.md') {
        $targetRelativePath += '.md'
    }
    $targetPath = Resolve-ContainedPath -Root $targetRoot -RelativePath $targetRelativePath -Description '文档目标'
    $targetRelativeToWebsite = Get-RelativePath -Root $websiteRootResolved -Path $targetPath
    $route = Get-TargetRoute -Section $section -TargetRelativePath $targetRelativePath
    $title = Get-TitleFromMarkdown -Content (Get-Content -Raw -LiteralPath $file.FullName)
    if ([string]::IsNullOrWhiteSpace($title)) {
        $title = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    }

    $page = [pscustomobject] @{
        SourceRelativePath = $sourceRelativePath
        TargetRelativePath = $targetRelativePath.Replace('\', '/')
        TargetPath = $targetPath
        TargetRelativeToWebsite = $targetRelativeToWebsite
        Section = $section
        Route = $route
        Group = if ($isDesigner) { '流程设计器' } else { Get-GroupTitle $sourceRelativePath }
        Title = $title
        SourcePath = $file.FullName
    }
    $pages.Add($page)

    $sourceWithoutExtension = Remove-MarkdownExtension -Path $sourceRelativePath
    Add-RouteKey -Map $routeMap -Key $sourceRelativePath -Route $route
    Add-RouteKey -Map $routeMap -Key $sourceWithoutExtension -Route $route
    $baseName = [IO.Path]::GetFileNameWithoutExtension($sourceRelativePath)
    if (-not $sourceByBaseName.ContainsKey($baseName)) {
        $sourceByBaseName[$baseName] = [System.Collections.Generic.List[string]]::new()
    }
    $sourceByBaseName[$baseName].Add($route)
}

foreach ($baseName in $sourceByBaseName.Keys) {
    $routes = @($sourceByBaseName[$baseName] | Sort-Object -Unique)
    if ($routes.Count -eq 1) {
        Add-RouteKey -Map $routeMap -Key $baseName -Route $routes[0]
    }
}

$syncTempRoot = Join-Path ([IO.Path]::GetTempPath()) ('spectra-docs-sync-{0}' -f ([guid]::NewGuid()))
$stageRoot = Join-Path $syncTempRoot 'stage'
$backupRoot = Join-Path $syncTempRoot 'backup'
$generatedFiles = [System.Collections.Generic.List[string]]::new()
$stageGeneratedManifestPath = Join-Path $stageRoot $generatedManifestRelativePath.Replace('/', '\')

try {
    New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null
    foreach ($page in $pages) {
        $content = Get-Content -Raw -LiteralPath $page.SourcePath
        $content = Convert-WikiLinks -Content $content -RouteMap $routeMap -SourceRelativePath $page.SourceRelativePath
        $content = Add-VitePressFrontmatter -Content $content -Title $page.Title
        $stagePagePath = Join-Path $stageRoot ((Get-RelativePath -Root $websiteRootResolved -Path $page.TargetPath) -replace '/', '\')
        Write-Utf8NoBom -Path $stagePagePath -Content $content
        $generatedFiles.Add($page.TargetRelativeToWebsite)
    }

    foreach ($attachment in @($manifest.attachments)) {
        $sourceRelativePath = [string] $attachment.source
        if (Test-SensitivePath $sourceRelativePath) {
            throw "附件命中敏感文件规则: $sourceRelativePath"
        }
        $sourcePath = Resolve-ContainedPath -Root $sourceDocsRoot -RelativePath $sourceRelativePath -Description '附件源文件'
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            $script:Warnings.Add("附件源文件不存在: $sourceRelativePath")
            continue
        }

        $targetRelativePath = [string] $attachment.target
        $targetPath = Resolve-ContainedPath -Root $assetsTarget -RelativePath $targetRelativePath -Description '附件目标'
        $stageTargetPath = Join-Path $stageRoot ((Get-RelativePath -Root $websiteRootResolved -Path $targetPath) -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $stageTargetPath) | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $stageTargetPath -Force
        $generatedFiles.Add((Get-RelativePath -Root $websiteRootResolved -Path $targetPath))
    }

    $stageSidebarPath = Join-Path $stageRoot ($sidebarRelativePath -replace '/', '\')
    New-SidebarModule -Pages @($pages) -Path $stageSidebarPath
    $generatedFiles.Add($sidebarRelativePath)

    $generatedManifest = New-GeneratedManifest -GeneratedFiles @($generatedFiles) -SourceFiles @($sourceFiles) -ManifestRelativePath $generatedManifestRelativePath
    Write-JsonNoBom -Path $stageGeneratedManifestPath -Value $generatedManifest
    $generatedFiles.Add($generatedManifestRelativePath)

    $previousManifest = $null
    if (Test-Path -LiteralPath $generatedManifestPath -PathType Leaf) {
        try {
            $previousManifest = Get-Content -Raw -LiteralPath $generatedManifestPath | ConvertFrom-Json
        } catch {
            $script:Warnings.Add("无法读取旧同步清单，将跳过常规过期文件清理。")
        }
    }

    $staleFiles = [System.Collections.Generic.List[string]]::new()
    if ($PruneLegacy) {
        foreach ($root in @($spectraTarget, $designerTarget, $assetsTarget)) {
            if (Test-Path -LiteralPath $root -PathType Container) {
                Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
                    $relative = Get-RelativePath -Root $websiteRootResolved -Path $_.FullName
                    if (-not $relative.StartsWith('docs/pages/blogs/', [StringComparison]::OrdinalIgnoreCase)) {
                        $staleFiles.Add($relative)
                    }
                }
            }
        }
    } elseif ($null -ne $previousManifest) {
        foreach ($oldFile in @($previousManifest.files)) {
            if ($generatedFiles -notcontains [string] $oldFile) {
                $staleFiles.Add([string] $oldFile)
            }
        }
    }

    $generatedFiles = @($generatedFiles | Sort-Object -Unique)
    $staleFiles = @($staleFiles | Where-Object { $_ -notin $generatedFiles } | Sort-Object -Unique)
    $plannedAdds = [System.Collections.Generic.List[string]]::new()
    $plannedChanges = [System.Collections.Generic.List[string]]::new()
    $plannedDeletes = [System.Collections.Generic.List[string]]::new()

    foreach ($relative in $generatedFiles) {
        $expectedPath = Join-Path $stageRoot ($relative -replace '/', '\')
        $actualPath = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $relative -Description '生成文件'
        if (-not (Test-Path -LiteralPath $actualPath -PathType Leaf)) {
            $plannedAdds.Add($relative)
        } elseif (Test-PathChanged -ExpectedPath $expectedPath -ActualPath $actualPath) {
            $plannedChanges.Add($relative)
        }
    }

    foreach ($relative in $staleFiles) {
        if ($relative.StartsWith('docs/pages/blogs/', [StringComparison]::OrdinalIgnoreCase)) {
            throw "删除计划意外包含 blogs 文件: $relative"
        }
        $actualPath = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $relative -Description '过期文件'
        if (Test-Path -LiteralPath $actualPath -PathType Leaf) {
            $plannedDeletes.Add($relative)
        }
    }

    Write-Output "文档同步模式: $Mode"
    Write-Output "源文档: $($sourceFiles.Count) 个 Markdown，$($pages.Count) 个页面"
    Write-Output "新增: $($plannedAdds.Count)"
    $plannedAdds | ForEach-Object { Write-Output "  + $_" }
    Write-Output "修改: $($plannedChanges.Count)"
    $plannedChanges | ForEach-Object { Write-Output "  ~ $_" }
    Write-Output "删除: $($plannedDeletes.Count)"
    $plannedDeletes | ForEach-Object { Write-Output "  - $_" }
    foreach ($warning in $script:Warnings) {
        Write-Warning $warning
    }

    if ($Mode -eq 'Preview') {
        Write-Output 'Preview 完成，未修改 website。'
        exit 0
    }

    New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
    $managedRoots = @(
        [string] $manifest.targets.spectra,
        [string] $manifest.targets.designer,
        [string] $manifest.targets.assets,
        ([IO.Path]::GetDirectoryName($sidebarRelativePath).Replace('\', '/'))
    ) | Sort-Object -Unique
    foreach ($relativeRoot in $managedRoots) {
        $actualRoot = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $relativeRoot -Description '受控生成目录'
        if (Test-Path -LiteralPath $actualRoot) {
            $backupPath = Join-Path $backupRoot ($relativeRoot -replace '/', '\')
            Copy-Item -LiteralPath $actualRoot -Destination $backupPath -Recurse -Force
        }
    }

    try {
        foreach ($relative in $staleFiles) {
            $actualPath = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $relative -Description '过期文件'
            if (Test-Path -LiteralPath $actualPath -PathType Leaf) {
                Remove-Item -LiteralPath $actualPath -Force
            }
        }

        foreach ($relative in $generatedFiles) {
            $stagePath = Join-Path $stageRoot ($relative -replace '/', '\')
            $actualPath = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $relative -Description '生成文件'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $actualPath) | Out-Null
            Copy-Item -LiteralPath $stagePath -Destination $actualPath -Force
        }
    } catch {
        foreach ($relativeRoot in $managedRoots) {
            $actualRoot = Resolve-ContainedPath -Root $websiteRootResolved -RelativePath $relativeRoot -Description '回滚目录'
            if (Test-Path -LiteralPath $actualRoot) {
                Remove-Item -LiteralPath $actualRoot -Recurse -Force
            }
            $backupPath = Join-Path $backupRoot ($relativeRoot -replace '/', '\')
            if (Test-Path -LiteralPath $backupPath) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $actualRoot) | Out-Null
                Copy-Item -LiteralPath $backupPath -Destination $actualRoot -Recurse -Force
            }
        }
        throw
    }

    if ($Build) {
        Push-Location $websiteRootResolved
        try {
            & pnpm run docs:build
            if ($LASTEXITCODE -ne 0) {
                throw "website VitePress 构建失败，退出码: $LASTEXITCODE"
            }
        } finally {
            Pop-Location
        }
    }

    Write-Output 'Apply 完成。脚本未执行 Git commit 或 push。'
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $backupRoot) {
        Remove-Item -LiteralPath $backupRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $syncTempRoot) {
        Remove-Item -LiteralPath $syncTempRoot -Recurse -Force
    }
}
