$ErrorActionPreference = 'Stop'
$deployRoot = Join-Path $PSScriptRoot '..\.deploy'
$deployRoot = [IO.Path]::GetFullPath($deployRoot)
New-Item -ItemType Directory -Path $deployRoot -Force | Out-Null
$stateFile = Join-Path $deployRoot 'process.json'
if (Test-Path -LiteralPath $stateFile) {
    $previous = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $oldProcess = Get-Process -Id $previous.pid -ErrorAction SilentlyContinue
    if ($oldProcess -and $oldProcess.Path -eq $previous.path -and
        $oldProcess.Path.StartsWith($deployRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        Stop-Process -Id $oldProcess.Id
        Wait-Process -Id $oldProcess.Id -Timeout 15 -ErrorAction SilentlyContinue
    }
}
$busy = Get-NetTCPConnection -LocalPort 5001 -State Listen -ErrorAction SilentlyContinue
if ($busy) { throw 'Port 5001 is occupied. No unrelated process was stopped.' }
$release = Join-Path $deployRoot ('release-' + $env:BUILD_NUMBER + '-' + (Get-Date -Format 'yyyyMMddHHmmss'))
New-Item -ItemType Directory -Path $release -Force | Out-Null
$binary = Join-Path $release 'flask-demo.exe'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\dist\flask-demo.exe') -Destination $binary
$env:PORT = '5001'
$process = Start-Process -FilePath $binary -WorkingDirectory $release -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $release 'stdout.log') -RedirectStandardError (Join-Path $release 'stderr.log')
@{pid = $process.Id; path = $binary} | ConvertTo-Json | Set-Content -LiteralPath $stateFile
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Seconds 1
    $process.Refresh()
    if ($process.HasExited) { throw "Application exited. See $release\stderr.log" }
    try {
        $response = Invoke-WebRequest -Uri 'http://127.0.0.1:5001/' -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200 -and $response.Content -eq 'Hello, CI/CD with Jenkins!') {
            Write-Output 'Deployment verified: HTTP 200 and expected page content at http://127.0.0.1:5001/'
            exit 0
        }
    } catch { }
}
throw "Application health check failed. See $release\stderr.log"
