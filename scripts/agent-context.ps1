#requires -Version 7.6

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
    throw '未找到 rg（ripgrep），无法快速读取项目事实。'
}

$wrapperProperties = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'spectra-admin/.mvn/wrapper/maven-wrapper.properties')
$mavenVersion = [regex]::Match($wrapperProperties, 'apache-maven-([^/]+)-bin').Groups[1].Value
$pom = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'spectra-admin/pom.xml')
$backendVersion = [regex]::Match($pom, '<revision>([^<]+)</revision>').Groups[1].Value
$springBootVersion = [regex]::Match($pom, '<artifactId>spring-boot-starter-parent</artifactId>\s*<version>([^<]+)</version>').Groups[1].Value

$controllerCount = (& rg -l '^\s*@RestController\s*$' (Join-Path $projectRoot 'spectra-admin') -g '*.java' | Measure-Object).Count
$entityCount = (& rg -l '@TableName' (Join-Path $projectRoot 'spectra-admin') -g '*.java' | Measure-Object).Count

$projects = @(
    [pscustomobject]@{ Project = 'spectra-admin'; Runtime = 'Java 25.0.2'; PackageManager = "Maven $mavenVersion (wrapper)"; Check = '.\mvnw.cmd spotless:check'; Build = '.\mvnw.cmd clean package -DskipTests' }
    [pscustomobject]@{ Project = 'spectra-ui'; Runtime = 'Node 24.14.0'; PackageManager = 'pnpm 11.0.9'; Check = 'pnpm run format:check; pnpm run lint; pnpm run type-check; pnpm run test'; Build = 'pnpm run build' }
    [pscustomobject]@{ Project = 'spectra-app'; Runtime = 'Node 24.14.0'; PackageManager = 'pnpm 11.0.9'; Check = 'pnpm run format:check; pnpm run lint; pnpm run type-check'; Build = 'pnpm run build:h5' }
    [pscustomobject]@{ Project = 'logicflow-plugin-flowable'; Runtime = 'Node 24.14.0'; PackageManager = 'pnpm 11.0.9'; Check = 'pnpm run format:check'; Build = 'pnpm run build' }
)

$planRows = foreach ($file in Get-ChildItem -Recurse -File (Join-Path $projectRoot 'docs/90-计划') -Filter 'P-*.md') {
    $lines = Get-Content -LiteralPath $file.FullName
    $statusIndex = [Array]::IndexOf($lines, '## 状态')
    $status = if ($statusIndex -ge 0) {
        $lines[($statusIndex + 1)..([Math]::Min($statusIndex + 6, $lines.Count - 1))] |
            Where-Object { $_.Trim() -ne '' } |
            Select-Object -First 1
    } else {
        '未声明'
    }
    [pscustomobject]@{
        Plan = $file.BaseName
        Area = Split-Path $file.DirectoryName -Leaf
        Status = $status
    }
}

Write-Output '=== Spectra 快速上下文 ==='
[pscustomobject]@{
    Root = $projectRoot
    BackendVersion = $backendVersion
    SpringBoot = $springBootVersion
    Entities = $entityCount
    Controllers = $controllerCount
    CodeGraph = 'D:\Develop\Platform\codegraph\bin\codegraph.cmd'
    PowerShell = $PSVersionTable.PSVersion.ToString()
} | Format-List

Write-Output '=== 子项目与验证命令 ==='
$projects | Format-Table -AutoSize -Wrap

Write-Output '=== Agent 环境回退 ==='
Write-Output 'mise 未信任或沙箱运行时不可写时：. .\scripts\agent-runtime.ps1'
Write-Output 'Node 项目会直接使用项目固定的 Node 24.14.0 与 pnpm 11.0.9。'
Write-Output '后端 Maven 仓库由 agent-runtime.ps1 自动注入 MAVEN_OPTS，无需逐条追加参数。'

Write-Output '=== 保留的执行计划 ==='
$planRows | Sort-Object Area, Plan | Format-Table -AutoSize -Wrap

Write-Output '完整命令说明：docs/50-开发指南/20-常见命令.md'
