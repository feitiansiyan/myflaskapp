$ErrorActionPreference = 'Stop'
$deployRoot = Join-Path $PSScriptRoot '..\.deploy'
$deployRoot = [IO.Path]::GetFullPath($deployRoot)
New-Item -ItemType Directory -Path $deployRoot -Force | Out-Null
$stateFile = Join-Path $deployRoot 'process.json'
if (Test-Path -LiteralPath $stateFile) {
    $previous = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    if ($previous.path.StartsWith($deployRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        $oldProcesses = Get-Process -Name 'flask-demo' -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -eq $previous.path }
        foreach ($oldProcess in $oldProcesses) {
            Stop-Process -Id $oldProcess.Id -ErrorAction SilentlyContinue
            Wait-Process -Id $oldProcess.Id -Timeout 15 -ErrorAction SilentlyContinue
        }
    }
}
$busy = Get-NetTCPConnection -LocalPort 5001 -State Listen -ErrorAction SilentlyContinue
if ($busy) { throw 'Port 5001 is occupied. No unrelated process was stopped.' }
$release = Join-Path $deployRoot ('release-' + $env:BUILD_NUMBER + '-' + (Get-Date -Format 'yyyyMMddHHmmss'))
New-Item -ItemType Directory -Path $release -Force | Out-Null
$binary = Join-Path $release 'flask-demo.exe'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\dist\flask-demo.exe') -Destination $binary
# WMI launches independently of Jenkins' console handles so the build can finish.
$startup = New-CimInstance -ClassName Win32_ProcessStartup -ClientOnly -Property @{ShowWindow = [uint16]0}
$launch = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
    CommandLine = ('"' + $binary + '" --port 5001')
    CurrentDirectory = $release
    ProcessStartupInformation = $startup
}
if ($launch.ReturnValue -ne 0) { throw "Could not start application: WMI code $($launch.ReturnValue)" }
$process = Get-Process -Id $launch.ProcessId
@{pid = $process.Id; path = $binary} | ConvertTo-Json | Set-Content -LiteralPath $stateFile
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Seconds 1
    $process.Refresh()
    if ($process.HasExited) { throw "Application exited: $binary" }
    try {
        $response = Invoke-WebRequest -Uri 'http://127.0.0.1:5001/' -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200 -and $response.Content -eq 'Hello, CI/CD with Jenkins!') {
            Write-Output 'Deployment verified: HTTP 200 and expected page content at http://127.0.0.1:5001/'
            exit 0
        }
    } catch { }
}
throw "Application health check failed: $binary"
