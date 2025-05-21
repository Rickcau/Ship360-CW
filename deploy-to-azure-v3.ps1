# Ship360 Chat API - Azure App Service Deployment Script
# This script automates the deployment of the FastAPI application to Azure App Service as code (not container)

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
    [switch]$CleanupOnError = $false, # Default to NOT cleaning up on error
    
    [Parameter(Mandatory = $false)]
    [switch]$RecreateApp = $false,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseLocalDeployment = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseFTPDeployment = $false
)

# Clear console
Clear-Host

# Global variables
$script:skipCleanup = $false

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

# Function to wait for Web App provisioning
function Wait-WebAppProvisioning {
    param (
        [string]$WebAppName,
        [string]$ResourceGroupName
    )
    
    Write-Host "Waiting for Web App to be fully provisioned..." -ForegroundColor Yellow
    $retries = 0
    $maxRetries = 10
    $isReady = $false
    
    while (-not $isReady -and $retries -lt $maxRetries) {
        $retries++
        Start-Sleep -Seconds 10
        
        $status = az webapp show --name $WebAppName --resource-group $ResourceGroupName --query "state" -o tsv 2>&1
        if ($status -eq "Running") {
            $isReady = $true
            Write-Host "✅ Web App is running and ready" -ForegroundColor Green
            break
        }
        
        Write-Host "  Web App is not ready yet (attempt $retries of $maxRetries)..." -ForegroundColor Yellow
    }
    
    return $isReady
}

# Function to clean up resources on error
function Remove-DeploymentResources {
    param (
        [string]$ErrorMessage
    )
    
    if (-not $CleanupOnError -or $script:skipCleanup) {
        Write-Host "❌ Deployment may still be in progress: $ErrorMessage" -ForegroundColor Yellow
        Write-Host "Resources were not removed. Deployment will continue in the background." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Cleaning up resources due to error: $ErrorMessage" -ForegroundColor Yellow
    
    # Delete Web App if it was created in this run
    if ($script:webAppCreatedInThisRun) {
        Write-Host "Deleting Web App $WebAppName..." -ForegroundColor Yellow
        az webapp delete --name $WebAppName --resource-group $ResourceGroupName
    }
    
    # Delete App Service Plan if it was created in this run
    if ($script:appServicePlanCreatedInThisRun) {
        Write-Host "Deleting App Service Plan $AppServicePlanName..." -ForegroundColor Yellow
        az appservice plan delete --name $AppServicePlanName --resource-group $ResourceGroupName --yes
    }
    
    # Delete Resource Group if it was created in this run
    if ($script:resourceGroupCreatedInThisRun) {
        Write-Host "Deleting Resource Group $ResourceGroupName..." -ForegroundColor Yellow
        az group delete --name $ResourceGroupName --yes --no-wait
    }
    
    Write-Host "❌ Deployment failed: $ErrorMessage" -ForegroundColor Red
}

# Function to update startup.sh file
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
    # Initialize tracking variables
    $script:resourceGroupCreatedInThisRun = $false
    $script:appServicePlanCreatedInThisRun = $false
    $script:webAppCreatedInThisRun = $false
    
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
    }
    
    # Check if App Service Plan exists
    $appServicePlanExists = az appservice plan list --resource-group $ResourceGroupName --query "[?name=='$AppServicePlanName']" --output tsv
    if (-not $appServicePlanExists) {
        Write-Host "Creating App Service Plan $AppServicePlanName..." -ForegroundColor Yellow
        
        # Try to create the App Service Plan
        if ($UseFreeAppServicePlan) {
            $result = az appservice plan create --name $AppServicePlanName --resource-group $ResourceGroupName --sku F1 --is-linux 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Free tier (F1) App Service Plan created" -ForegroundColor Green
                $script:appServicePlanCreatedInThisRun = $true
            } else {
                Write-Host "❌ Failed to create Free tier App Service Plan. Error: $result" -ForegroundColor Red
                Write-Host "Trying Basic tier (B1) instead..." -ForegroundColor Yellow
                $result = az appservice plan create --name $AppServicePlanName --resource-group $ResourceGroupName --sku B1 --is-linux 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✅ Basic tier (B1) App Service Plan created" -ForegroundColor Green
                    $script:appServicePlanCreatedInThisRun = $true
                } else {
                    Write-Host "❌ Failed to create App Service Plan. Error: $result" -ForegroundColor Red
                    Remove-DeploymentResources "Failed to create App Service Plan"
                    return
                }
            }
        } else {
            $result = az appservice plan create --name $AppServicePlanName --resource-group $ResourceGroupName --sku B1 --is-linux 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Basic tier (B1) App Service Plan created" -ForegroundColor Green
                $script:appServicePlanCreatedInThisRun = $true
            } else {
                Write-Host "❌ Failed to create App Service Plan. Error: $result" -ForegroundColor Red
                Remove-DeploymentResources "Failed to create App Service Plan"
                return
            }
        }
    } else {
        Write-Host "✅ App Service Plan $AppServicePlanName already exists" -ForegroundColor Green
    }
    
    # Check if Web App exists
    $webAppExists = az webapp list --resource-group $ResourceGroupName --query "[?name=='$WebAppName']" --output tsv
    if (-not $webAppExists) {
        Write-Host "Creating Web App $WebAppName..." -ForegroundColor Yellow
        # Use correct runtime format with colon separator (PYTHON:3.12)
        $result = az webapp create --name $WebAppName --resource-group $ResourceGroupName --plan $AppServicePlanName --runtime "PYTHON:$PythonVersion" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to create Web App. Error: $result" -ForegroundColor Red
            Remove-DeploymentResources "Failed to create Web App"
            return
        }
        $script:webAppCreatedInThisRun = $true
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
            Write-Host "Recreating web app in code mode..." -ForegroundColor Yellow
            $createResult = az webapp create --name $WebAppName --resource-group $ResourceGroupName `
                --plan $appPlanInfo.name --runtime "PYTHON:$PythonVersion"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "❌ Failed to recreate web app. Error: $createResult" -ForegroundColor Red
                Remove-DeploymentResources "Failed to recreate web app"
                return
            }
            Write-Host "✅ Web app recreated in code mode" -ForegroundColor Green
            
            # Wait for the web app to be fully provisioned
            $webAppReady = Wait-WebAppProvisioning -WebAppName $WebAppName -ResourceGroupName $ResourceGroupName
            if (-not $webAppReady) {
                Write-Host "⚠️ Warning: Web app may not be fully ready for configuration, but continuing anyway..." -ForegroundColor Yellow
            }
        } elseif ($isContainerMode) {
            Write-Host "⚠️ The web app is running in container mode but -RecreateApp was not specified." -ForegroundColor Yellow
            Write-Host "   To fix this, run the script again with the -RecreateApp parameter." -ForegroundColor Yellow
            
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
        Remove-DeploymentResources "Failed to configure startup file"
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
        "PYTHON_ENABLE_GUNICORN_MULTIWORKERS=1" # Enable multiple gunicorn workers
    )
    
    # Set all settings at once
    $result = az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings $appSettings 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to set application settings. Error: $result" -ForegroundColor Red
        Remove-DeploymentResources "Failed to set application settings"
        return
    } else {
        Write-Host "✅ Application settings configured" -ForegroundColor Green
    }
    
    # Check and update CORS settings
    Write-Host "Updating CORS settings..." -ForegroundColor Yellow
    $corsResult = az webapp cors add --name $WebAppName --resource-group $ResourceGroupName --allowed-origins "*" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ CORS settings updated to allow all origins" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Failed to update CORS settings: $corsResult" -ForegroundColor Yellow
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
            Write-Host "The following environment variables are required:" -ForegroundColor Yellow
            Write-Host "  - AZURE_OPENAI_ENDPOINT" -ForegroundColor Yellow
            Write-Host "  - AZURE_OPENAI_API_KEY" -ForegroundColor Yellow
            Write-Host "  - AZURE_OPENAI_CHAT_DEPLOYMENT_NAME" -ForegroundColor Yellow
            Write-Host "  - AZURE_OPENAI_API_VERSION" -ForegroundColor Yellow
            Write-Host "  - SP360_TOKEN_URL" -ForegroundColor Yellow
            Write-Host "  - SP360_TOKEN_USERNAME" -ForegroundColor Yellow
            Write-Host "  - SP360_TOKEN_PASSWORD" -ForegroundColor Yellow
            Write-Host "  - SP360_RATE_SHOP_URL" -ForegroundColor Yellow
            Write-Host "  - SP360_SHIPMENTS_URL" -ForegroundColor Yellow
            Write-Host "  - SP360_TRACKING_URL" -ForegroundColor Yellow
            return
        }
    }
    
    $envVars = Get-Content $envFilePath | Where-Object { $_ -match "^[^#].*=.*" } | ForEach-Object {
        $parts = $_ -split "=", 2
        $key = $parts[0].Trim()
        $value = $parts[1].Trim('"', "'", ' ')
        "$key=$value"
    }
    
    if ($envVars.Count -gt 0) {
        # Check if the web app exists before trying to set environment variables
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

# Function to enable FTP and SCM Basic Auth Publishing
function Enable-FTPBasicAuth {
    param (
        [string]$WebAppName,
        [string]$ResourceGroupName
    )
    
    Write-Host "Enabling FTP and SCM Basic Auth Publishing..." -ForegroundColor Yellow
    
    # Check if the web app exists
    $webAppExists = az webapp list --resource-group $ResourceGroupName --query "[?name=='$WebAppName']" --output tsv
    if (-not $webAppExists) {
        Write-Host "❌ Web App $WebAppName not found. Cannot enable FTP/SCM auth." -ForegroundColor Red
        return $false
    }
    
    # Enable SCM Basic Auth (confirmed working command)
    Write-Host "Enabling SCM Basic Auth..." -ForegroundColor Yellow
    $scmResult = az resource update --resource-group $ResourceGroupName --name scm --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent sites/$WebAppName --set properties.allow=true 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to enable SCM Basic Auth. Error: $scmResult" -ForegroundColor Red
        return $false
    } else {
        Write-Host "✅ SCM Basic Auth enabled" -ForegroundColor Green
    }
    
    # Enable FTP Basic Auth (confirmed working command)
    Write-Host "Enabling FTP Basic Auth..." -ForegroundColor Yellow
    $ftpResult = az resource update --resource-group $ResourceGroupName --name ftp --namespace Microsoft.Web --resource-type basicPublishingCredentialsPolicies --parent sites/$WebAppName --set properties.allow=true 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to enable FTP Basic Auth. Error: $ftpResult" -ForegroundColor Red
        return $false
    } else {
        Write-Host "✅ FTP Basic Auth enabled" -ForegroundColor Green
    }
    
    # Set FTP state to allow both FTP and FTPS
    Write-Host "Setting FTP state to allow FTP and FTPS connections..." -ForegroundColor Yellow
    $ftpsResult = az webapp config set --name $WebAppName --resource-group $ResourceGroupName --ftps-state "AllAllowed" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to set FTP state. Error: $ftpsResult" -ForegroundColor Red
        return $false
    } else {
        Write-Host "✅ FTP state set to allow all connections" -ForegroundColor Green
    }
    
    Write-Host "✅ FTP and SCM Basic Auth Publishing enabled successfully" -ForegroundColor Green
    Write-Host "Restarting web app to apply authentication changes..." -ForegroundColor Yellow
    
    # Restart the web app to apply the changes
    az webapp restart --name $WebAppName --resource-group $ResourceGroupName
    
    # Give the app a moment to restart
    Start-Sleep -Seconds 10
    
    return $true
}

# Function to deploy using Kudu REST API (more reliable than FTP)
function Publish-ApplicationUsingKudu {
    param (
        [string]$WebAppName,
        [string]$ResourceGroupName,
        [string]$SourceDir
    )
    
    Write-Host "Deploying application using Kudu ZIP deployment (more reliable than FTPS)..." -ForegroundColor Yellow
    
    # Create a zip file for deployment
    $zipPath = "ship360-chat-api-deploy.zip"
    Write-Host "Creating deployment ZIP archive..." -ForegroundColor Yellow
    
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    
    try {
        Compress-Archive -Path "$SourceDir\*" -DestinationPath $zipPath -Force
        Write-Host "✅ ZIP archive created for deployment" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to create ZIP archive: $_" -ForegroundColor Red
        return $false
    }
    
    # Get publishing credentials for Kudu API
    Write-Host "Getting Kudu API credentials..." -ForegroundColor Yellow
    $publishingProfile = az webapp deployment list-publishing-profiles --name $WebAppName --resource-group $ResourceGroupName --query "[?publishMethod=='MSDeploy']" | ConvertFrom-Json
    
    if (-not $publishingProfile) {
        Write-Host "❌ Failed to get Kudu publishing credentials." -ForegroundColor Red
        return $false
    }
    
    # Extract credentials
    $kuduUsername = $publishingProfile.userName
    $kuduPassword = $publishingProfile.userPWD
    
    # Create authorization header
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $kuduUsername, $kuduPassword)))
    $userAgent = "PowerShell Script"
    $Headers = @{
        Authorization = ("Basic {0}" -f $base64AuthInfo)
        "User-Agent" = $userAgent
    }
    
    # Kudu API URL for ZIP deployment
    $kuduApiUrl = "https://$WebAppName.scm.azurewebsites.net/api/zipdeploy"
    
    # Upload and deploy the ZIP file
    Write-Host "Uploading and deploying ZIP file via Kudu API..." -ForegroundColor Yellow
    Write-Host "This may take several minutes for large applications." -ForegroundColor Yellow
    
    try {
        $deploymentStartTime = Get-Date
        
        # Use Invoke-RestMethod to upload and deploy
        $result = Invoke-RestMethod -Uri $kuduApiUrl -Headers $Headers -Method POST -InFile $zipPath -ContentType "multipart/form-data" -TimeoutSec 600
        
        $deploymentTime = [math]::Round(((Get-Date) - $deploymentStartTime).TotalSeconds, 1)
        Write-Host "✅ Deployment completed in $deploymentTime seconds!" -ForegroundColor Green
        
        # Restart the app to ensure changes are applied
        Write-Host "Restarting web app to apply changes..." -ForegroundColor Yellow
        az webapp restart --name $WebAppName --resource-group $ResourceGroupName
        
        Write-Host "✅ Deployment via Kudu API successful!" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ Failed to deploy via Kudu API: $_" -ForegroundColor Red
        
        # Provide manual upload instructions
        Write-Host "`nAlternative deployment option - Use Kudu console:" -ForegroundColor Cyan
        Write-Host "1. Go to: https://$WebAppName.scm.azurewebsites.net/ZipDeployUI" -ForegroundColor Yellow
        Write-Host "2. Drag and drop $zipPath to deploy" -ForegroundColor Yellow
        
        return $false
    } finally {
        # Clean up the ZIP file if configured to do so
        if ($CleanupOnError) {
            if (Test-Path $zipPath) {
                Remove-Item $zipPath -Force
            }
        } else {
            Write-Host "ZIP file available at: $zipPath" -ForegroundColor Cyan
        }
    }
}

function Publish-Application {
    # Check deployment method first
    if ($UseFTPDeployment) {
        # For FTP deployment, we need to enable FTP Basic Auth
        $ftpEnabled = Enable-FTPBasicAuth -WebAppName $WebAppName -ResourceGroupName $ResourceGroupName
        
        if (-not $ftpEnabled) {
            Write-Host "❌ Cannot proceed with FTP deployment without enabling FTP Basic Auth." -ForegroundColor Red
            Write-Host "   You can manually enable it in Azure Portal:" -ForegroundColor Yellow
            Write-Host "   1. Go to your Web App -> Configuration -> General settings" -ForegroundColor Yellow
            Write-Host "   2. Set 'FTP Basic Auth Publishing' to 'On'" -ForegroundColor Yellow
            Write-Host "   3. Set 'FTP state' to 'FTP and FTPS' or 'FTPS only'" -ForegroundColor Yellow
            Write-Host "   4. Click 'Save' and try again" -ForegroundColor Yellow
            return
        }
        
        # Skip ZIP creation for FTP/Kudu deployment
        Write-Host "FTP deployment enabled. However, it's often problematic with Windows FTP client." -ForegroundColor Yellow
        Write-Host "Switching to more reliable Kudu ZIP deployment..." -ForegroundColor Yellow
        
        $workingDir = Get-Location
        $sourceDir = Join-Path -Path $workingDir -ChildPath "ship360-chat-api"
        
        # Use more reliable Kudu ZIP deployment
        Publish-ApplicationUsingKudu -WebAppName $WebAppName -ResourceGroupName $ResourceGroupName -SourceDir $sourceDir
        return
    }
    
    # ZIP deployment - create archive
    Write-Host "Packaging application for ZIP deployment..." -ForegroundColor Yellow
    
    $workingDir = Get-Location
    $deploymentStartTime = Get-Date
    
    # Create a temporary deployment zip file
    $zipFile = "ship360-deploy.zip"
    if (Test-Path $zipFile) {
        Remove-Item $zipFile -Force
    }
    
    # Navigate to the application directory and create a zip file
    Set-Location -Path ".\ship360-chat-api"
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
    }
    catch {
        Write-Host "❌ Failed to create ZIP archive: $_" -ForegroundColor Red
        Set-Location -Path $workingDir  # Return to original directory before cleanup
        if ($CleanupOnError) {
            Remove-DeploymentResources "Failed to create ZIP archive: $_"
        }
        return
    }
    finally {
        # Return to original directory
        Set-Location -Path $workingDir
    }
    
    # Use ZIP deployment method
    Publish-ApplicationUsingZip
}

function Publish-ApplicationUsingZip {
    Write-Host "Deploying application using ZIP deployment..." -ForegroundColor Yellow
    
    # Check if there are cryptography related warnings, which can be ignored for local CLI
    Write-Host "Note: Any warnings about 32-bit Python and cryptography are local to your CLI and won't affect the deployment." -ForegroundColor Yellow
    
    # Deploy the zip file to Azure
    Write-Host "Deploying ZIP file to Azure App Service..." -ForegroundColor Yellow
    # Increased timeout to 3600 seconds (1 hour) to allow for dependency installation
    $deployResult = az webapp deploy --name $WebAppName --resource-group $ResourceGroupName --src-path $zipFile --async $false --timeout 3600 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        # If deployment fails with 400 status code, try navigating to the SCM site for logs
        if ($deployResult -like "*Status Code: 400*") {
            $script:skipCleanup = $true  # Always skip cleanup on specific deployment errors
            
            $scmUrl = "https://$WebAppName.scm.azurewebsites.net"
            Write-Host "⚠️ Deployment received a 400 error, which may be due to Python package installation issues." -ForegroundColor Yellow
            Write-Host "   You can check the deployment logs at: $scmUrl/api/deployments/latest" -ForegroundColor Cyan
            Write-Host "   Or try using the FTP deployment method by re-running with -UseFTPDeployment switch." -ForegroundColor Cyan
            
            # Rather than fail, let's try to restart the app which might help
            Write-Host "Attempting to restart the web app to finalize deployment..." -ForegroundColor Yellow
            az webapp restart --name $WebAppName --resource-group $ResourceGroupName
            
            return
        }
        
        # If the deployment fails due to timeout but deployment is still in progress
        if ($deployResult -like "*Timeout reached*" -or $deployResult -like "*is still on-going*" -or $deployResult -like "*timed out*") {
            $script:skipCleanup = $true  # Prevent cleanup during timeout
            
            Write-Host "⚠️ Deployment is still in progress but the command timed out." -ForegroundColor Yellow
            Write-Host "   This is normal for apps with many dependencies to install." -ForegroundColor Yellow
            
            # Monitor deployment status - increased max monitoring time
            $maxMonitoringMinutes = 60  # Increased from 30 to 60 minutes
            $endMonitoringTime = $deploymentStartTime.AddMinutes($maxMonitoringMinutes)
            
            Write-Host "Continuing to monitor deployment status for up to $maxMonitoringMinutes minutes..." -ForegroundColor Yellow
            
            while ((Get-Date) -lt $endMonitoringTime) {
                Start-Sleep -Seconds 30
                
                # Check for logs indicating progress
                $logs = az webapp log tail --name $WebAppName --resource-group $ResourceGroupName --filter Error Warning Info --limit 10 2>&1
                
                if ($logs -like "*pip install*" -or $logs -like "*Installing collected packages*") {
                    Write-Host "  📦 Python package installation in progress. This may take several minutes..." -ForegroundColor Cyan
                }
                
                if ($logs -like "*gunicorn*" -or $logs -like "*Starting FastAPI*") {
                    Write-Host "  🚀 Application startup detected!" -ForegroundColor Green
                    break
                }
                
                # If no meaningful logs are found, just show a progress indicator
                Write-Host "  Deployment still in progress..." -ForegroundColor Yellow
            }
            
            Write-Host "⚠️ Monitoring period ended. The app may still be starting up." -ForegroundColor Yellow
            Write-Host "   Please check the application status in a few minutes." -ForegroundColor Yellow
            Write-Host "   Dependencies like semantic-kernel and openai can take a long time to install." -ForegroundColor Yellow
        } else {
            Write-Host "❌ Deployment failed. Error: $deployResult" -ForegroundColor Red
            if ($CleanupOnError) {
                Remove-DeploymentResources "Deployment failed"
            }
            return
        }
    } else {
        Write-Host "✅ ZIP deployment completed successfully!" -ForegroundColor Green
    }
}

# Function to check if the application is running
function Test-ApplicationStatus {
    Write-Host "`nChecking if application is running..." -ForegroundColor Yellow
    
    $webAppUrl = "https://$WebAppName.azurewebsites.net"
    $maxRetries = 40  # Doubled from 20 to 40 for longer wait time
    $retryCount = 0
    $appReady = $false
    
    while (-not $appReady -and $retryCount -lt $maxRetries) {
        $retryCount++
        Write-Host "  Checking application status (attempt $retryCount of $maxRetries)..." -ForegroundColor Yellow
        
        # Every 5th check, look for specific log entries to provide better feedback
        if ($retryCount % 5 -eq 0) {
            $logs = az webapp log tail --name $WebAppName --resource-group $ResourceGroupName --filter Error Warning Info --limit 20 2>&1
            
            if ($logs -like "*startup.sh*" -or $logs -like "*pip install*" -or $logs -like "*Installing collected packages*") {
                Write-Host "   Detected ongoing installation or startup process. Continuing to wait..." -ForegroundColor Cyan
                Write-Host "   This is normal and can take 10-30 minutes for apps with many dependencies." -ForegroundColor Cyan
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
        Write-Host "⚠️ Application status check timed out. It might still be starting up." -ForegroundColor Yellow
        Write-Host "   This is normal for apps with many dependencies to install." -ForegroundColor Yellow
        Write-Host "   The app will continue to initialize even after this script ends." -ForegroundColor Yellow
        Write-Host "   504 Gateway Timeout errors are normal during startup." -ForegroundColor Yellow
        Write-Host "   Check the logs using the command: az webapp log tail --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor Cyan
    }
    
    return $appReady
}

# Main execution flow
Write-Host "Starting Ship360 Chat API deployment to Azure..." -ForegroundColor Green

# Verify prerequisites
Test-AzureCLI
Test-AzureLogin

# Update startup file
Update-StartupFile

# Create and configure Azure resources
New-AzureResources

# Set environment variables from .env file
Set-EnvironmentVariables

# Deploy application
Publish-Application

# Check application status
$appRunning = Test-ApplicationStatus

# Display final deployment information
Write-Host "`n==================== Deployment Summary ====================" -ForegroundColor Cyan
Write-Host "Resource Group:     $ResourceGroupName" -ForegroundColor Cyan
Write-Host "App Service Plan:   $AppServicePlanName" -ForegroundColor Cyan
Write-Host "Web App Name:       $WebAppName" -ForegroundColor Cyan
Write-Host "Web App URL:        https://$WebAppName.azurewebsites.net" -ForegroundColor Cyan
Write-Host "Application Status: $(if ($appRunning) { "Running ✅" } else { "Starting up ⌛" })" -ForegroundColor $(if ($appRunning) { "Green" } else { "Yellow" })
Write-Host "===========================================================" -ForegroundColor Cyan

# Provide helpful commands
Write-Host "`nHelpful commands:" -ForegroundColor Green
Write-Host "  - View logs: az webapp log tail --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor White
Write-Host "  - SSH into app: az webapp ssh --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor White
Write-Host "  - Restart app: az webapp restart --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor White
Write-Host "  - View settings: az webapp config appsettings list --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor White
Write-Host "  - SCM/Kudu URL: https://$WebAppName.scm.azurewebsites.net" -ForegroundColor White
Write-Host "  - Swap to FTP deployment: $PSCommandPath -UseFTPDeployment" -ForegroundColor White 