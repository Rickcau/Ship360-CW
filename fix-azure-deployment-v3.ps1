# Fix Azure Deployment for Ship360 Chat API
# This script fixes container mode and timeout issues

param (
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "ship360-rg",
    
    [Parameter(Mandatory = $false)]
    [string]$WebAppName = "ship360-chat-api-2505191259",

    [Parameter(Mandatory = $false)]
    [string]$PythonVersion = "3.12",
    
    [Parameter(Mandatory = $false)]
    [switch]$RecreateApp = $false
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

# Step 1: Check if the web app is running in container mode and fix it if needed
Write-Host "Checking web app configuration..." -ForegroundColor Yellow

# Get the current configuration
$appConfig = az webapp show --name $WebAppName --resource-group $ResourceGroupName | ConvertFrom-Json

if ($null -eq $appConfig) {
    Write-Host "❌ Web app not found. Please make sure the name is correct." -ForegroundColor Red
    exit 1
}

# Check if the app is running in container mode
$isContainerMode = $appConfig.kind -like "*,container*" -or $appConfig.reserved -eq $true

if ($isContainerMode -and $RecreateApp) {
    Write-Host "App is currently running in container mode. Recreating the app in code mode..." -ForegroundColor Yellow
    
    # Get the current app plan
    $appPlanInfo = az appservice plan show --name $appConfig.appServicePlanId.Split('/')[-1] --resource-group $ResourceGroupName | ConvertFrom-Json
    
    # Delete the current app
    Write-Host "Deleting current web app..." -ForegroundColor Yellow
    az webapp delete --name $WebAppName --resource-group $ResourceGroupName    # Recreate the app in code mode    Write-Host "Recreating web app in code mode..." -ForegroundColor Yellow
    # Pass runtime parameter directly with double quotes to ensure it's passed correctly
    $createResult = az webapp create --name $WebAppName --resource-group $ResourceGroupName `
        --plan $appPlanInfo.name --runtime "PYTHON|$PythonVersion"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to recreate web app. Error: $createResult" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Web app recreated in code mode" -ForegroundColor Green
} elseif ($isContainerMode) {
    Write-Host "⚠️ The web app is running in container mode but -RecreateApp was not specified." -ForegroundColor Yellow
    Write-Host "   To fix this, run the script again with the -RecreateApp parameter." -ForegroundColor Yellow
    Write-Host "   WARNING: This will delete and recreate the app, which will lose all current settings!" -ForegroundColor Red
    
    $confirm = Read-Host "Do you want to continue without fixing the container mode issue? (y/n)"
    if ($confirm -ne 'y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "✅ App is correctly configured for code deployment" -ForegroundColor Green
}

# Step 2: Update the startup.sh file in the app
Write-Host "`nUpdating startup.sh file..." -ForegroundColor Yellow

$startupContent = @'
#!/bin/bash
cd /home/site/wwwroot

# Install dependencies if needed
pip install --no-cache-dir -r requirements.txt

# Export environment variables
export PYTHONPATH=/home/site/wwwroot:$PYTHONPATH

# Start the FastAPI application with Gunicorn
exec gunicorn app.main:app --workers 2 --worker-class uvicorn.workers.UvicornWorker --timeout 600 --bind 0.0.0.0:8000 --access-logfile '-' --error-logfile '-'
'@

# Save the updated startup.sh file
$startupPath = ".\ship360-chat-api\startup.sh"
$startupContent | Out-File -FilePath $startupPath -Encoding utf8 -NoNewline -Force
Write-Host "✅ Updated startup.sh file" -ForegroundColor Green

# Step 3: Update application settings
Write-Host "`nUpdating application settings..." -ForegroundColor Yellow

# Create an array of settings to apply
$appSettings = @(
    "SCM_DO_BUILD_DURING_DEPLOYMENT=true",
    "WEBSITES_PORT=8000",
    "WEBSITE_RUN_FROM_PACKAGE=0",  # Ensure we're not using run-from-package mode
    "ENABLE_ORYX_BUILD=false"      # Disable Oryx build as we're controlling the environment
)

# Set all settings at once
$result = az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings $appSettings 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to set application settings. Error: $result" -ForegroundColor Red
} else {
    Write-Host "✅ Application settings updated" -ForegroundColor Green
}

# Step 4: Set the startup command explicitly
Write-Host "`nSetting startup command..." -ForegroundColor Yellow

# Set the startup command to our startup.sh script
$result = az webapp config set --name $WebAppName --resource-group $ResourceGroupName --startup-file "/home/site/wwwroot/startup.sh" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to set startup command. Error: $result" -ForegroundColor Red
} else {
    Write-Host "✅ Startup command set" -ForegroundColor Green
}

# Step 5: Check and update CORS settings if needed
Write-Host "`nUpdating CORS settings..." -ForegroundColor Yellow
$result = az webapp cors show --name $WebAppName --resource-group $ResourceGroupName 2>&1
if ($LASTEXITCODE -eq 0) {
    # Add allow-all CORS policy
    $corsResult = az webapp cors add --name $WebAppName --resource-group $ResourceGroupName --allowed-origins "*" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ CORS settings updated to allow all origins" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Failed to update CORS settings: $corsResult" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Failed to check current CORS settings: $result" -ForegroundColor Yellow
}

# Step 6: Package application for deployment
Write-Host "`nPackaging application for deployment..." -ForegroundColor Yellow

$workingDir = Get-Location
$zipFile = "ship360-deploy.zip"
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

# Navigate to the application directory
Set-Location -Path ".\ship360-chat-api"

# Create a ZIP archive without using System.IO.Compression to avoid 32-bit issues
try {
    Write-Host "Creating ZIP archive..." -ForegroundColor Yellow
    if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
        # Use PowerShell's Compress-Archive if available
        Compress-Archive -Path * -DestinationPath "$workingDir\$zipFile" -Force
    } else {
        # Fallback to .NET method if needed
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
        [System.IO.Compression.ZipFile]::CreateFromDirectory((Get-Location), "$workingDir\$zipFile", $compressionLevel, $false)
    }
    Write-Host "✅ ZIP archive created" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create ZIP archive: $_" -ForegroundColor Red
    exit 1
} finally {
    # Return to original directory
    Set-Location -Path $workingDir
}

# Step 7: Deploy to Azure using the newer az webapp deploy command
Write-Host "`nDeploying application using modern azure cli command..." -ForegroundColor Yellow
$deploymentStartTime = Get-Date

# Deploy the application
$deployResult = az webapp deploy --name $WebAppName --resource-group $ResourceGroupName --src-path $zipFile --async $false --timeout 1800 2>&1

if ($LASTEXITCODE -ne 0) {
    # If the deployment fails, check if it's due to a timeout but deployment is still in progress
    if ($deployResult -like "*Timeout reached*" -or $deployResult -like "*is still on-going*") {
        $deploymentUrl = ($deployResult | Select-String -Pattern "https://.*\.scm\.azurewebsites\.net/api/deployments/[a-f0-9-]+").Matches.Value
        
        if ($deploymentUrl) {
            Write-Host "⚠️ Deployment is still in progress but the command timed out." -ForegroundColor Yellow
            Write-Host "   You can check deployment status at: $deploymentUrl" -ForegroundColor Cyan
        } else {
            Write-Host "⚠️ Deployment timed out but may still be in progress." -ForegroundColor Yellow
        }
        
        # Get the deployment ID from the URL if available
        $deploymentId = if ($deploymentUrl) {
            $deploymentUrl.Split('/')[-1]
        } else {
            # Try to get the latest deployment ID
            $latestDeployment = az webapp deployment list --name $WebAppName --resource-group $ResourceGroupName --query "[0].id" -o tsv
            $latestDeployment
        }
        
        if ($deploymentId) {
            Write-Host "Continuing to monitor deployment status for ID: $deploymentId" -ForegroundColor Yellow
            
            # Monitor deployment status
            $maxMonitoringMinutes = 30
            $endMonitoringTime = $deploymentStartTime.AddMinutes($maxMonitoringMinutes)
            $deploymentComplete = $false
            
            while (-not $deploymentComplete -and (Get-Date) -lt $endMonitoringTime) {
                Start-Sleep -Seconds 30
                $deploymentStatus = az webapp deployment show --name $WebAppName --resource-group $ResourceGroupName --deployment-id $deploymentId 2>$null
                
                if ($deploymentStatus) {
                    try {
                        $status = $deploymentStatus | ConvertFrom-Json
                        $currentStatus = $status.status
                        $elapsedTime = [math]::Round(((Get-Date) - $deploymentStartTime).TotalMinutes, 1)
                        
                        Write-Host "Current status: $currentStatus (Elapsed: $elapsedTime minutes)" -ForegroundColor Yellow
                        
                        if ($currentStatus -eq "Success") {
                            Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
                            $deploymentComplete = $true
                        }
                        elseif ($currentStatus -eq "Failed") {
                            Write-Host "❌ Deployment failed." -ForegroundColor Red
                            $deploymentComplete = $true
                        }
                    }
                    catch {
                        Write-Host "⚠️ Unable to parse deployment status." -ForegroundColor Yellow
                    }
                }
            }
            
            if (-not $deploymentComplete) {
                Write-Host "⚠️ Monitoring timed out after $maxMonitoringMinutes minutes." -ForegroundColor Yellow
                Write-Host "   The deployment might still be in progress." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "❌ Deployment failed. Error: $deployResult" -ForegroundColor Red
        # Clean up
        if (Test-Path $zipFile) {
            Remove-Item $zipFile -Force
        }
        exit 1
    }
} else {
    Write-Host "✅ Application deployed successfully" -ForegroundColor Green
}

# Clean up
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

# Step 8: Restart the web app
Write-Host "`nRestarting web app..." -ForegroundColor Yellow
$result = az webapp restart --name $WebAppName --resource-group $ResourceGroupName 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Failed to restart web app. Error: $result" -ForegroundColor Yellow
} else {
    Write-Host "✅ Web app restarted successfully" -ForegroundColor Green
}

# Display URLs and set up monitoring
$webAppUrl = "https://$WebAppName.azurewebsites.net"

# Step 9: Display information about how to check logs
Write-Host "`nTo check the application logs and diagnose issues, run:" -ForegroundColor Yellow
Write-Host "az webapp log tail --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor White
Write-Host "  - or visit -" -ForegroundColor Yellow 
Write-Host "https://$WebAppName.scm.azurewebsites.net/api/logstream" -ForegroundColor White

# Step 10: Check if the application is running
Write-Host "`nWaiting for application to start (this may take a few minutes)..." -ForegroundColor Yellow
$maxRetries = 30  # Increased for more time to start up (30 * 15 = 7.5 minutes)
$retryCount = 0
$appReady = $false

while (-not $appReady -and $retryCount -lt $maxRetries) {
    $retryCount++
    $elapsedMinutes = [math]::Round($retryCount * 15 / 60, 1)
    Write-Host "  Checking application status (attempt $retryCount of $maxRetries, elapsed: $elapsedMinutes min)..." -ForegroundColor Yellow
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
                # Try a basic request
                try {
                    $response = Invoke-WebRequest -Uri "$webAppUrl" -Method Get -UseBasicParsing -ErrorAction Stop
                    $statusCode = $response.StatusCode
                    
                    # Any successful status code (200-299)
                    if ($statusCode -ge 200 -and $statusCode -lt 300) {
                        $appReady = $true
                        Write-Host "✅ Web app is responding with status code $statusCode!" -ForegroundColor Green
                        break
                    }
                } catch {
                    # Continue to next attempt
                }
            }
        }
    } catch {
        # Just continue to the next attempt
    }
    
    if (-not $appReady -and $retryCount -ge $maxRetries) {
        Write-Host "⚠️ Application status check timed out. It might still be starting up." -ForegroundColor Yellow
        Write-Host "   Check the logs using the command above for troubleshooting." -ForegroundColor Yellow
    }
}

# Display URLs for the application
Write-Host "`nDeployment complete! Your API should now be available at:" -ForegroundColor Green
Write-Host "$webAppUrl/api/chat/sync" -ForegroundColor Cyan
Write-Host "$webAppUrl/docs" -ForegroundColor Cyan

Write-Host "`nApplication details:" -ForegroundColor Yellow
Write-Host "- Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "- Web App Name: $WebAppName" -ForegroundColor White
Write-Host "- Log Stream: https://$WebAppName.scm.azurewebsites.net/api/logstream" -ForegroundColor White

Write-Host "`nTroubleshooting tips if you're still seeing issues:" -ForegroundColor Yellow
Write-Host "1. Check the logs for errors: az webapp log tail --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor White
Write-Host "2. Access the Kudu console for advanced debugging: https://$WebAppName.scm.azurewebsites.net/" -ForegroundColor White
Write-Host "3. Try accessing different endpoints (/docs, /, /api/chat/sync)" -ForegroundColor White
Write-Host "4. The first request after deployment might still be slow - give it time" -ForegroundColor White
