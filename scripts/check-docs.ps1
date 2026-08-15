#requires -Version 7.6

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$docsRoot = (Resolve-Path (Join-Path $projectRoot 'docs')).Path
$errors = [System.Collections.Generic.List[string]]::new()

if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
    throw '未找到 rg（ripgrep），无法执行文档事实校验。'
}

$allFiles = Get-ChildItem -Recurse -File $docsRoot
$markdownFiles = $allFiles | Where-Object { $_.Extension -eq '.md' }

foreach ($file in $markdownFiles) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    foreach ($match in [regex]::Matches($content, '\[\[([^\]]+)\]\]')) {
        $rawTarget = $match.Groups[1].Value
        $target = (($rawTarget -split '\|')[0] -split '#')[0]
        if ([string]::IsNullOrWhiteSpace($target) -or $target -eq 'wikilink') {
            continue
        }

        $normalized = $target.Replace('/', [IO.Path]::DirectorySeparatorChar)
        $candidates = [System.Collections.Generic.List[string]]::new()
        if ([IO.Path]::GetExtension($normalized)) {
            $candidates.Add((Join-Path $docsRoot $normalized))
            $candidates.Add((Join-Path $file.DirectoryName $normalized))
            foreach ($candidate in $allFiles | Where-Object { $_.Name -eq [IO.Path]::GetFileName($normalized) }) {
                $candidates.Add($candidate.FullName)
            }
        } else {
            $candidates.Add((Join-Path $docsRoot ($normalized + '.md')))
            $candidates.Add((Join-Path $file.DirectoryName ($normalized + '.md')))
            $leaf = [IO.Path]::GetFileName($normalized) + '.md'
            foreach ($candidate in $markdownFiles | Where-Object { $_.Name -eq $leaf }) {
                $candidates.Add($candidate.FullName)
            }
        }

        if (-not ($candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)) {
            $line = ($content.Substring(0, $match.Index) -split "`n").Count
            $relative = $file.FullName.Substring($projectRoot.Length + 1)
            $errors.Add("失效 wikilink: ${relative}:${line} [[$rawTarget]]")
        }
    }
}

$controllerFiles = & rg -l '^\s*@RestController\s*$' (Join-Path $projectRoot 'spectra-admin') -g '*.java'
$controllerNames = $controllerFiles | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) } | Sort-Object -Unique
$entityCount = (& rg -l '@TableName' (Join-Path $projectRoot 'spectra-admin') -g '*.java' | Measure-Object).Count
$overview = Get-Content -Raw -LiteralPath (Join-Path $docsRoot '00-项目总览.md')

if ($overview -notmatch [regex]::Escape("$entityCount 个 Entity")) {
    $errors.Add("项目总览中的 Entity 数量不是源码实际值 $entityCount。")
}
if ($overview -notmatch [regex]::Escape("$($controllerNames.Count) 个 Controller")) {
    $errors.Add("项目总览中的 Controller 数量不是源码实际值 $($controllerNames.Count)。")
}

$configExpectations = @(
    [pscustomobject]@{ Path = 'spectra-admin/.mise.local.toml.example'; Pattern = 'SERVER_PORT\s*=\s*"4004"'; Description = '后端模板端口 4004' }
    [pscustomobject]@{ Path = 'spectra-admin/.mise.local.toml.example'; Pattern = 'SERVER_SSL_ENABLED\s*=\s*"false"'; Description = '后端模板首次启动关闭 HTTPS' }
    [pscustomobject]@{ Path = 'spectra-ui/.env.example'; Pattern = 'VITE_API_URL=http://127\.0\.0\.1:4004/'; Description = 'Web 模板直连 HTTP 4004' }
    [pscustomobject]@{ Path = 'spectra-app/.env.example'; Pattern = 'VITE_API_BASE_URL\s*=\s*"http://127\.0\.0\.1:4004"'; Description = 'App 模板 HTTP 4004' }
)
foreach ($expectation in $configExpectations) {
    $configPath = Join-Path $projectRoot $expectation.Path
    $configContent = Get-Content -Raw -LiteralPath $configPath
    if ($configContent -notmatch $expectation.Pattern) {
        $errors.Add("配置模板与首次启动文档不一致：$($expectation.Description)（$($expectation.Path)）。")
    }
}

$devConfig = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'spectra-admin/spectra-config/src/main/resources/application-dev.yml')
$requiredBackendVariables = [regex]::Matches($devConfig, '\$\{([A-Z][A-Z0-9_]*)(?::[^}]*)?\}') |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique
$backendTemplate = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'spectra-admin/.mise.local.toml.example')
$providedBackendVariables = [regex]::Matches($backendTemplate, '(?m)^([A-Z][A-Z0-9_]*)\s*=') |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique
$missingBackendVariables = $requiredBackendVariables | Where-Object { $_ -notin $providedBackendVariables }
$allowedBackendOverrides = @('SERVER_SSL_ENABLED')
$unexpectedBackendVariables = $providedBackendVariables |
    Where-Object { $_ -notin $requiredBackendVariables -and $_ -notin $allowedBackendOverrides }
if ($missingBackendVariables) {
    $errors.Add("后端本机模板缺少 application-dev.yml 变量：$($missingBackendVariables -join ', ')。")
}
if ($unexpectedBackendVariables) {
    $errors.Add("后端本机模板包含源码未使用的旧变量：$($unexpectedBackendVariables -join ', ')。")
}

foreach ($relativeDoc in @('10-后端/90-API总览.md', '70-AI速查/04-API端点.md')) {
    $path = Join-Path $docsRoot $relativeDoc
    $content = Get-Content -Raw -LiteralPath $path
    $documentedNames = [regex]::Matches($content, '`?([A-Z][A-Za-z0-9]+Controller)`?') |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique
    $missing = Compare-Object $documentedNames $controllerNames |
        Where-Object SideIndicator -eq '=>' |
        ForEach-Object { $_.InputObject }
    if ($missing) {
        $errors.Add("$relativeDoc 缺少 Controller: $($missing -join ', ')")
    }
}

$stalePatterns = @(
    'logicflow-flowable/'
    'document/Plans/'
    '31-OA建表SQL.sql'
    '20-知识库/'
    'D:\Develop\'
    'C:\Users\'
)
$staleTargets = @(
    $docsRoot
    (Join-Path $projectRoot 'README.md')
    (Join-Path $projectRoot 'AGENTS.md')
    (Join-Path $projectRoot 'spectra-admin/README.md')
    (Join-Path $projectRoot 'spectra-admin/AGENTS.md')
    (Join-Path $projectRoot 'spectra-ui/README.md')
    (Join-Path $projectRoot 'spectra-ui/AGENTS.md')
    (Join-Path $projectRoot 'spectra-app/README.md')
    (Join-Path $projectRoot 'spectra-app/AGENTS.md')
    (Join-Path $projectRoot 'logicflow-plugin-flowable/README.md')
    (Join-Path $projectRoot 'logicflow-plugin-flowable/AGENTS.md')
    (Join-Path $projectRoot '.agents/plugins/spectra')
)
foreach ($pattern in $stalePatterns) {
    $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    try {
        $matches = & rg -n -F $pattern $staleTargets 2>$null
        $rgExitCode = $LASTEXITCODE
    } finally {
        $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
    }
    if ($rgExitCode -gt 1) {
        throw "扫描过期内容失败：rg 退出码 $rgExitCode，模式 $pattern"
    }
    foreach ($result in $matches) {
        $errors.Add("过期内容: $result")
    }
}

foreach ($plan in Get-ChildItem -Recurse -File (Join-Path $docsRoot '90-计划') -Filter 'P-*.md') {
    $head = (Get-Content -LiteralPath $plan.FullName | Select-Object -First 45) -join "`n"
    if ($head -match '\*\*已完成(?:（[^）]+）)?\*\*|\*\*全部阶段已完成\*\*|status:\s*(?:completed|done)') {
        $errors.Add("已完成计划仍在执行计划目录: $($plan.FullName.Substring($projectRoot.Length + 1))")
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "文档检查通过：$($markdownFiles.Count) 个 Markdown 文件，$entityCount 个 Entity，$($controllerNames.Count) 个 Controller。"
