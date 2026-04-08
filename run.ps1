Write-Host "Starting the backend..." -ForegroundColor Green
Start-Process powershell -WorkingDirectory "$PSScriptRoot" -ArgumentList "-NoExit", "-Command", "npm run dev"

Write-Host "Starting the frontend..." -ForegroundColor Green
Start-Process powershell -WorkingDirectory "$PSScriptRoot\frontend" -ArgumentList "-NoExit", "-Command", "flutter run -d chrome --web-port 5500"

Write-Host "Both processes have been started in new windows!" -ForegroundColor Cyan
