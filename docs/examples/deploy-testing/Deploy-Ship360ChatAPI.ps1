#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploys the Ship360 Chat API (FastAPI) to Azure App Service.

.DESCRIPTION
    This PowerShell script automates the deployment of the Ship360 Chat API to Azure App Service.
    It creates the necessary Azure resources, configures the runtime environment, and deploys the FastAPI application.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group to create or use.

.PARAMETER AppServiceName
    The name of the Azure App Service (Web App) to create.

.PARAMETER Location
    The Azure region where resources will be created (default: eastus).

.PARAMETER AppServicePlanName
    The name of the App Service Plan to create (default: generated from AppServiceName).

.PARAMETER PricingTier
    The pricing tier for the App Service Plan (default: B1).

.PARAMETER SubscriptionId
    The Azure Subscription ID to use (optional - uses current subscription if not specified).

.PARAMETER EnvironmentFile
    Path to the .env file containing environment variables for the application.

.PARAMETER SourcePath
    Path to the Ship360 Chat API source code (default: ../../ship360-chat-api).

.PARAMETER SkipResourceCreation
    Skip creation of Azure resources and only deploy the application.

.EXAMPLE
    .\Deploy-Ship360ChatAPI.ps1 -ResourceGroupName "rg-ship360-dev" -AppServiceName "app-ship360-chat-dev" -EnvironmentFile ".\ship360.env"

.EXAMPLE
    .\Deploy-Ship360ChatAPI.ps1 -ResourceGroupName "rg-ship360-prod" -AppServiceName "app-ship360-chat-prod" -Location "westus2" -PricingTier "P1v2" -EnvironmentFile ".\ship360-prod.env"

.NOTES
    Prerequisites:
    - Azure CLI installed and logged in
    - Azure subscription with appropriate permissions
    - Ship360 Chat API source code
    - Environment variables configured in .env file
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$AppServiceName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$AppServicePlanName = "$AppServiceName-plan",
    
    [Parameter(Mandatory = $false)]
    [string]$PricingTier = "B1",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$EnvironmentFile,
    
    [Parameter(Mandatory = $false)]
    [string]$SourcePath = "../../../ship360-chat-api",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipResourceCreation
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "Green"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-ColorOutput "Checking prerequisites..." "Yellow"
    
    # Check if Azure CLI is installed
    try {
        $azVersion = az version --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✓ Azure CLI version: $($azVersion.'azure-cli')" "Green"
    }
    catch {
        Write-Error "Azure CLI is not installed or not in PATH. Please install Azure CLI and try again."
        exit 1
    }
    
    # Check if logged into Azure
    try {
        $account = az account show --output json 2>$null | ConvertFrom-Json
        Write-ColorOutput "✓ Logged into Azure as: $($account.user.name)" "Green"
        Write-ColorOutput "✓ Current subscription: $($account.name) ($($account.id))" "Green"
    }
    catch {
        Write-Error "Not logged into Azure. Please run 'az login' and try again."
        exit 1
    }
    
    # Check if source path exists
    if (!(Test-Path $SourcePath)) {
        Write-Error "Source path '$SourcePath' does not exist. Please check the path and try again."
        exit 1
    }
    
    # Check if requirements.txt exists
    $requirementsPath = Join-Path $SourcePath "requirements.txt"
    if (!(Test-Path $requirementsPath)) {
        Write-Error "requirements.txt not found at '$requirementsPath'."
        exit 1
    }
    
    # Check if environment file exists
    if (!(Test-Path $EnvironmentFile)) {
        Write-Error "Environment file '$EnvironmentFile' does not exist."
        exit 1
    }
    
    # Check if main.py exists
    $mainPyPath = Join-Path $SourcePath "app/main.py"
    if (!(Test-Path $mainPyPath)) {
        Write-Error "Main application file not found at '$mainPyPath'."
        exit 1
    }
    
    Write-ColorOutput "✓ All prerequisites met!" "Green"
}

# Function to set Azure subscription
function Set-AzureSubscription {
    if ($SubscriptionId) {
        Write-ColorOutput "Setting Azure subscription to: $SubscriptionId" "Yellow"
        try {
            az account set --subscription $SubscriptionId
            Write-ColorOutput "✓ Subscription set successfully" "Green"
        }
        catch {
            Write-Error "Failed to set subscription to '$SubscriptionId'. Please check the subscription ID."
            exit 1
        }
    }
}

# Function to create Azure resources
function New-AzureResources {
    if ($SkipResourceCreation) {
        Write-ColorOutput "Skipping resource creation..." "Yellow"
        return
    }
    
    Write-ColorOutput "Creating Azure resources..." "Yellow"
    
    # Create Resource Group
    Write-ColorOutput "Creating resource group: $ResourceGroupName" "Cyan"
    try {
        $rgExists = az group exists --name $ResourceGroupName --output tsv
        if ($rgExists -eq "false") {
            az group create --name $ResourceGroupName --location $Location --output none
            Write-ColorOutput "✓ Resource group created: $ResourceGroupName" "Green"
        } else {
            Write-ColorOutput "✓ Resource group already exists: $ResourceGroupName" "Green"
        }
    }
    catch {
        Write-Error "Failed to create resource group: $ResourceGroupName"
        exit 1
    }
    
    # Create App Service Plan
    Write-ColorOutput "Creating App Service Plan: $AppServicePlanName" "Cyan"
    try {
        $planExists = az appservice plan show --name $AppServicePlanName --resource-group $ResourceGroupName --output none 2>$null
        if (!$planExists) {
            az appservice plan create `
                --name $AppServicePlanName `
                --resource-group $ResourceGroupName `
                --location $Location `
                --sku $PricingTier `
                --is-linux `
                --output none
            Write-ColorOutput "✓ App Service Plan created: $AppServicePlanName" "Green"
        } else {
            Write-ColorOutput "✓ App Service Plan already exists: $AppServicePlanName" "Green"
        }
    }
    catch {
        Write-Error "Failed to create App Service Plan: $AppServicePlanName"
        exit 1
    }
    
    # Create Web App
    Write-ColorOutput "Creating Web App: $AppServiceName" "Cyan"
    try {
        $appExists = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --output none 2>$null
        if (!$appExists) {
            az webapp create `
                --name $AppServiceName `
                --resource-group $ResourceGroupName `
                --plan $AppServicePlanName `
                --runtime "PYTHON|3.11" `
                --output none
            Write-ColorOutput "✓ Web App created: $AppServiceName" "Green"
        } else {
            Write-ColorOutput "✓ Web App already exists: $AppServiceName" "Green"
        }
    }
    catch {
        Write-Error "Failed to create Web App: $AppServiceName"
        exit 1
    }
}

# Function to parse environment file and set app settings
function Set-EnvironmentVariables {
    Write-ColorOutput "Configuring environment variables..." "Yellow"
    
    try {
        # Read environment file
        $envContent = Get-Content $EnvironmentFile
        $appSettings = @()
        
        foreach ($line in $envContent) {
            # Skip empty lines and comments
            if ($line -match '^\s*$' -or $line -match '^\s*#') {
                continue
            }
            
            # Parse KEY=VALUE format
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Remove quotes if present
                $value = $value -replace '^["'']|["'']$', ''
                
                $appSettings += "$key=$value"
            }
        }
        
        if ($appSettings.Count -gt 0) {
            # Set application settings
            az webapp config appsettings set `
                --name $AppServiceName `
                --resource-group $ResourceGroupName `
                --settings $appSettings `
                --output none
            
            Write-ColorOutput "✓ Environment variables configured ($($appSettings.Count) variables)" "Green"
        } else {
            Write-ColorOutput "⚠ No environment variables found in file" "Yellow"
        }
    }
    catch {
        Write-Error "Failed to configure environment variables: $_"
        exit 1
    }
}

# Function to configure startup command
function Set-StartupCommand {
    Write-ColorOutput "Configuring startup command..." "Yellow"
    
    try {
        # Set startup command for FastAPI with gunicorn
        $startupCommand = "gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.main:app --bind=0.0.0.0 --timeout 600"
        
        az webapp config set `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --startup-file $startupCommand `
            --output none
        
        Write-ColorOutput "✓ Startup command configured" "Green"
    }
    catch {
        Write-Error "Failed to configure startup command: $_"
        exit 1
    }
}

# Function to deploy application
function Deploy-Application {
    Write-ColorOutput "Deploying application..." "Yellow"
    
    try {
        # Get the absolute path to source
        $absoluteSourcePath = Resolve-Path $SourcePath
        
        # Create deployment package
        $tempDir = Join-Path $env:TEMP "ship360-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        Write-ColorOutput "Creating deployment package in: $tempDir" "Cyan"
        
        # Copy application files
        Copy-Item -Path "$absoluteSourcePath\*" -Destination $tempDir -Recurse -Force
        
        # Ensure startup file is created for Azure App Service
        $webConfigPath = Join-Path $tempDir "web.config"
        $webConfigContent = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <system.webServer>
    <handlers>
      <add name="PythonHandler" path="*" verb="*" modules="httpPlatformHandler" resourceType="Unspecified"/>
    </handlers>
    <httpPlatform processPath="python" arguments="-m gunicorn -w 4 -k uvicorn.workers.UvicornWorker app.main:app --bind=0.0.0.0:%HTTP_PLATFORM_PORT% --timeout 600" stdoutLogEnabled="true" stdoutLogFile=".\python.log" startupTimeLimit="60" requestTimeout="00:10:00">
      <environmentVariables>
        <environmentVariable name="PORT" value="%HTTP_PLATFORM_PORT%" />
      </environmentVariables>
    </httpPlatform>
  </system.webServer>
</configuration>
"@
        Set-Content -Path $webConfigPath -Value $webConfigContent
        
        # Create ZIP package
        $zipPath = Join-Path $env:TEMP "ship360-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
        
        # Use PowerShell Compress-Archive if available, otherwise try other methods
        if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
            Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
        } else {
            # Fallback to using Azure CLI
            Push-Location $tempDir
            try {
                # Create a zip using tar (available on most systems)
                tar -czf $zipPath *
            } finally {
                Pop-Location
            }
        }
        
        Write-ColorOutput "✓ Deployment package created: $zipPath" "Green"
        
        # Deploy using Azure CLI
        Write-ColorOutput "Uploading and deploying application..." "Cyan"
        az webapp deploy `
            --name $AppServiceName `
            --resource-group $ResourceGroupName `
            --src-path $zipPath `
            --type zip `
            --output none
        
        Write-ColorOutput "✓ Application deployed successfully" "Green"
        
        # Clean up temporary files
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        
        Write-ColorOutput "✓ Temporary files cleaned up" "Green"
    }
    catch {
        Write-Error "Failed to deploy application: $_"
        exit 1
    }
}

# Function to test deployment
function Test-Deployment {
    Write-ColorOutput "Testing deployment..." "Yellow"
    
    try {
        # Get the app URL
        $appUrl = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --query "defaultHostName" --output tsv
        $fullUrl = "https://$appUrl"
        
        Write-ColorOutput "Application URL: $fullUrl" "Cyan"
        
        # Test health endpoint
        $healthUrl = "$fullUrl/"
        Write-ColorOutput "Testing health endpoint: $healthUrl" "Cyan"
        
        # Wait a moment for the app to start
        Start-Sleep -Seconds 30
        
        try {
            $response = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 30
            if ($response.status -eq "ok") {
                Write-ColorOutput "✓ Health check passed: $($response.message)" "Green"
            } else {
                Write-ColorOutput "⚠ Health check returned unexpected response" "Yellow"
            }
        }
        catch {
            Write-ColorOutput "⚠ Health check failed - this might be normal if the app is still starting up" "Yellow"
            Write-ColorOutput "  You can check the application logs in the Azure portal" "Yellow"
        }
        
        # Test API documentation endpoint
        $docsUrl = "$fullUrl/docs"
        Write-ColorOutput "API Documentation available at: $docsUrl" "Cyan"
        
        Write-ColorOutput "✓ Deployment testing completed" "Green"
        Write-ColorOutput "📝 Manual verification steps:" "Yellow"
        Write-ColorOutput "   1. Visit $fullUrl to check health endpoint" "White"
        Write-ColorOutput "   2. Visit $docsUrl to access API documentation" "White"
        Write-ColorOutput "   3. Test API endpoints using the Swagger UI" "White"
        Write-ColorOutput "   4. Check application logs in Azure Portal if issues occur" "White"
        
    }
    catch {
        Write-Error "Failed to test deployment: $_"
        exit 1
    }
}

# Main execution
function Main {
    Write-ColorOutput "🚀 Starting Ship360 Chat API deployment to Azure..." "Green"
    Write-ColorOutput "=================================================" "Green"
    
    try {
        Test-Prerequisites
        Set-AzureSubscription
        New-AzureResources
        Set-EnvironmentVariables
        Set-StartupCommand
        Deploy-Application
        Test-Deployment
        
        Write-ColorOutput "=================================================" "Green"
        Write-ColorOutput "🎉 Deployment completed successfully!" "Green"
        Write-ColorOutput "=================================================" "Green"
        
        # Display summary
        $appUrl = az webapp show --name $AppServiceName --resource-group $ResourceGroupName --query "defaultHostName" --output tsv
        Write-ColorOutput "📋 Deployment Summary:" "Cyan"
        Write-ColorOutput "   Resource Group: $ResourceGroupName" "White"
        Write-ColorOutput "   App Service: $AppServiceName" "White"
        Write-ColorOutput "   URL: https://$appUrl" "White"
        Write-ColorOutput "   API Docs: https://$appUrl/docs" "White"
        
    }
    catch {
        Write-Error "Deployment failed: $_"
        exit 1
    }
}

# Execute main function
Main