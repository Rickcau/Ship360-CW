# Ship360-CW Chat API Deployment to Azure
# This script automates the deployment of the Ship360-CW Chat API to Azure App Service
# It includes container mode detection and fixes, improved startup configuration, and robust error handling

# Parameters
param (
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "ship360-rg",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "centralus",
    
    [Parameter(Mandatory = $false)]
    [string]$AppServicePlanName = "ship360-plan",
    
    [Parameter(Mandatory = $false)]
    [string]$WebAppName = "ship360-chat-api-$((Get-Date).ToString('yyMMddHHmm'))",
    
    [Parameter(Mandatory = $false)]
    [string]$PythonVersion = "3.12",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseFreeAppServicePlan = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$CleanupOnError = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$RecreateApp = $false
)

# Clear console
Clear-Host

# Function to check if Azure CLI is installed
function Test-AzureCLI {
    $azureCliVersion = az --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Azure CLI is not installed. Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Azure CLI is installed" -ForegroundColor Green
}

# Function to check if user is logged in to Azure
function Test-AzureLogin {
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
}

# Function to prepare requirements.txt
function Update-RequirementsFile {
    param (
        [string]$ReqFilePath
    )
    
    Write-Host "Updating requirements.txt to prevent aiohttp build failures..." -ForegroundColor Yellow
    
    if (Test-Path $ReqFilePath) {
        $content = Get-Content -Path $ReqFilePath -Raw
        
        # Check if aiohttp is in the requirements
        if ($content -match "aiohttp[=><]") {
            Write-Host "  ℹ️ Found aiohttp dependency in requirements.txt" -ForegroundColor Cyan
            
            # Back up original file
            $backupPath = "$ReqFilePath.bak"
            Copy-Item -Path $ReqFilePath -Destination $backupPath -Force
            Write-Host "  ℹ️ Backed up original requirements.txt to $backupPath" -ForegroundColor Cyan
            
            # Update to use precompiled wheels for aiohttp
            $newContent = $content -replace "aiohttp[=><][^;\r\n]*", "aiohttp==3.8.5; platform_machine!=""x86_64"" and platform_machine!=""amd64""`naiohttp==3.8.5; platform_machine==""x86_64"" or platform_machine==""amd64"" --only-binary=aiohttp"
            
            # Replace multiprocessing.pool with --only-binary flag for other problematic packages
            $newContent = $newContent -replace "multiprocessing.pool[=><][^;\r\n]*", "multiprocessing.pool; --only-binary=:all:"
            
            # Add pip upgrade at the beginning
            $newContent = "--upgrade pip`n$newContent"
            
            # Write updated content
            Set-Content -Path $ReqFilePath -Value $newContent
            Write-Host "  ✅ Updated requirements.txt with optimized package specifications" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ℹ️ No aiohttp dependency found in requirements.txt" -ForegroundColor Cyan
            return $false
        }
    } else {
        Write-Warning "requirements.txt not found at $ReqFilePath"
        return $false
    }
}

# Function to create startup.sh file
function Update-StartupFile {
    $startupPath = ".\ship360-chat-api\startup.sh"
    
    # Always update the startup file with latest configuration
    Write-Host "Creating/Updating startup.sh file..." -ForegroundColor Yellow
    $startupContent = @'
#!/bin/bash
cd /home/site/wwwroot

# Echo progress for better logging
echo "Starting deployment process from startup.sh"

# Create a log file
exec > >(tee -a /home/LogFiles/startup.log) 2>&1
echo "$(date): Starting application deployment"

# Wait for any previous processes to finish
echo "Waiting for any package operations to finish..."
for i in {1..30}; do
    if ps aux | grep -q "[p]ip install"; then
        echo "Package installation is still running... waiting (attempt $i of 30)"
        sleep 10
    else
        break
    fi
done

# Install dependencies
echo "Installing dependencies from requirements.txt..."
pip install --no-cache-dir -r requirements.txt

# Export environment variables
echo "Setting up environment variables..."
export PYTHONPATH=/home/site/wwwroot:$PYTHONPATH

# Start the FastAPI application with Gunicorn
echo "Starting FastAPI application with Gunicorn..."
exec gunicorn app.main:app --workers 2 --worker-class uvicorn.workers.UvicornWorker --timeout 600 --bind 0.0.0.0:8000 --access-logfile '-' --error-logfile '-'
'@ 
    
    # Save the updated startup.sh file - make sure to use UTF8 without BOM
    # and make sure line endings are LF not CRLF for Linux compatibility
    $startupContent = $startupContent.Replace("`r`n", "`n")
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($startupPath, $startupContent, $utf8NoBom)
    
    Write-Host "✅ Updated startup.sh file" -ForegroundColor Green
}

# Function to create Azure resources
function New-AzureResources {
    # Check if resource group exists
    $resourceGroupExists = az group exists --name $ResourceGroupName
    if ($resourceGroupExists -eq "false") {
        Write-Host "Creating resource group $ResourceGroupName in $Location..." -ForegroundColor Yellow
        az group create --name $ResourceGroupName --location $Location
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to create resource group. Please check your permissions and try again." -ForegroundColor Red
            exit 1
        }
        $script:resourceGroupCreatedInThisRun = $true
        Write-Host "✅ Resource group created" -ForegroundColor Green
    } else {
        Write-Host "✅ Resource group $ResourceGroupName already exists" -ForegroundColor Green
        $script:resourceGroupCreatedInThisRun = $false
    }
    
    # Check if App Service Plan exists
    $appServicePlanExists = az appservice plan list --resource-group $ResourceGroupName --query "[?name=='$AppServicePlanName']" --output tsv
    if (-not $appServicePlanExists) {
        Write-Host "Creating App Service Plan $AppServicePlanName..." -ForegroundColor Yellow
        
        # Try to create the App Service Plan
        $appServicePlanCreated = $false
        $attempts = 0
        $maxAttempts = 2
        
        while (-not $appServicePlanCreated -and $attempts -lt $maxAttempts) {
            $attempts++
            
            # First try with F1 (Free tier) if UseFreeAppServicePlan is true
            if ($UseFreeAppServicePlan) {
                Write-Host "Attempting to create Free tier (F1) App Service Plan..." -ForegroundColor Yellow
                $result = az appservice plan create --name $AppServicePlanName --resource-group $ResourceGroupName --sku F1 --is-linux 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $appServicePlanCreated = $true
                    Write-Host "✅ Free tier (F1) App Service Plan created" -ForegroundColor Green
                } else {
                    Write-Host "❌ Failed to create Free tier App Service Plan. Error: $result" -ForegroundColor Red                    # If Free tier failed and we've tried both options, cleanup and exit
                    if ($attempts -ge $maxAttempts) {
                        Write-Host "❌ Could not create App Service Plan. You may need to request a quota increase: https://aka.ms/antquotahelp" -ForegroundColor Red
                        Remove-DeploymentResources "Could not create App Service Plan: $result"
                        return
                    }
                    # Otherwise try Basic tier (B1)
                    $UseFreeAppServicePlan = $false
                }
            } else {
                Write-Host "Attempting to create Basic tier (B1) App Service Plan..." -ForegroundColor Yellow
                $result = az appservice plan create --name $AppServicePlanName --resource-group $ResourceGroupName --sku B1 --is-linux 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $appServicePlanCreated = $true
                    Write-Host "✅ Basic tier (B1) App Service Plan created" -ForegroundColor Green
                } else {
                    Write-Host "❌ Failed to create Basic tier App Service Plan. Error: $result" -ForegroundColor Red
                    
                    # If the error is due to quota limitations, suggest requesting a quota increase
                    if ($result -match "without additional quota") {
                        Write-Host "You've hit a quota limit for Basic tier VMs in $Location." -ForegroundColor Red
                        Write-Host "Options:" -ForegroundColor Yellow
                        Write-Host "1. Request a quota increase: https://aka.ms/antquotahelp" -ForegroundColor Yellow
                        Write-Host "2. Try a different region by running the script with -Location parameter" -ForegroundColor Yellow
                        Write-Host "3. Try using the Free tier by running the script with -UseFreeAppServicePlan" -ForegroundColor Yellow
                        
                        # If this is the first attempt, try using Free tier instead
                        if ($attempts -lt $maxAttempts) {
                            $UseFreeAppServicePlan = $true
                            Write-Host "Trying Free tier (F1) instead..." -ForegroundColor Yellow
                        } else {
                            Write-Host "❌ Deployment failed due to quota limitations." -ForegroundColor Red
                            exit 1
                        }
                    } else {                        Write-Host "❌ App Service Plan creation failed. Please check the error message above." -ForegroundColor Red
                        exit 1
                    }
                }
            }
        }
    } else {
        Write-Host "✅ App Service Plan $AppServicePlanName already exists" -ForegroundColor Green
    }
    
    # Check if Web App exists    $webAppExists = az webapp list --resource-group $ResourceGroupName --query "[?name=='$WebAppName']" --output tsv
    if (-not $webAppExists) {        Write-Host "Creating Web App $WebAppName..." -ForegroundColor Yellow
        # Explicitly set runtime to ensure code mode, not container mode
        # Use correct runtime format with colon separator (PYTHON:3.12)
        $result = az webapp create --name $WebAppName --resource-group $ResourceGroupName --plan $AppServicePlanName --runtime "PYTHON:$PythonVersion" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to create Web App. Error: $result" -ForegroundColor Red
            Remove-DeploymentResources "Failed to create Web App. Error: $result"
            return
        }
        Write-Host "✅ Web App created in code mode" -ForegroundColor Green
        
        # Wait for the web app to be fully provisioned before trying to configure it
        $webAppReady = Wait-WebAppProvisioning -WebAppName $WebAppName -ResourceGroupName $ResourceGroupName
        if (-not $webAppReady) {
            Write-Host "⚠️ Warning: Web app may not be fully ready for configuration, but continuing anyway..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "✅ Web App $WebAppName already exists" -ForegroundColor Green
        
        # Check if app is in container mode and fix it if needed
        $appConfig = az webapp show --name $WebAppName --resource-group $ResourceGroupName | ConvertFrom-Json
        $isContainerMode = $appConfig.kind -like "*,container*" -or $appConfig.reserved -eq $true
        if ($isContainerMode -and $RecreateApp) {
            Write-Host "App is currently running in container mode. Recreating the app in code mode..." -ForegroundColor Yellow
            
            # Get the current app plan
            $appPlanInfo = az appservice plan show --name $appConfig.appServicePlanId.Split('/')[-1] --resource-group $ResourceGroupName | ConvertFrom-Json
            
            # Delete the current app
            Write-Host "Deleting current web app..." -ForegroundColor Yellow
            az webapp delete --name $WebAppName --resource-group $ResourceGroupName
            
            # Recreate the app in code mode
            Write-Host "Recreating web app in code mode..." -ForegroundColor Yellow            # Use consistent format for runtime parameter like the original app
            $createResult = az webapp create --name $WebAppName --resource-group $ResourceGroupName `
                --plan $appPlanInfo.name --runtime "PYTHON:$PythonVersion"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "❌ Failed to recreate web app. Error: $createResult" -ForegroundColor Red
                Remove-DeploymentResources "Failed to recreate web app. Error: $createResult"
                return
            }
            Write-Host "✅ Web app recreated in code mode" -ForegroundColor Green
            
            # Wait for the web app to be fully provisioned before trying to configure it
            $webAppReady = Wait-WebAppProvisioning -WebAppName $WebAppName -ResourceGroupName $ResourceGroupName
            if (-not $webAppReady) {
                Write-Host "⚠️ Warning: Web app may not be fully ready for configuration, but continuing anyway..." -ForegroundColor Yellow
            }
        } elseif ($isContainerMode) {
            Write-Host "⚠️ The web app is running in container mode but -RecreateApp was not specified." -ForegroundColor Yellow
            Write-Host "   To fix this, run the script again with the -RecreateApp parameter." -ForegroundColor Yellow
            Write-Host "   WARNING: This will delete and recreate the app, which will lose all current settings!" -ForegroundColor Red
            
            $confirm = Read-Host "Do you want to continue without fixing the container mode issue? (y/n)"
            if ($confirm -ne 'y') {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    }
    
    # Configure Web App settings
    Write-Host "Configuring web app settings..." -ForegroundColor Yellow
      # Configure startup file
    $result = az webapp config set --name $WebAppName --resource-group $ResourceGroupName --startup-file "/home/site/wwwroot/startup.sh" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to configure startup file. Error: $result" -ForegroundColor Red
        Remove-DeploymentResources "Failed to configure startup file. Error: $result"
        return
    }
    Write-Host "✅ Startup file configured" -ForegroundColor Green
      # Configure application settings
    Write-Host "Configuring application settings..." -ForegroundColor Yellow
    
    # Create an array of settings to apply
    $appSettings = @(
        "SCM_DO_BUILD_DURING_DEPLOYMENT=true",
        "WEBSITES_PORT=8000",
        "WEBSITE_RUN_FROM_PACKAGE=0",  # Ensure we're not using run-from-package mode
        "ENABLE_ORYX_BUILD=true",      # Enable Oryx build to handle Python dependency issues
        "PYTHON_ENABLE_GUNICORN_MULTIWORKERS=1", # Enable multiple gunicorn workers
        "DOCKER_ENABLE_CI=false",      # Disable container features
        "DOCKER_REGISTRY_SERVER_URL=",  # Clear any container registry settings
        "WEBSITE_WEBDEPLOY_USE_SCM=false" # Use direct deployment
    )
      # Set all settings at once
    $result = az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings $appSettings 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to set application settings. Error: $result" -ForegroundColor Red
        Remove-DeploymentResources "Failed to set application settings. Error: $result"
        return
    } else {
        Write-Host "✅ Application settings configured" -ForegroundColor Green
    }
      # Check and update CORS settings
    Write-Host "Updating CORS settings..." -ForegroundColor Yellow
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
}

# Function to set environment variables from .env file
function Set-EnvironmentVariables {
    Write-Host "Setting environment variables..." -ForegroundColor Yellow
    
    $envFilePath = ".\ship360-chat-api\.env"
    if (-not (Test-Path $envFilePath)) {
        $envFilePath = ".\.env"
        if (-not (Test-Path $envFilePath)) {
            Write-Host "Warning: .env file not found. Environment variables will not be set." -ForegroundColor Yellow
            return
        }
    }
    
    $envVars = Get-Content $envFilePath | Where-Object { $_ -match "^[^#].*=.*" } | ForEach-Object {
        $parts = $_ -split "=", 2
        $key = $parts[0].Trim()
        $value = $parts[1].Trim('"', "'", ' ')
        "$key=$value"
    }
    
    if ($envVars.Count -gt 0) {        # Check if the web app exists before trying to set environment variables
        $webAppExists = az webapp list --resource-group $ResourceGroupName --query "[?name=='$WebAppName']" --output tsv
        if (-not $webAppExists) {
            Write-Host "❌ Cannot set environment variables - Web App $WebAppName not found" -ForegroundColor Red
            return
        }
        
        # Set environment variables
        $result = az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings $envVars 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to set environment variables. Error: $result" -ForegroundColor Red
            return
        }
        Write-Host "✅ Environment variables set" -ForegroundColor Green
    } else {
        Write-Host "Warning: No environment variables found in .env file" -ForegroundColor Yellow
    }
}

# Function to deploy application
function Publish-Application {
    Write-Host "Packaging application for deployment..." -ForegroundColor Yellow
    
    $workingDir = Get-Location
    $deploymentStartTime = Get-Date
    
    # Create a temporary deployment zip file
    $zipFile = "ship360-deploy.zip"
    if (Test-Path $zipFile) {
        Remove-Item $zipFile -Force
    }
    
    # Navigate to the application directory and create a zip file
    Set-Location -Path ".\ship360-chat-api"        # Create a ZIP archive without using System.IO.Compression to avoid 32-bit issues
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
        Set-Location -Path $workingDir  # Return to original directory before cleanup
        Remove-DeploymentResources "Failed to create ZIP archive: $_"
        return
    } finally {
        # Return to original directory
        Set-Location -Path $workingDir
    }
    
    # Deploy the zip file to Azure using the newer command
    Write-Host "Deploying application to Azure..." -ForegroundColor Yellow
    # Increased timeout to 3600 seconds (1 hour) to allow for dependency installation
    $deployResult = az webapp deploy --name $WebAppName --resource-group $ResourceGroupName --src-path $zipFile --async $false --timeout 3600 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        # If the deployment fails, check if it's due to a timeout but deployment is still in progress
        if ($deployResult -like "*Timeout reached*" -or $deployResult -like "*is still on-going*" -or $deployResult -like "*timed out*") {
            $deploymentUrl = ($deployResult | Select-String -Pattern "https://.*\.scm\.azurewebsites\.net/api/deployments/[a-f0-9-]+").Matches.Value
            
            if ($deploymentUrl) {
                Write-Host "⚠️ Deployment is still in progress but the command timed out." -ForegroundColor Yellow
                Write-Host "   You can check deployment status at: $deploymentUrl" -ForegroundColor Cyan
            } else {
                Write-Host "⚠️ Deployment timed out but may still be in progress." -ForegroundColor Yellow
                Write-Host "   This is normal for apps with many dependencies to install." -ForegroundColor Yellow
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
                
                # Monitor deployment status - increased max monitoring time
                $maxMonitoringMinutes = 45  # Increased from 30 minutes
                $endMonitoringTime = $deploymentStartTime.AddMinutes($maxMonitoringMinutes)
                $deploymentComplete = $false
                $lastLogCheck = Get-Date
                
                while (-not $deploymentComplete -and (Get-Date) -lt $endMonitoringTime) {
                    # Every 2 minutes, also check the logs to see if pip install is running
                    if ((Get-Date).Subtract($lastLogCheck).TotalMinutes -ge 2) {
                        $lastLogCheck = Get-Date
                        Write-Host "  Checking application logs..." -ForegroundColor Yellow
                        $logs = az webapp log tail --name $WebAppName --resource-group $ResourceGroupName --filter Error Warning Info --limit 10 2>&1
                          if ($logs -like "*pip install*" -or $logs -like "*Installing collected packages*") {
                            Write-Host "  📦 Python package installation in progress. This may take several minutes..." -ForegroundColor Cyan
                        }
                        
                        if ($logs -like "*Failed building wheel for aiohttp*" -or $logs -like "*Failed to build aiohttp*") {
                            Write-Host "  ⚠️ Issues detected building aiohttp. Will try to fix in post-deployment." -ForegroundColor Yellow
                        }
                        
                        if ($logs -like "*gunicorn*" -or $logs -like "*Starting FastAPI*") {
                            Write-Host "  🚀 Application startup detected!" -ForegroundColor Green
                        }
                        
                        if ($logs -like "*Initiating warmup request*" -and $logs -like "*Container*") {
                            Write-Host "  ⚠️ Container mode detected! The app may be running incorrectly." -ForegroundColor Red
                            Write-Host "     Will attempt to fix in post-deployment step." -ForegroundColor Yellow
                        }
                    }
                    
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
                                # Check if it's a false failure due to package installation timeouts
                                $logs = az webapp log tail --name $WebAppName --resource-group $ResourceGroupName --filter Error Warning Info --limit 50 2>&1
                                
                                if ($logs -like "*pip install*" -or $logs -like "*Installing collected packages*" -or $logs -like "*startup.sh*") {
                                    Write-Host "⚠️ Deployment marked as failed, but Python packages are still installing." -ForegroundColor Yellow
                                    Write-Host "   This is often a false negative. Will continue monitoring." -ForegroundColor Yellow
                                    Start-Sleep -Seconds 60  # Give more time for installation
                                } else {
                                    Write-Host "❌ Deployment failed." -ForegroundColor Red
                                    $deploymentComplete = $true
                                    
                                    # Check if it failed for a known reason that we can fix
                                    if ($logs -like "*Failed building wheel*" -or $logs -like "*Container*" -or $logs -like "*startup.sh*") {
                                        Write-Host "   Detected common issues that can be fixed in post-deployment." -ForegroundColor Yellow
                                    } else {
                                        Remove-DeploymentResources "Deployment failed"
                                        exit 1
                                    }
                                }
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
                    
                    # Check if pip install is still running
                    $logs = az webapp log tail --name $WebAppName --resource-group $ResourceGroupName --filter Error Warning Info --limit 20 2>&1
                    
                    if ($logs -like "*pip install*" -or $logs -like "*Installing collected packages*" -or $logs -like "*startup.sh*") {
                        Write-Host "⚠️ Detected that Python packages are still being installed." -ForegroundColor Yellow
                        Write-Host "   Continuing to post-deployment steps." -ForegroundColor Yellow
                        $skipCleanup = $true
                    }
                }
            } else {
                Write-Host "❌ Deployment failed. Error: $deployResult" -ForegroundColor Red
                Remove-DeploymentResources "Deployment failed. Error: $deployResult"
                return
            }
        }
    }
}

# Function to clean up resources on error
function Remove-DeploymentResources {
    param (
        [string]$Message = "An error occurred during deployment.",
        [switch]$ForceCleanup = $false
    )
    
    Write-Host "`n$Message" -ForegroundColor Red
    
    # Check if the error is likely due to packages still installing
    $skipCleanup = $false
    if (-not $ForceCleanup) {
        $logs = az webapp log tail --name $WebAppName --resource-group $ResourceGroupName --filter Error Warning Info --limit 50 2>&1
        if ($logs -like "*pip install*" -or $logs -like "*Installing collected packages*" -or $logs -like "*startup.sh*") {
            Write-Host "⚠️ Detected that Python packages are still being installed." -ForegroundColor Yellow
            Write-Host "   Skipping resource cleanup as the app may still be initializing." -ForegroundColor Yellow
            $skipCleanup = $true
        }
    }
    
    if ($CleanupOnError -and -not $skipCleanup) {
        Write-Host "Cleaning up resources..." -ForegroundColor Yellow
        
        try {
            # Ask for confirmation before cleaning up
            $confirmation = Read-Host "Are you sure you want to delete the web app resources? Dependencies may still be installing. (Y/N)"
            if ($confirmation -ne "Y" -and $confirmation -ne "y") {
                Write-Host "Cleanup aborted. Resources will remain." -ForegroundColor Cyan
                return
            }
            
            # Check if Web App exists and delete it
            $webAppExists = az webapp list --resource-group $ResourceGroupName --query "[?name=='$WebAppName']" --output tsv
            if ($webAppExists) {
                Write-Host "Deleting Web App $WebAppName..." -ForegroundColor Yellow
                az webapp delete --name $WebAppName --resource-group $ResourceGroupName
                Write-Host "Web App deleted" -ForegroundColor Green
            }
            
            # Check if App Service Plan exists and delete it
            $appServicePlanExists = az appservice plan list --resource-group $ResourceGroupName --query "[?name=='$AppServicePlanName']" --output tsv
            if ($appServicePlanExists) {
                Write-Host "Deleting App Service Plan $AppServicePlanName..." -ForegroundColor Yellow
                az appservice plan delete --name $AppServicePlanName --resource-group $ResourceGroupName --yes
                Write-Host "App Service Plan deleted" -ForegroundColor Green
            }
            
            # Delete resource group only if we created it in this run
            if ($script:resourceGroupCreatedInThisRun) {
                Write-Host "Deleting Resource Group $ResourceGroupName..." -ForegroundColor Yellow
                az group delete --name $ResourceGroupName --yes --no-wait
                Write-Host "Resource Group deletion initiated" -ForegroundColor Green
            }
            
            Write-Host "Cleanup completed" -ForegroundColor Green
        }
        catch {
            Write-Host "Error during cleanup: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Resources were not cleaned up. You may need to manually delete them." -ForegroundColor Yellow
    }
    
    exit 1
}

# Function to reset container mode if needed
function Reset-ContainerMode {
    param (
        [string]$WebAppName,
        [string]$ResourceGroupName,
        [string]$PythonVersion
    )
    
    # Check if the web app is in container mode
    $appConfig = az webapp show --name $WebAppName --resource-group $ResourceGroupName | ConvertFrom-Json
    $isContainerMode = $appConfig.kind -like "*,container*" -or $appConfig.reserved -eq $true
    
    if ($isContainerMode) {
        Write-Host "Web App $WebAppName is in container mode. Resetting to code mode..." -ForegroundColor Yellow
        
        # Get the current app plan
        $appPlanInfo = az appservice plan show --name $appConfig.appServicePlanId.Split('/')[-1] --resource-group $ResourceGroupName | ConvertFrom-Json
        
        # Delete the current app
        Write-Host "Deleting current web app..." -ForegroundColor Yellow
        az webapp delete --name $WebAppName --resource-group $ResourceGroupName
        
        # Recreate the app in code mode
        Write-Host "Recreating web app in code mode..." -ForegroundColor Yellow        # Use consistent format for runtime parameter like the original app
        $createResult = az webapp create --name $WebAppName --resource-group $ResourceGroupName `
            --plan $appPlanInfo.name --runtime "PYTHON:$PythonVersion"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to recreate web app. Error: $createResult" -ForegroundColor Red
            Remove-DeploymentResources "Failed to recreate web app. Error: $createResult"
            return
        }
        Write-Host "✅ Web app recreated in code mode" -ForegroundColor Green
        
        # Wait for the web app to be fully provisioned before trying to configure it
        $webAppReady = Wait-WebAppProvisioning -WebAppName $WebAppName -ResourceGroupName $ResourceGroupName
        if (-not $webAppReady) {
            Write-Host "⚠️ Warning: Web app may not be fully ready for configuration, but continuing anyway..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Web App $WebAppName is already in code mode" -ForegroundColor Green
    }
}

# Function to set startup script configuration
function Set-StartupScriptConfig {
    param (
        [string]$WebAppName,
        [string]$ResourceGroupName
    )
    
    Write-Host "Setting startup script configuration..." -ForegroundColor Yellow
    
    # Ensure the startup file is correctly configured
    $result = az webapp config set --name $WebAppName --resource-group $ResourceGroupName --startup-file "/home/site/wwwroot/startup.sh" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to configure startup file. Error: $result" -ForegroundColor Red
        return
    }
    
    # Restart the web app to apply changes
    Write-Host "Restarting web app to apply changes..." -ForegroundColor Yellow
    az webapp restart --name $WebAppName --resource-group $ResourceGroupName
}

# Function to apply post-deployment fixes
function Set-PostDeploymentFixes {
    param (
        [string]$WebAppName,
        [string]$ResourceGroupName,
        [string]$PythonVersion
    )
    
    Write-Host "Applying post-deployment fixes..." -ForegroundColor Yellow
    
    # Check if the web app is in container mode
    $appConfig = az webapp show --name $WebAppName --resource-group $ResourceGroupName | ConvertFrom-Json
    $isContainerMode = $appConfig.kind -like "*,container*" -or $appConfig.reserved -eq $true
    
    if ($isContainerMode) {
        Write-Host "Web App $WebAppName is in container mode. Attempting to fix..." -ForegroundColor Yellow
        
        # Get the current deployment ID
        $latestDeployment = az webapp deployment list --name $WebAppName --resource-group $ResourceGroupName --query "[0].id" -o tsv
        
        if ($latestDeployment) {
            # Redeploy the latest package to trigger a rebuild
            Write-Host "Redeploying latest package to trigger rebuild..." -ForegroundColor Yellow
            az webapp deployment source config-zip --name $WebAppName --resource-group $ResourceGroupName --src "$latestDeployment" --timeout 3600
        } else {
            Write-Host "❌ Failed to fix container mode. Redeployment not possible." -ForegroundColor Red
        }
    } else {
        Write-Host "Web App $WebAppName is in code mode. No fixes needed." -ForegroundColor Green
    }
}

# Function to check if the application is running
function Test-ApplicationStatus {
    Write-Host "`nChecking if application is running..." -ForegroundColor Yellow
    
    # Check if logs show that pip install is in progress
    Write-Host "Checking application logs for startup process..." -ForegroundColor Yellow
    $checkInstallLogs = az webapp log tail --name $WebAppName --resource-group $ResourceGroupName --filter Error Warning Info 2>&1
    $isInstallingDependencies = $checkInstallLogs -like "*pip install*" -or $checkInstallLogs -like "*Installing collected packages*"
    
    if ($isInstallingDependencies) {
        Write-Host "🔄 Python packages are being installed. This may take several minutes..." -ForegroundColor Cyan
        Write-Host "   The script will continue to monitor the application." -ForegroundColor Cyan
    }
    
    $webAppUrl = "https://$WebAppName.azurewebsites.net"
    $maxRetries = 60  # Significantly increased for more time to start up (60 * 15 = 15 minutes)
    $retryCount = 0
    $appReady = $false
    
    while (-not $appReady -and $retryCount -lt $maxRetries) {
        $retryCount++
        $elapsedMinutes = [math]::Round($retryCount * 15 / 60, 1)
        Write-Host "  Checking application status (attempt $retryCount of $maxRetries, elapsed: $elapsedMinutes min)..." -ForegroundColor Yellow
        
        # Every 10th check, look for specific log entries to provide better feedback
        if ($retryCount % 10 -eq 0) {
            $logs = az webapp log tail --name $WebAppName --resource-group $ResourceGroupName --filter Error Warning Info --limit 50 2>&1
            
            if ($logs -like "*startup.sh*" -or $logs -like "*pip install*" -or $logs -like "*Installing collected packages*") {
                Write-Host "   Detected ongoing installation or startup process. Continuing to wait..." -ForegroundColor Cyan
            }
            
            if ($logs -like "*Error:*") {
                Write-Host "   Warning: Detected errors in the logs. The application may have issues starting." -ForegroundColor Yellow
            }
        }
        
        Start-Sleep -Seconds 15  # Wait between checks
        
        # Try the health check endpoint first
        try {
            $statusResult = Invoke-RestMethod -Uri "$webAppUrl/" -Method Get -UseBasicParsing -ErrorAction Stop -TimeoutSec 30
            if ($statusResult.status -eq "ok") {
                $appReady = $true
                Write-Host "✅ Application is running!" -ForegroundColor Green
                continue
            }
        } catch {
            # Health check failed, proceed to next check
        }
        
        # Try docs endpoint 
        try {
            $statusCode = (Invoke-WebRequest -Uri "$webAppUrl/docs" -Method Head -UseBasicParsing -ErrorAction Stop -TimeoutSec 30).StatusCode
            if ($statusCode -eq 200) {
                $appReady = $true
                Write-Host "✅ Swagger UI is available!" -ForegroundColor Green
                continue
            }
        } catch {
            # Docs endpoint failed, proceed to next check
        }
        
        # Try a basic request as last resort
        try {
            $response = Invoke-WebRequest -Uri "$webAppUrl" -Method Get -UseBasicParsing -ErrorAction Stop -TimeoutSec 30
            $statusCode = $response.StatusCode
            
            # Any successful status code (200-299)
            if ($statusCode -ge 200 -and $statusCode -lt 300) {
                $appReady = $true
                Write-Host "✅ Web app is responding with status code $statusCode!" -ForegroundColor Green
                continue
            }
        } catch {
            # All attempts failed for this cycle, will try again in next iteration
        }
    }
    
    if (-not $appReady) {
        if ($retryCount -ge $maxRetries) {
            Write-Host "⚠️ Application status check timed out. It might still be starting up." -ForegroundColor Yellow
            Write-Host "   This is normal for apps with many dependencies to install." -ForegroundColor Yellow
            Write-Host "   The app will continue to initialize even after this script ends." -ForegroundColor Yellow
            Write-Host "   Check the logs using the command: az webapp log tail --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor Cyan
            
            # Return true anyway to prevent resource cleanup when the app might still be initializing
            return $true
        }
    }
    
    return $appReady
}
