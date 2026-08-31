#requires -Version 7.6

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$backendRoot = (Resolve-Path (Join-Path $workspaceRoot 'spectra-admin')).Path

$moduleDefinitions = [ordered]@{
    'spectra-common' = [pscustomobject]@{ RelativeRoot = 'spectra-common'; PackageRoot = 'com.devops00.spectra.common' }
    'spectra-config' = [pscustomobject]@{ RelativeRoot = 'spectra-config'; PackageRoot = 'com.devops00.spectra.config' }
    'spectra-framework' = [pscustomobject]@{ RelativeRoot = 'spectra-framework'; PackageRoot = 'com.devops00.spectra.framework' }
    'spectra-launch' = [pscustomobject]@{ RelativeRoot = 'spectra-launch'; PackageRoot = 'com.devops00.spectra.launch' }
    'spectra-security-base' = [pscustomobject]@{ RelativeRoot = 'spectra-starter/spectra-security-base'; PackageRoot = 'com.devops00.spectra.security.base' }
    'spectra-security-spring-boot-starter' = [pscustomobject]@{ RelativeRoot = 'spectra-starter/spectra-security-spring-boot-starter'; PackageRoot = 'com.devops00.spectra.security' }
    'spectra-notification' = [pscustomobject]@{ RelativeRoot = 'spectra-modules/spectra-notification'; PackageRoot = 'com.devops00.spectra.notification' }
    'spectra-core' = [pscustomobject]@{ RelativeRoot = 'spectra-modules/spectra-core'; PackageRoot = 'com.devops00.spectra.core' }
    'spectra-upload' = [pscustomobject]@{ RelativeRoot = 'spectra-modules/spectra-upload'; PackageRoot = 'com.devops00.spectra.upload' }
    'spectra-workflow' = [pscustomobject]@{ RelativeRoot = 'spectra-modules/spectra-workflow'; PackageRoot = 'com.devops00.spectra.workflow' }
    'spectra-oa' = [pscustomobject]@{ RelativeRoot = 'spectra-modules/spectra-oa'; PackageRoot = 'com.devops00.spectra.oa' }
}

$sourceFiles = Get-ChildItem -LiteralPath $backendRoot -Recurse -File -Include '*.java', '*.yml', '*.yaml', '*.xml', '*.properties' |
    Where-Object {
        $_.FullName -notmatch '\\target\\' -and
        $_.FullName -notmatch '\\src\\test\\' -and
        $_.FullName -notmatch '\\.mise\.local\.toml$' -and
        $_.Name -ne 'pom.xml' -and
        $_.Name -notlike '*.flattened-pom.xml'
    }

$pomFiles = Get-ChildItem -LiteralPath $backendRoot -Recurse -File -Filter 'pom.xml' |
    Where-Object { $_.FullName -notmatch '\\target\\' }

# POM 中的禁止依赖清单本身必须包含 Nacos/Discovery 等关键词；依赖是否引入由根 POM 的
# Maven Enforcer bannedDependencies 规则检查，源码与配置扫描不应把规则声明误报为运行时入口。
$scanFiles = @($sourceFiles)

$forbiddenPatterns = @(
    [pscustomobject]@{ Name = '应用级租户上下文'; Pattern = '(?i)\bTenantContext\b' }
    [pscustomobject]@{ Name = '租户解析器'; Pattern = '(?i)\bTenantResolver\b' }
    [pscustomobject]@{ Name = '租户服务'; Pattern = '(?i)\bTenantService\b' }
    [pscustomobject]@{ Name = '租户 ID'; Pattern = '(?i)\btenantId\b' }
    [pscustomobject]@{ Name = '应用租户字段'; Pattern = '(?i)\btenant_id\b' }
    [pscustomobject]@{ Name = '多租户关键词'; Pattern = '(?i)multi[-_ ]?tenant' }
    [pscustomobject]@{ Name = '多租户中文关键词'; Pattern = '多租户' }
    [pscustomobject]@{ Name = 'SaaS 关键词'; Pattern = '(?i)\bSaaS\b' }
    [pscustomobject]@{ Name = 'Nacos/服务发现关键词'; Pattern = '(?i)nacos|spring[-.]cloud|service[-.]?discovery|discoveryClient|eureka|consul' }
)

$violations = [System.Collections.Generic.List[string]]::new()
$violationRules = [System.Collections.Generic.List[string]]::new()
foreach ($file in $scanFiles) {
    foreach ($pattern in $forbiddenPatterns) {
        $matches = Select-String -LiteralPath $file.FullName -Pattern $pattern.Pattern
        foreach ($match in $matches) {
            $violations.Add('{0}:{1}: {2}' -f $match.Path, $match.LineNumber, $match.Line.Trim())
            $violationRules.Add($pattern.Name)
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Output '发现应用级租户或 SaaS 入口：'
    $violations | Sort-Object -Unique | ForEach-Object { Write-Output "- $_" }
    throw '单租户架构检查失败。Flowable 内部 tenant_id_ 只允许存在于引擎 schema，不应出现在应用 Java、配置或运行时 XML 中。'
}

[xml]$rootPom = Get-Content -Raw -LiteralPath (Join-Path $backendRoot 'pom.xml')
$namespace = [System.Xml.XmlNamespaceManager]::new($rootPom.NameTable)
$namespace.AddNamespace('m', 'http://maven.apache.org/POM/4.0.0')
$declaredModules = @($rootPom.SelectNodes('/m:project/m:modules/m:module', $namespace) | ForEach-Object InnerText)

$businessPackagePrefixes = @(
    'com.devops00.spectra.core.',
    'com.devops00.spectra.oa.',
    'com.devops00.spectra.workflow.',
    'com.devops00.spectra.notification.',
    'com.devops00.spectra.upload.',
    'com.devops00.spectra.erp.'
)
$optionalBusinessPackagePrefixes = @(
    'com.devops00.spectra.oa.',
    'com.devops00.spectra.workflow.',
    'com.devops00.spectra.notification.',
    'com.devops00.spectra.upload.',
    'com.devops00.spectra.erp.'
)
$architectureViolations = [System.Collections.Generic.List[string]]::new()
$architectureRulesChecked = [System.Collections.Generic.List[string]]::new()

function Get-MainJavaFiles([string]$relativeRoot) {
    $mainRoot = Join-Path $backendRoot (Join-Path $relativeRoot 'src/main/java')
    if (-not (Test-Path -LiteralPath $mainRoot)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $mainRoot -Recurse -File -Filter '*.java')
}

function Get-ImportLines([System.IO.FileInfo]$file) {
    return @(Select-String -LiteralPath $file.FullName -Pattern '^\s*import\s+' | ForEach-Object Line)
}

function Get-PackageLine([System.IO.FileInfo]$file) {
    return (Select-String -LiteralPath $file.FullName -Pattern '^\s*package\s+' | Select-Object -First 1).Line
}

function Add-ArchitectureViolation([string]$rule, [System.IO.FileInfo]$file, [string]$message) {
    $location = if ($null -eq $file) { '' } else { '{0}: ' -f $file.FullName }
    $architectureViolations.Add('{0}: {1}{2}' -f $rule, $location, $message)
}

function Get-DirectMavenArtifactIds([System.IO.FileInfo]$pomFile) {
    [xml]$pom = Get-Content -Raw -LiteralPath $pomFile.FullName
    $pomNamespace = [System.Xml.XmlNamespaceManager]::new($pom.NameTable)
    $pomNamespace.AddNamespace('m', 'http://maven.apache.org/POM/4.0.0')
    return @($pom.SelectNodes('/m:project/m:dependencies/m:dependency/m:artifactId', $pomNamespace) |
        ForEach-Object InnerText)
}

$coreSources = Get-MainJavaFiles 'spectra-modules/spectra-core'
foreach ($file in $coreSources) {
    $imports = Get-ImportLines $file
    foreach ($prefix in $optionalBusinessPackagePrefixes) {
        if ($imports | Where-Object { $_ -match [regex]::Escape($prefix) }) {
            Add-ArchitectureViolation 'Core 不得依赖可选业务实现' $file "发现 import: $prefix"
        }
    }
}
$architectureRulesChecked.Add('core-no-optional-business-imports')

$launchSources = Get-MainJavaFiles 'spectra-launch'
foreach ($file in $launchSources) {
    $packageLine = Get-PackageLine $file
    if ($packageLine -notmatch '^\s*package\s+com\.devops00\.spectra\.launch(?:\.|;)') {
        Add-ArchitectureViolation 'Launch 只允许装配代码' $file "包声明不属于 launch: $packageLine"
    }
    if ($file.Name -match '(Controller|Entity|Mapper|Repository|Service)\.java$') {
        Add-ArchitectureViolation 'Launch 只允许装配代码' $file '启动模块不得包含业务实现类文件'
    }
    if ((Get-Content -Raw -LiteralPath $file.FullName) -match '(?m)^\s*@(RestController|Controller|Service|Repository|Mapper|Entity)\b') {
        Add-ArchitectureViolation 'Launch 只允许装配代码' $file '启动模块不得声明业务 Spring/MyBatis 组件'
    }
}
$architectureRulesChecked.Add('launch-assembly-only')

foreach ($layer in @(
        [pscustomobject]@{ Name = 'common'; RelativeRoot = 'spectra-common' },
        [pscustomobject]@{ Name = 'framework'; RelativeRoot = 'spectra-framework' })) {
    foreach ($file in (Get-MainJavaFiles $layer.RelativeRoot)) {
        $imports = Get-ImportLines $file
        foreach ($prefix in $businessPackagePrefixes) {
            if ($imports | Where-Object { $_ -match [regex]::Escape($prefix) }) {
                Add-ArchitectureViolation "$($layer.Name) 不得反向依赖业务模块" $file "发现 import: $prefix"
            }
        }
    }
}
$architectureRulesChecked.Add('common-framework-no-business-imports')

foreach ($module in @(
        'spectra-modules/spectra-core',
        'spectra-modules/spectra-oa',
        'spectra-modules/spectra-workflow',
        'spectra-modules/spectra-notification',
        'spectra-modules/spectra-upload')) {
    foreach ($file in (Get-MainJavaFiles $module)) {
        $imports = Get-ImportLines $file
        if ($imports | Where-Object { $_ -match 'com\.devops00\.spectra\.launch\.' }) {
            Add-ArchitectureViolation '业务模块不得依赖 launch' $file '发现 launch import'
        }
    }
}
$architectureRulesChecked.Add('business-no-launch-imports')

$auditSources = @($sourceFiles | Where-Object { $_.Extension -eq '.java' -and $_.FullName -match '\\src\\main\\java\\' })
foreach ($file in $auditSources) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    if ($content -match '(?m)^\s*@Audit\b' -and
        $content -notmatch 'import\s+com\.devops00\.spectra\.common\.audit\.Audit;') {
        Add-ArchitectureViolation '统一审计入口' $file '@Audit 必须来自 common.audit.Audit'
    }
}
foreach ($legacyType in @(
        'spectra-starter/spectra-log-base/src/main/java/com/devops00/spectra/log/base/annotation/ULog.java',
        'spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/common/listener/ulog/ULogListener.java',
        'spectra-starter/spectra-log-base/src/main/java/com/devops00/spectra/log/base/entity/ULogEntity.java',
        'spectra-starter/spectra-log-base/src/main/java/com/devops00/spectra/log/base/publisher/ULogEventPublisher.java')) {
    if (Test-Path -LiteralPath (Join-Path $backendRoot $legacyType)) {
        Add-ArchitectureViolation '统一审计入口' $null "旧 ULog 类型不得恢复: $legacyType"
    }
}
foreach ($legacyModule in @(
        'spectra-starter/spectra-log-base',
        'spectra-starter/spectra-log-spring-boot-starter')) {
    if (Test-Path -LiteralPath (Join-Path $backendRoot $legacyModule)) {
        Add-ArchitectureViolation '统一审计入口' $null "旧日志模块不得恢复: $legacyModule"
    }
}
$architectureRulesChecked.Add('unified-audit-entry')

$healthContributors = @(
    'spectra-framework/src/main/java/com/devops00/spectra/framework/health/DataSourceHealthContributor.java',
    'spectra-framework/src/main/java/com/devops00/spectra/framework/health/RedisHealthContributor.java',
    'spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/scheduler/health/SchedulerHealthIndicator.java',
    'spectra-modules/spectra-notification/src/main/java/com/devops00/spectra/notification/health/NotificationHealthIndicator.java',
    'spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/health/FileStorageHealthIndicator.java',
    'spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/health/FlowableHealthContributor.java'
)
foreach ($relativePath in $healthContributors) {
    $path = Join-Path $backendRoot $relativePath
    if (-not (Test-Path -LiteralPath $path)) {
        Add-ArchitectureViolation '统一健康 contributor' $null "缺少健康实现: $relativePath"
        continue
    }
    $content = Get-Content -Raw -LiteralPath $path
    if ($content -notmatch 'com\.devops00\.spectra\.common\.health\.DependencyHealthContributor') {
        Add-ArchitectureViolation '统一健康 contributor' $null "健康实现未使用统一协议: $relativePath"
    }
}
foreach ($requiredHealthType in @(
        'spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/health/CoreHealthRegistry.java',
        'spectra-framework/src/main/java/com/devops00/spectra/framework/health/ActuatorHealthContributorAdapter.java')) {
    if (-not (Test-Path -LiteralPath (Join-Path $backendRoot $requiredHealthType))) {
        Add-ArchitectureViolation '统一健康 contributor' $null "缺少统一健康入口: $requiredHealthType"
    }
}
$architectureRulesChecked.Add('unified-health-contributor')

$directDependencyPolicies = @{
    'spectra-common' = @('spectra-core', 'spectra-oa', 'spectra-workflow', 'spectra-notification', 'spectra-upload', 'spectra-erp', 'spectra-framework', 'spectra-starter')
    'spectra-framework' = @('spectra-core', 'spectra-oa', 'spectra-workflow', 'spectra-notification', 'spectra-upload', 'spectra-erp')
    'spectra-core' = @('spectra-modules', 'spectra-starter', 'spectra-oa', 'spectra-workflow', 'spectra-notification', 'spectra-upload', 'spectra-erp')
    'spectra-launch' = @('spectra-modules', 'spectra-starter')
}
foreach ($pomFile in $pomFiles) {
    [xml]$pom = Get-Content -Raw -LiteralPath $pomFile.FullName
    $pomNamespace = [System.Xml.XmlNamespaceManager]::new($pom.NameTable)
    $pomNamespace.AddNamespace('m', 'http://maven.apache.org/POM/4.0.0')
    $artifactNode = $pom.SelectSingleNode('/m:project/m:artifactId', $pomNamespace)
    if ($null -eq $artifactNode -or -not $directDependencyPolicies.ContainsKey($artifactNode.InnerText)) {
        continue
    }
    $forbiddenDependencies = $directDependencyPolicies[$artifactNode.InnerText]
    foreach ($dependency in (Get-DirectMavenArtifactIds $pomFile)) {
        if ($forbiddenDependencies -contains $dependency) {
            Add-ArchitectureViolation 'Maven 直接依赖方向' $pomFile "[$($artifactNode.InnerText)] 不得直接依赖 $dependency"
        }
    }
}
$architectureRulesChecked.Add('maven-leaf-dependency-direction')

if ($architectureViolations.Count -gt 0) {
    Write-Output '发现架构边界违规：'
    $architectureViolations | Sort-Object -Unique | ForEach-Object { Write-Output "- $_" }
    throw '模块化单体架构门禁失败。请先修复上述归属、依赖、日志或健康入口问题。'
}

$moduleInventory = foreach ($entry in $moduleDefinitions.GetEnumerator()) {
    $moduleRoot = Join-Path $backendRoot $entry.Value.RelativeRoot
    $mainRoot = Join-Path $moduleRoot 'src/main/java'
    $testRoot = Join-Path $moduleRoot 'src/test/java'
    $mainFiles = if (Test-Path -LiteralPath $mainRoot) { @(Get-ChildItem -LiteralPath $mainRoot -Recurse -File -Filter '*.java') } else { @() }
    $testFiles = if (Test-Path -LiteralPath $testRoot) { @(Get-ChildItem -LiteralPath $testRoot -Recurse -File -Filter '*.java') } else { @() }

    [pscustomobject]@{
        Module = $entry.Key
        MainJava = $mainFiles.Count
        TestJava = $testFiles.Count
        Controllers = @($mainFiles | Where-Object Name -Match 'Controller\.java$').Count
        Entities = @($mainFiles | Where-Object Name -Match 'Entity\.java$').Count
        Mappers = @($mainFiles | Where-Object Name -Match 'Mapper\.java$').Count
        Services = @($mainFiles | Where-Object Name -Match 'Service(Impl)?\.java$').Count
        Configurations = @($mainFiles | Where-Object Name -Match '(Configuration|Config)\.java$').Count
        HealthIndicators = @($mainFiles | Where-Object Name -Match 'HealthIndicator\.java$').Count
        Listeners = @($mainFiles | Where-Object Name -Match 'Listener\.java$').Count
        Handlers = @($mainFiles | Where-Object Name -Match 'Handler\.java$').Count
    }
}

$dependencyInventory = foreach ($pomFile in $pomFiles) {
    [xml]$pom = Get-Content -Raw -LiteralPath $pomFile.FullName
    $pomNamespace = [System.Xml.XmlNamespaceManager]::new($pom.NameTable)
    $pomNamespace.AddNamespace('m', 'http://maven.apache.org/POM/4.0.0')
    $artifactNode = $pom.SelectSingleNode('/m:project/m:artifactId', $pomNamespace)
    if ($null -eq $artifactNode) { continue }
    $dependencies = @($pom.SelectNodes('/m:project/m:dependencies/m:dependency/m:artifactId', $pomNamespace) | ForEach-Object InnerText)
    if ($dependencies.Count -gt 0) {
        [pscustomobject]@{
            Artifact = $artifactNode.InnerText
            DirectDependencies = ($dependencies -join ', ')
        }
    }
}

Write-Output '模块源码角色盘点（文件名后缀统计，作为迁移清单索引，不替代语义审查）：'
$moduleInventory | Format-Table -AutoSize
Write-Output '当前 Maven 直接依赖盘点（仅记录现状，后续任务再按归属矩阵收敛）：'
$dependencyInventory | Sort-Object Artifact | Format-Table -Wrap -AutoSize

[pscustomobject]@{
    Status = 'PASS'
    ScannedSourceFiles = $sourceFiles.Count
    ScannedPomFiles = $pomFiles.Count
    MavenRootModules = ($declaredModules -join ', ')
    ModuleCount = $moduleInventory.Count
    MainJavaFiles = ($moduleInventory | Measure-Object -Property MainJava -Sum).Sum
    TestJavaFiles = ($moduleInventory | Measure-Object -Property TestJava -Sum).Sum
    ForbiddenRulesChecked = $forbiddenPatterns.Count
    ForbiddenMatches = 0
    ArchitectureRulesChecked = $architectureRulesChecked.Count
    ArchitectureViolations = 0
} | Format-List
