[CmdletBinding()]
param(
    [string]$PostgresBin = 'D:/Develop/Platform/pgsql18/bin',
    [string]$RedisServer = 'D:/Develop/Platform/redis/redis-server.exe',
    [ValidateRange(1024, 65535)][int]$PostgresPort = 25432,
    [ValidateRange(1024, 65535)][int]$RedisPort = 26379
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path $workspaceRoot '.temp/b02/dependencies'
if (Test-Path -LiteralPath $fixtureRoot) {
    throw 'B02 fixture directory already exists; inspect the existing test processes before reuse.'
}
foreach ($port in @($PostgresPort, $RedisPort)) {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
    try { $listener.Start() } finally { $listener.Stop() }
}
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
$pgData = Join-Path $fixtureRoot 'postgres'
$redisData = Join-Path $fixtureRoot 'redis'
New-Item -ItemType Directory -Path $redisData | Out-Null
& (Join-Path $PostgresBin 'initdb.exe') -D $pgData -U b02_test --auth=trust --encoding=UTF8 --locale=C *> (Join-Path $fixtureRoot 'initdb.log')
if ($LASTEXITCODE -ne 0) { throw "Isolated initdb failed: exit $LASTEXITCODE; inspect .temp/b02/dependencies/initdb.log" }
$pgProcess = Start-Process -FilePath (Join-Path $PostgresBin 'postgres.exe') -ArgumentList @('-D', $pgData, '-p', "$PostgresPort", '-h', '127.0.0.1') -WindowStyle Hidden -RedirectStandardOutput (Join-Path $fixtureRoot 'pg.stdout.log') -RedirectStandardError (Join-Path $fixtureRoot 'pg.stderr.log') -PassThru
$redisProcess = Start-Process -FilePath $RedisServer -ArgumentList @('--bind', '127.0.0.1', '--port', "$RedisPort", '--appendonly', 'no', '--save', '""', '--dir', $redisData, '--logfile', (Join-Path $fixtureRoot 'redis.log')) -WorkingDirectory $redisData -WindowStyle Hidden -PassThru
$ready = $false
for ($attempt = 0; $attempt -lt 20; $attempt++) {
    & (Join-Path $PostgresBin 'pg_isready.exe') -h 127.0.0.1 -p $PostgresPort -U b02_test -d postgres *> $null
    if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    Start-Sleep -Milliseconds 250
}
if (-not $ready) { throw 'Isolated PostgreSQL did not become ready; inspect fixture logs.' }
& (Join-Path $PostgresBin 'createdb.exe') -h 127.0.0.1 -p $PostgresPort -U b02_test b02_test
if ($LASTEXITCODE -ne 0) { throw "Isolated database creation failed: exit $LASTEXITCODE" }
[ordered]@{
    purpose = 'B02 synthetic tests only; fresh loopback dependencies, no business data'
    postgresHost = '127.0.0.1'
    postgresPort = $PostgresPort
    postgresDatabase = 'b02_test'
    postgresUser = 'b02_test'
    postgresProcessId = $pgProcess.Id
    redisHost = '127.0.0.1'
    redisPort = $RedisPort
    redisProcessId = $redisProcess.Id
    directory = $fixtureRoot
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fixtureRoot 'manifest.json')
Write-Output "B02 isolated dependencies: PostgreSQL 127.0.0.1:$PostgresPort/b02_test; Redis 127.0.0.1:$RedisPort. Manifest: .temp/b02/dependencies/manifest.json"
