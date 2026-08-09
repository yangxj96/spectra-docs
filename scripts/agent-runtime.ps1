#requires -Version 7.6

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$agentJavaCandidates = @(
    $env:SPECTRA_AGENT_JAVA_HOME
    'D:\Develop\Platform\mise\data\installs\java\temurin-25.0.2+10.0.LTS'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }

$agentNodeCandidates = @(
    $env:SPECTRA_AGENT_NODE_BIN
    'D:\Develop\Platform\mise\data\installs\node\24.14.0'
    (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }

$agentPnpmCandidates = @(
    $env:SPECTRA_AGENT_PNPM
    'D:\Develop\Platform\mise\data\installs\pnpm\11.0.9\pnpm.exe'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }

$agentJavaHome = $agentJavaCandidates | Select-Object -First 1
$agentNodeBin = $agentNodeCandidates | Select-Object -First 1
$agentPnpm = $agentPnpmCandidates | Select-Object -First 1

if (-not $agentJavaHome) {
    throw '未找到项目要求的 Java 25。可通过 SPECTRA_AGENT_JAVA_HOME 指定 JDK 目录。'
}
if (-not $agentNodeBin) {
    throw '未找到 Codex bundled Node。可通过 SPECTRA_AGENT_NODE_BIN 指定 Node bin 目录。'
}
if (-not $agentPnpm) {
    throw '未找到项目要求的 pnpm 11.0.9。可通过 SPECTRA_AGENT_PNPM 指定 pnpm.exe。'
}

$env:JAVA_HOME = $agentJavaHome
$env:SPECTRA_PNPM = $agentPnpm
$agentPathPrefixes = @((Split-Path $agentPnpm -Parent), $agentNodeBin, (Join-Path $agentJavaHome 'bin'))
$existingPathParts = $env:Path -split ';' | Where-Object { $_ }
$env:Path = (($agentPathPrefixes + $existingPathParts) | Select-Object -Unique) -join ';'
$env:CI = 'true'

$agentMavenRepoCandidates = @(
    $env:SPECTRA_AGENT_MAVEN_REPO
    (Join-Path $env:USERPROFILE '.m2\repository')
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

[pscustomobject]@{
    JavaHome = $env:JAVA_HOME
    Node = (Get-Command node).Source
    Pnpm = $env:SPECTRA_PNPM
    MavenRepository = $env:SPECTRA_MAVEN_REPO
    CI = $env:CI
} | Format-List
