# Ship360-CW Chat API Deployment to Azure
# This script automates the deployment of the Ship360-CW Chat API to Azure App Service

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
    [bool]$UseFreeAppServicePlan = $false,
    
    [Parameter(Mandatory = $false)]
    [bool]$CleanupOnError = $true
)

# Clear console
Clear-Host

# Function to check if Azure CLI is installed
function Check-AzureCliInstalled {
    $azureCliVersion = az --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Azure CLI is not installed. Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Azure CLI is installed" -ForegroundColor Green
}

# Function to check if user is logged in to Azure
function Check-AzureLogin {
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
function Prepare-RequirementsFile {
    $requirementsPath = ".\ship360-chat-api\requirements.txt"
    
    if (-not (Test-Path $requirementsPath)) {
        Write-Host "Creating requirements.txt file..." -ForegroundColor Yellow
        @"
fastapi==0.103.1
uvicorn==0.23.2
python-dotenv==1.0.0
aiohttp==3.8.5
semantic-kernel==0.4.3.dev0
azure-search-documents==11.4.0
gunicorn==20.1.0
"@ | Out-File -FilePath $requirementsPath -Encoding utf8
        Write-Host "✅ Created requirements.txt file" -ForegroundColor Green
    } else {
        Write-Host "✅ requirements.txt file already exists" -ForegroundColor Green
        # Check if gunicorn is in requirements.txt
        $requirementsContent = Get-Content $requirementsPath
        if (-not ($requirementsContent -match "gunicorn")) {
            Write-Host "Adding gunicorn to requirements.txt..." -ForegroundColor Yellow
            "gunicorn==20.1.0" | Out-File -FilePath $requirementsPath -Append -Encoding utf8
            Write-Host "✅ Added gunicorn to requirements.txt" -ForegroundColor Green
        }
    }
}

# Function to create startup.sh file
function Prepare-StartupFile {
    $startupPath = ".\ship360-chat-api\startup.sh"
      if (-not (Test-Path $startupPath)) {
        Write-Host "Creating startup.sh file..." -ForegroundColor Yellow
        @"
#!/bin/bash
cd /home/site/wwwroot

# Install dependencies if needed
pip install -r requirements.txt

# Export environment variables
export PYTHONPATH=/home/site/wwwroot:$PYTHONPATH

# Start the FastAPI application with Gunicorn
gunicorn app.main:app --workers 2 --worker-class uvicorn.workers.UvicornWorker --timeout 600 --bind 0.0.0.0:8000 --access-logfile '-' --error-logfile '-'
"@ | Out-File -FilePath $startupPath -Encoding utf8 -NoNewline
        Write-Host "✅ Created startup.sh file" -ForegroundColor Green
        
        # Note: We don't need to make it executable on Windows as Azure will handle this
        Write-Host "Note: No need to run chmod +x on Windows as Azure will handle executable permissions" -ForegroundColor Yellow
    } else {
        Write-Host "✅ startup.sh file already exists" -ForegroundColor Green
    }
}

# Function to create Azure resources
function Create-AzureResources {    # Check if resource group exists
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
                    Write-Host "❌ Failed to create Free tier App Service Plan. Error: $result" -ForegroundColor Red
                    # If Free tier failed and we've tried both options, exit
                    if ($attempts -ge $maxAttempts) {
                        Write-Host "❌ Could not create App Service Plan. You may need to request a quota increase: https://aka.ms/antquotahelp" -ForegroundColor Red
                        exit 1
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
                        Write-Host "3. Try using the Free tier by running the script with -UseFreeAppServicePlan `$true" -ForegroundColor Yellow
                        
                        # If this is the first attempt, try using Free tier instead
                        if ($attempts -lt $maxAttempts) {
                            $UseFreeAppServicePlan = $true
                            Write-Host "Trying Free tier (F1) instead..." -ForegroundColor Yellow
                        } else {
                            Write-Host "❌ Deployment failed due to quota limitations." -ForegroundColor Red
                            exit 1
                        }
                    } else {
                        Write-Host "❌ App Service Plan creation failed. Please check the error message above." -ForegroundColor Red
                        exit 1
                    }
                }
            }
        }
    } else {
        Write-Host "✅ App Service Plan $AppServicePlanName already exists" -ForegroundColor Green
    }
    
    # Check if Web App exists
    $webAppExists = az webapp list --resource-group $ResourceGroupName --query "[?name=='$WebAppName']" --output tsv
    if (-not $webAppExists) {
        Write-Host "Creating Web App $WebAppName..." -ForegroundColor Yellow
        $result = az webapp create --name $WebAppName --resource-group $ResourceGroupName --plan $AppServicePlanName --runtime "PYTHON:$PythonVersion" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to create Web App. Error: $result" -ForegroundColor Red
            exit 1
        }
        Write-Host "✅ Web App created" -ForegroundColor Green
    } else {
        Write-Host "✅ Web App $WebAppName already exists" -ForegroundColor Green
    }
    
    # Configure Web App startup file
    Write-Host "Configuring startup file..." -ForegroundColor Yellow
    $result = az webapp config set --name $WebAppName --resource-group $ResourceGroupName --startup-file "startup.sh" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to configure startup file. Error: $result" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Startup file configured" -ForegroundColor Green
    
    # Configure additional application settings
    Write-Host "Configuring additional application settings..." -ForegroundColor Yellow
    
    # Set SCM_DO_BUILD_DURING_DEPLOYMENT to ensure proper build during deployment
    $result = az webapp configappsettings set --name $WebAppName --resource-group $ResourceGroupName --settings SCM_DO_BUILD_DURING_DEPLOYMENT=true 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to set SCM_DO_BUILD_DURING_DEPLOYMENT. Error: $result" -ForegroundColor Red
    }
    
    # Set WEBSITES_PORT to ensure the app listens on the correct port
    $result = az webapp config appsettings set --name $WebAppName --resource-group $ResourceGroupName --settings WEBSITES_PORT=8000 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to set WEBSITES_PORT. Error: $result" -ForegroundColor Red
    }
    
    Write-Host "✅ Additional application settings configured" -ForegroundColor Green
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

# Function to deploy application
function Deploy-Application {
    Write-Host "Packaging application for deployment..." -ForegroundColor Yellow
    
    $workingDir = Get-Location
    
    # Create a temporary deployment zip file
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
        Cleanup-Resources "Deployment failed"
        exit 1
    }
    
    # Clean up
    if (Test-Path $zipFile) {
        Remove-Item $zipFile -Force
    }
    
    Write-Host "✅ Application deployment completed" -ForegroundColor Green
}

# Function to check if the application is running
function Test-ApplicationStatus {
    param (
        [string]$WebAppName,
        [string]$ResourceGroupName
    )
    
    Write-Host "Checking if application is running..." -ForegroundColor Yellow
    
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
                Write-Host "⚠️ Application may not be fully started yet. This is normal for the first deployment." -ForegroundColor Yellow
                Write-Host "  You can check the logs to diagnose any issues:" -ForegroundColor Yellow
                Write-Host "  az webapp log tail --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor Gray
            } else {
                Write-Host "  Application not ready yet, waiting..." -ForegroundColor Yellow
            }
        }
    }
    
    return $appReady
}

# Function to clean up resources on error
function Remove-DeploymentResources {
    param (
        [string]$Message = "An error occurred during deployment."
    )
    
    Write-Host "`n$Message" -ForegroundColor Red
    
    if ($CleanupOnError) {
        Write-Host "Cleaning up resources..." -ForegroundColor Yellow
        
        # Check if Web App exists and delete it
        $webAppExists = az webapp list --resource-group $ResourceGroupName --query "[?name=='$WebAppName']" --output tsv
        if ($webAppExists) {
            Write-Host "Deleting Web App $WebAppName..." -ForegroundColor Yellow
            az webapp delete --name $WebAppName --resource-group $ResourceGroupName --keep-empty-plan
        }
        
        # Check if App Service Plan exists and delete it
        $appServicePlanExists = az appservice plan list --resource-group $ResourceGroupName --query "[?name=='$AppServicePlanName']" --output tsv
        if ($appServicePlanExists) {
            Write-Host "Deleting App Service Plan $AppServicePlanName..." -ForegroundColor Yellow
            az appservice plan delete --name $AppServicePlanName --resource-group $ResourceGroupName --yes
        }
        
        # Check if Resource Group exists and delete it (only if we created it in this run)
        if ($script:resourceGroupCreatedInThisRun) {
            Write-Host "Deleting Resource Group $ResourceGroupName..." -ForegroundColor Yellow
            az group delete --name $ResourceGroupName --yes --no-wait
            Write-Host "Resource Group deletion initiated (will continue in background)" -ForegroundColor Yellow
        }
        
        Write-Host "Cleanup completed." -ForegroundColor Yellow
    } else {
        Write-Host "Resources were not cleaned up. You may need to manually delete them." -ForegroundColor Yellow
    }
    
    exit 1
}

# Add a global variable to track if we created the resource group in this run
$script:resourceGroupCreatedInThisRun = $false

# Main Execution with error handling
Write-Host "Starting deployment of Ship360-CW Chat API to Azure..." -ForegroundColor Cyan
Write-Host "Using location: $Location" -ForegroundColor Cyan

try {
    # Check prerequisites
    Check-AzureCliInstalled
    Check-AzureLogin
    
    # Prepare application files
    Prepare-RequirementsFile
    Prepare-StartupFile
    
    # Create and configure Azure resources
    Create-AzureResources
    Set-EnvironmentVariables
    
    # Deploy the application
    Deploy-Application
      # Check application status
    $appStatus = Test-ApplicationStatus -WebAppName $WebAppName -ResourceGroupName $ResourceGroupName
      # Display URL for the deployed application
    $webAppUrl = "https://$WebAppName.azurewebsites.net"
    Write-Host "`nDeployment complete! Your API is available at:" -ForegroundColor Green
    Write-Host "$webAppUrl/api/chat/sync" -ForegroundColor Cyan
    Write-Host "$webAppUrl/docs" -ForegroundColor Cyan
    Write-Host "`nTo check logs, run:" -ForegroundColor Yellow
    Write-Host "az webapp log tail --name $WebAppName --resource-group $ResourceGroupName" -ForegroundColor White
} catch {
    Remove-DeploymentResources "Deployment failed with error: $_"
}