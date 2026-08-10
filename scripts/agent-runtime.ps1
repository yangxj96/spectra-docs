#requires -Version 7.6

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$javaCommand = Get-Command java -ErrorAction SilentlyContinue
$javaHomeFromPath = if ($javaCommand) {
    Split-Path (Split-Path $javaCommand.Source -Parent) -Parent
}
$nodeCommand = Get-Command node -ErrorAction SilentlyContinue
$nodeBinFromPath = if ($nodeCommand) { Split-Path $nodeCommand.Source -Parent }
$pnpmCommand = Get-Command pnpm -ErrorAction SilentlyContinue
$pnpmFromPath = if ($pnpmCommand) { $pnpmCommand.Source }

$agentJavaCandidates = @(
    $env:SPECTRA_AGENT_JAVA_HOME
    $env:JAVA_HOME
    $javaHomeFromPath
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }

$agentNodeCandidates = @(
    $env:SPECTRA_AGENT_NODE_BIN
    $nodeBinFromPath
    (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }

$agentPnpmCandidates = @(
    $env:SPECTRA_AGENT_PNPM
    $pnpmFromPath
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }

$agentJavaHome = $agentJavaCandidates | Where-Object {
    $javaExecutable = Join-Path $_ 'bin\java.exe'
    if (-not (Test-Path -LiteralPath $javaExecutable -PathType Leaf)) {
        return $false
    }
    $versionOutput = (& $javaExecutable -version 2>&1 | Select-Object -First 1) -join ''
    $versionOutput -match 'version "25(?:\.|\")'
} | Select-Object -First 1

$agentNodeBin = $agentNodeCandidates | Where-Object {
    $nodeExecutable = Join-Path $_ 'node.exe'
    (Test-Path -LiteralPath $nodeExecutable -PathType Leaf) -and ((& $nodeExecutable --version) -eq 'v24.14.0')
} | Select-Object -First 1

$agentPnpm = $agentPnpmCandidates | Where-Object {
    ((& $_ --version) -join '').Trim() -eq '11.0.9'
} | Select-Object -First 1

if (-not $agentJavaHome) {
    throw '未找到项目要求的 Java 25。请先激活 mise，或通过 SPECTRA_AGENT_JAVA_HOME 指定 JDK 目录。'
}
if (-not $agentNodeBin) {
    throw '未找到项目要求的 Node 24.14.0。请先激活 mise，或通过 SPECTRA_AGENT_NODE_BIN 指定 Node bin 目录。'
}
if (-not $agentPnpm) {
    throw '未找到项目要求的 pnpm 11.0.9。请先激活 mise，或通过 SPECTRA_AGENT_PNPM 指定 pnpm 可执行文件。'
}

$env:JAVA_HOME = $agentJavaHome
$env:SPECTRA_PNPM = $agentPnpm
$agentPathPrefixes = @((Split-Path $agentPnpm -Parent), $agentNodeBin, (Join-Path $agentJavaHome 'bin'))
$existingPathParts = $env:Path -split ';' | Where-Object { $_ }
$env:Path = (($agentPathPrefixes + $existingPathParts) | Select-Object -Unique) -join ';'
$env:CI = 'true'

$workspaceMavenRepo = Join-Path $projectRoot '.maven-repository'
if (-not (Test-Path -LiteralPath $workspaceMavenRepo -PathType Container)) {
    New-Item -ItemType Directory -Path $workspaceMavenRepo -Force | Out-Null
}

$agentMavenRepoCandidates = @(
    $env:SPECTRA_AGENT_MAVEN_REPO
    (Join-Path $env:USERPROFILE '.m2\repository')
    $workspaceMavenRepo
    (Join-Path $env:TEMP 'spectra-maven-repository')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }

$agentMavenRepo = $null
foreach ($candidate in $agentMavenRepoCandidates) {
    try {
        $probePath = Join-Path $candidate ('.codex-write-test-' + $PID)
        Set-Content -LiteralPath $probePath -Value 'ok' -NoNewline
        Remove-Item -LiteralPath $probePath -Force
        $agentMavenRepo = $candidate
        break
    } catch {
        continue
    }
}

if (-not $agentMavenRepo) {
    throw '未找到可写的 Maven 本地仓库。可通过 SPECTRA_AGENT_MAVEN_REPO 指定目录。'
}

$env:SPECTRA_MAVEN_REPO = $agentMavenRepo
$mavenRepoOption = "-Dmaven.repo.local=$agentMavenRepo"
$existingMavenOpts = @($env:MAVEN_OPTS -split '\s+' | Where-Object {
    $_ -and $_ -notlike '-Dmaven.repo.local=*'
})
$env:MAVEN_OPTS = (($existingMavenOpts + $mavenRepoOption) -join ' ').Trim()

[pscustomobject]@{
    JavaHome = $env:JAVA_HOME
    Node = (Get-Command node).Source
    Pnpm = $env:SPECTRA_PNPM
    MavenRepository = $env:SPECTRA_MAVEN_REPO
    MavenOpts = $env:MAVEN_OPTS
    CI = $env:CI
} | Format-List
