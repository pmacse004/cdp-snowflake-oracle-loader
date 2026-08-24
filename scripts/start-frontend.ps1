# =============================================================================
# start-frontend.ps1 — Start the CDP Loader React dashboard
# =============================================================================
Set-StrictMode -Version Latest

$frontendDir = "cdp-loader-ui"

if (-not (Test-Path $frontendDir)) {
    Write-Error "Frontend directory '$frontendDir' not found."
    exit 1
}

Set-Location $frontendDir

if (-not (Test-Path "node_modules")) {
    Write-Host "Installing npm dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) { Write-Error "npm install failed"; exit 1 }
}

# Create .env if not present
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host ".env created from .env.example (VITE_API_BASE_URL=http://localhost:8080)" -ForegroundColor Green
}

Write-Host "Starting React dashboard on http://localhost:5173" -ForegroundColor Cyan
Write-Host "Ensure backend is running on port 8080." -ForegroundColor Yellow
Write-Host ""
npm run dev
