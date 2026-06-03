$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Split-Path -Parent $scriptDir
$serverPath = Join-Path $root "server"
$clientPath = Join-Path $root "client"

Start-Process -FilePath "powershell" -ArgumentList "-NoExit","-Command","cd '$serverPath'; npm run dev"
Start-Process -FilePath "powershell" -ArgumentList "-NoExit","-Command","cd '$clientPath'; npm run dev"

Write-Host "Frontend available at http://localhost:5173"
Start-Sleep -Seconds 2
Start-Process "http://localhost:5173"
