$syncPythonScript = Join-Path $PSScriptRoot 'sync-website-docs.py'
$syncPythonCommand = Get-Command -Name python3 -CommandType Application -ErrorAction SilentlyContinue

if ($null -eq $syncPythonCommand) {
    $syncPythonCommand = Get-Command -Name python -CommandType Application -ErrorAction SilentlyContinue
}

if ($null -eq $syncPythonCommand) {
    [Console]::Error.WriteLine('Python 3 was not found in PATH (looked for python3 and python).')
    exit 1
}

& $syncPythonCommand.Source $syncPythonScript @args
$syncExitCode = 0
if ($null -ne $LASTEXITCODE) {
    $syncExitCode = [int] $LASTEXITCODE
}

exit $syncExitCode
