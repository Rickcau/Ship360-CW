# Fix Azure Deployment for Ship360 Chat API
# This script fixes the 504 Gateway Timeout error

param (
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "ship360-rg",
    
    [Parameter(Mandatory = $false)]
    [string]$WebAppName = "ship360-chat-api-2505191259"
)

# Check if Azure CLI is installed
$azureCliVersion = az --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Azure CLI is not installed. Please install it first." -ForegroundColor Red
    exit 1
}

# Check if logged in to Azure
$account = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "You are not logged in to Azure. Logging in now..." -ForegroundColor Yellow
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to log in to Azure. Please try again." -ForegroundColor Red
        exit 1
    }
} else {
    $accountJson = $account | ConvertFrom-Json
    Write-Host "✅ Logged in to Azure as $($accountJson.user.name)" -ForegroundColor Green
}

# Step 1: Update the startup.sh file in the app
Write-Host "Updating startup.sh file..." -ForegroundColor Yellow

$startupContent = @'
#!/bin/bash
cd /home/site/wwwroot

# Install dependencies if needed
pip install -r requirements.txt

# Export environment variables
export PYTHONPATH=/home/site/wwwroot:$PYTHONPATH

# Start the FastAPI application with Gunicorn
gunicorn app.main:app --workers 2 --worker-class uvicorn.workers.UvicornWorker --timeout 600 --bind 0.0.0.0:8000 --access-logfile '-' --error-logfile '-'
'@

# Save the updated startup.sh file
$startupPath = ".\ship360-chat-api\startup.sh"
$startupContent | Out-File -FilePath $startupPath -Encoding utf8 -NoNewline -Force
Write-Host "✅ Updated startup.sh file" -ForegroundColor Green

# Step 2: Update application settings
Write-Host "Updating application settings..." -ForegroundColor Yellow

# Set SCM_DO_BUILD_DURING_DEPLOYMENT to ensure proper build during deployment
$result = az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to set SCM_DO_BUILD_DURING_DEPLOYMENT. Error: $result" -ForegroundColor Red
} else {
    Write-Host "✅ Set SCM_DO_BUILD_DURING_DEPLOYMENT=true" -ForegroundColor Green
}

# Set WEBSITES_PORT to ensure the app listens on the correct port
$result = az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings WEBSITES_PORT=8000 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to set WEBSITES_PORT. Error: $result" -ForegroundColor Red
} else {
    Write-Host "✅ Set WEBSITES_PORT=8000" -ForegroundColor Green
}

# Step 3: Redeploy the application
Write-Host "Packaging application for redeployment..." -ForegroundColor Yellow

$workingDir = Get-Location
$zipFile = "ship360-deploy.zip"
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

# Navigate to the application directory and create a zip file
Set-Location -Path ".\ship360-chat-api"

# Use PowerShell to create a ZIP archive
Add-Type -AssemblyName System.IO.Compression.FileSystem
$compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
[System.IO.Compression.ZipFile]::CreateFromDirectory((Get-Location), "$workingDir\$zipFile", $compressionLevel, $false)

# Return to original directory
Set-Location -Path $workingDir

# Deploy the zip file to Azure
Write-Host "Deploying application to Azure..." -ForegroundColor Yellow
$result = az webapp deployment source config-zip --name $WebAppName --resource-group $ResourceGroupName --src $zipFile 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to deploy application. Error: $result" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ Application deployed successfully" -ForegroundColor Green
}

# Clean up
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

# Step 4: Restart the web app
Write-Host "Restarting web app..." -ForegroundColor Yellow
$result = az webapp restart --name $WebAppName --resource-group $ResourceGroupName 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to restart web app. Error: $result" -ForegroundColor Red
} else {
    Write-Host "✅ Web app restarted successfully" -ForegroundColor Green
}

# Step 5: Check if the application is running
Write-Host "Waiting for application to start..." -ForegroundColor Yellow
$webAppUrl = "https://$WebAppName.azurewebsites.net"
$maxRetries = 12
$retryCount = 0
$appReady = $false

while (-not $appReady -and $retryCount -lt $maxRetries) {
    $retryCount++
    Write-Host "  Checking application status (attempt $retryCount of $maxRetries)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    try {
        # First try the health check endpoint
        try {
            $statusResult = Invoke-RestMethod -Uri "$webAppUrl/" -Method Get -UseBasicParsing -ErrorAction Stop
            if ($statusResult.status -eq "ok") {
                $appReady = $true
                Write-Host "✅ Application is running!" -ForegroundColor Green
                break
            }
        } catch {
            # If health check fails, try the docs endpoint
            $statusResult = Invoke-RestMethod -Uri "$webAppUrl/docs" -Method Head -UseBasicParsing -ErrorAction Stop
            $appReady = $true
            Write-Host "✅ Application is running!" -ForegroundColor Green
            break
        }
    } catch {
        if ($retryCount -ge $maxRetries) {
            Write-Host "⚠️ Application may not be fully started yet." -ForegroundColor Yellow
        } else {
            Write-Host "  Application not ready yet, waiting..." -ForegroundColor Yellow
        }
    }
}

# Display URLs for the application
Write-Host "`nDeployment fixes complete! Your API should now be available at:" -ForegroundColor Green
Write-Host "$webAppUrl/api/chat/sync" -ForegroundColor Cyan
Write-Host "$webAppUrl/docs" -ForegroundColor Cyan

Write-Host "`nTo check logs, run:" -ForegroundColor Yellow
Write-Host "az webapp log tail --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor White
