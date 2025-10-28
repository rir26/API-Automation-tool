Write-Host "Starting API Test Suite with Swagger Parameter Extraction..." -ForegroundColor Cyan

# Run API calls with Swagger-based parameters
Write-Host "`n1. Executing API calls..." -ForegroundColor Yellow
& ".\callapi.ps1"

Write-Host "`nTest suite completed!" -ForegroundColor Cyan
