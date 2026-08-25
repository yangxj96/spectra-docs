#requires -Version 7.6

[CmdletBinding()]
param(
    [ValidateSet('auto', 'all', 'backend', 'web', 'app', 'plugin')]
    [string]$Area = 'auto',
    [switch]$Facts
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$currentPath = (Get-Location).Path

$routes = @{
    backend = [pscustomobject]@{
        Name = 'backend'
        Agent = 'spectra-admin/AGENTS.md'
        Skill = '$spectra-admin-spec'
        Docs = @('docs/10-后端/目标领域笔记', 'docs/30-数据模型/目标实体笔记')
        Validate = 'spectra-admin/mvnw.cmd -pl <module> -am test'
    }
    web = [pscustomobject]@{
        Name = 'web'
        Agent = 'spectra-ui/AGENTS.md'
        Skill = '$spectra-ui-spec'
        Docs = @('docs/20-前端/10-spectra-ui.md（仅目标规则未覆盖时）')
        Validate = 'pnpm run type-check; pnpm run test'
    }
    app = [pscustomobject]@{
        Name = 'app'
        Agent = 'spectra-app/AGENTS.md'
        Skill = '$spectra-app-spec'
        Docs = @('docs/20-前端/20-spectra-app.md（仅目标规则未覆盖时）')
        Validate = 'pnpm run type-check; pnpm run build:h5 或 build:mp-weixin'
    }
    plugin = [pscustomobject]@{
        Name = 'plugin'
        Agent = 'logicflow-plugin-flowable/AGENTS.md'
        Skill = '无专用 Skill；使用插件 AGENTS.md'
        Docs = @('docs/20-前端/30-流程建模插件.md（仅节点行为未覆盖时）')
        Validate = 'pnpm run format:check; pnpm run build'
    }
}

if ($Area -eq 'auto') {
    $relativePath = $currentPath.Substring($projectRoot.Length).TrimStart('\')
    $Area = switch -Regex ($relativePath) {
        '^spectra-admin(?:\\|$)' { 'backend'; break }
        '^spectra-ui(?:\\|$)' { 'web'; break }
        '^spectra-app(?:\\|$)' { 'app'; break }
        '^logicflow-plugin-flowable(?:\\|$)' { 'plugin'; break }
        default { 'all' }
    }
}

Write-Output '=== Agent Context Route ==='
Write-Output "Workspace: $projectRoot"
Write-Output "Area: $Area"

if ($Area -eq 'all') {
    $routes.Values |
        Select-Object Name, Agent, Skill, Validate |
        Format-Table -AutoSize -Wrap
    Write-Output 'Docs: 仅按任务读取 docs/00-项目总览.md、架构笔记或一个目标领域笔记。'
} else {
    $route = $routes[$Area]
    $route | Select-Object Name, Agent, Skill, Validate | Format-List
    Write-Output 'Suggested docs:'
    $route.Docs | ForEach-Object { Write-Output "- $_" }
}

Write-Output 'Context policy: 不预加载无关领域文档；结构分析优先使用 CodeGraph。'

if ($Facts) {
    if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
        throw '未找到 rg（ripgrep），无法读取项目事实。'
    }

    $wrapperProperties = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'spectra-admin/.mvn/wrapper/maven-wrapper.properties')
    $mavenVersion = [regex]::Match($wrapperProperties, 'apache-maven-([^/]+)-bin').Groups[1].Value
    $pom = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'spectra-admin/pom.xml')
    $backendVersion = [regex]::Match($pom, '<revision>([^<]+)</revision>').Groups[1].Value
    $springBootVersion = [regex]::Match($pom, '<artifactId>spring-boot-starter-parent</artifactId>\s*<version>([^<]+)</version>').Groups[1].Value
    $controllerCount = (& rg -l '^\s*@RestController\s*$' (Join-Path $projectRoot 'spectra-admin') -g '*.java' | Measure-Object).Count
    $entityCount = (& rg -l '@TableName' (Join-Path $projectRoot 'spectra-admin') -g '*.java' | Measure-Object).Count
    $codeGraph = if (Get-Command codegraph -ErrorAction SilentlyContinue) { '可用' } else { '未在 PATH 中（可选）' }

    Write-Output '=== Project Facts ==='
    [pscustomobject]@{
        BackendVersion = $backendVersion
        SpringBoot = $springBootVersion
        Maven = $mavenVersion
        Controllers = $controllerCount
        Entities = $entityCount
        CodeGraph = $codeGraph
        PowerShell = $PSVersionTable.PSVersion.ToString()
    } | Format-List
}
