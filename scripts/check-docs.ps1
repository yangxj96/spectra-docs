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

$stalePatterns = @('logicflow-flowable/', 'document/Plans/', '31-OA建表SQL.sql', '使用三斜杠（`///`）注释')
foreach ($pattern in $stalePatterns) {
    $matches = & rg -n -F $pattern $docsRoot (Join-Path $projectRoot 'AGENTS.md') (Join-Path $projectRoot 'spectra-admin/AGENTS.md') (Join-Path $projectRoot '.agents/plugins/spectra') 2>$null
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
