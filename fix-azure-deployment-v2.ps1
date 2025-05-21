# Fix Azure Deployment for Ship360 Chat API
# This script fixes the 504 Gateway Timeout error

param (
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "ship360-rg",
    
    [Parameter(Mandatory = $false)]
    [string]$WebAppName = "ship360-chat-api-2505191259"
)

# Clear console
Clear-Host

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

# Step 3: Check and update CORS settings if needed
Write-Host "Updating CORS settings..." -ForegroundColor Yellow
$result = az webapp cors show --name $WebAppName --resource-group $ResourceGroupName 2>&1
if ($LASTEXITCODE -eq 0) {
    # Add allow-all CORS policy
    $result = az webapp cors add --name $WebAppName --resource-group $ResourceGroupName --allowed-origins "*" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ CORS settings updated to allow all origins" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Failed to update CORS settings: $result" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Failed to check current CORS settings: $result" -ForegroundColor Yellow
}

# Step 4: Redeploy the application
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

# Step 5: Restart the web app
Write-Host "Restarting web app..." -ForegroundColor Yellow
$result = az webapp restart --name $WebAppName --resource-group $ResourceGroupName 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to restart web app. Error: $result" -ForegroundColor Red
} else {
    Write-Host "✅ Web app restarted successfully" -ForegroundColor Green
}

# Step 6: Display information about how to check logs
$webAppUrl = "https://$WebAppName.azurewebsites.net"
Write-Host "`nTo check the application logs and diagnose issues, run:" -ForegroundColor Yellow
Write-Host "az webapp log tail --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor White

# Step 7: Check if the application is running
Write-Host "`nWaiting for application to start (this may take a few minutes)..." -ForegroundColor Yellow
$maxRetries = 20  # Increased for more time to start up
$retryCount = 0
$appReady = $false

while (-not $appReady -and $retryCount -lt $maxRetries) {
    $retryCount++
    Write-Host "  Checking application status (attempt $retryCount of $maxRetries)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15  # Wait a bit longer between retries
    
    try {
        # Try the health check endpoint
        try {
            $statusResult = Invoke-RestMethod -Uri "$webAppUrl/" -Method Get -UseBasicParsing -ErrorAction Stop
            if ($statusResult.status -eq "ok") {
                $appReady = $true
                Write-Host "✅ Application is running!" -ForegroundColor Green
                break
            }
        } catch {
            # Try docs endpoint
            try {
                $statusCode = (Invoke-WebRequest -Uri "$webAppUrl/docs" -Method Head -UseBasicParsing -ErrorAction Stop).StatusCode
                if ($statusCode -eq 200) {
                    $appReady = $true
                    Write-Host "✅ Swagger UI is available!" -ForegroundColor Green
                    break
                }
            } catch {
                # Continue to next attempt
            }
        }
    } catch {
        # Just continue to the next attempt
    }
    
    if (-not $appReady -and $retryCount -ge $maxRetries) {
        Write-Host "⚠️ Application status check timed out. It might still be starting up." -ForegroundColor Yellow
        Write-Host "   You can check the logs using the command above for troubleshooting." -ForegroundColor Yellow
    }
}

# Display URLs for the application
Write-Host "`nDeployment fixes complete! Your API should now be available at:" -ForegroundColor Green
Write-Host "$webAppUrl/api/chat/sync" -ForegroundColor Cyan
Write-Host "$webAppUrl/docs" -ForegroundColor Cyan

Write-Host "`nTroubleshooting tips if you're still seeing 504 errors:" -ForegroundColor Yellow
Write-Host "1. Check the logs for errors using: az webapp log tail --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor White
Write-Host "2. Try accessing the app through different endpoints (/docs, /, /api/chat/sync)" -ForegroundColor White
Write-Host "3. The first request after deployment might time out - try refreshing after a minute" -ForegroundColor White
Write-Host "4. Verify dependencies in requirements.txt match what the app needs" -ForegroundColor White
