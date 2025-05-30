# Ship360 Chat API - Simplified Deployment Script
# This script provides a streamlined deployment process with professional output handling
# Created as requested in issue #22

param(
    [Parameter(Position=0)]
    [ValidateSet("help", "deploy", "update", "status")]
    [string]$Command = "help",
    
    [Parameter()]
    [string]$ResourceGroup,
    
    [Parameter()]
    [string]$Location = "eastus"
)

# Generate a random 3-character suffix for uniqueness
$RandomSuffix = -join ((97..122) | Get-Random -Count 3 | ForEach-Object {[char]$_})

# Azure Configuration - Load from environment variables with defaults
$RESOURCE_GROUP = if ($ResourceGroup) { $ResourceGroup } elseif ($env:AZURE_RESOURCE_GROUP) { $env:AZURE_RESOURCE_GROUP } else { "rg-ship360-chat-api-$RandomSuffix" }
$LOCATION = if ($env:AZURE_LOCATION) { $env:AZURE_LOCATION } else { $Location }
$ACR_NAME = if ($env:AZURE_ACR_NAME) { $env:AZURE_ACR_NAME } else { "acrship360chat$RandomSuffix" }
$CONTAINER_APP_ENV = if ($env:AZURE_CONTAINER_APP_ENV) { $env:AZURE_CONTAINER_APP_ENV } else { "ship360-chat-env-$RandomSuffix" }
$CONTAINER_APP_NAME = if ($env:AZURE_CONTAINER_APP_NAME) { $env:AZURE_CONTAINER_APP_NAME } else { "ship360-chat-api-$RandomSuffix" }
$IMAGE_NAME = "ship360-chat-api"
$IMAGE_TAG = "latest"

#region Output Formatting Functions
function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Blue
    Write-Host " $Title" -ForegroundColor Blue
    Write-Host ("=" * 60) -ForegroundColor Blue
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "⚡ $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-SubStep {
    param([string]$Message)
    Write-Host "   └─ $Message" -ForegroundColor Gray
}
#endregion

#region Utility Functions
function Test-AzureCLI {
    try {
        $null = az --version 2>$null
        return $true
    }
    catch {
        return $false
    }
}

function Test-EnvFile {
    if (Test-Path "ship360-chat-api/.env") {
        return $true
    }
    elseif (Test-Path ".env") {
        return $true
    }
    return $false
}

function Load-EnvFile {
    $envPath = ""
    if (Test-Path "ship360-chat-api/.env") {
        $envPath = "ship360-chat-api/.env"
    }
    elseif (Test-Path ".env") {
        $envPath = ".env"
    }
    
    if ($envPath) {
        Get-Content $envPath | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                # Remove quotes if present
                $value = $value -replace '^["'']|["'']$', ''
                [Environment]::SetEnvironmentVariable($name, $value, "Process")
            }
        }
        Write-Success "Environment variables loaded from $envPath"
    } else {
        Write-Warning ".env file not found! Using default values."
    }
}

function Test-AzureLogin {
    try {
        $account = az account show --query "name" --output tsv 2>$null
        if ($account) {
            Write-Success "Already logged into Azure: $account"
            return $true
        }
    }
    catch {
        return $false
    }
    return $false
}

function Show-DeploymentSummary {
    param([string]$ResourceGroup, [string]$ContainerAppName)
    
    Write-Header "Deployment Summary"
    
    Write-Info "Resource Group: $ResourceGroup"
    Write-Info "Container App: $ContainerAppName"
    Write-Info "Location: $LOCATION"
    
    try {
        $fqdn = az containerapp show --name $ContainerAppName --resource-group $ResourceGroup --query properties.configuration.ingress.fqdn --output tsv 2>$null
        if ($fqdn) {
            Write-Success "Application URL: https://$fqdn"
            Write-Info "API Documentation: https://$fqdn/docs"
            Write-Info "Health Check: https://$fqdn/"
        }
    }
    catch {
        Write-Warning "Could not retrieve application URL"
    }
}
#endregion

#region Command Functions
function Show-Help {
    Write-Header "Ship360 Chat API - New Deployment Script"
    
    Write-Host "DESCRIPTION:" -ForegroundColor Blue
    Write-Host "  Simplified deployment script with professional output handling" -ForegroundColor Gray
    Write-Host "  Combines working logic with clean, formatted output" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "COMMANDS:" -ForegroundColor Blue
    Write-Host "  deploy              Deploy new Ship360 Chat API to Azure Container Apps" -ForegroundColor Gray
    Write-Host "  update              Update existing deployment with latest code" -ForegroundColor Gray
    Write-Host "  status              Check status of deployed resources" -ForegroundColor Gray
    Write-Host "  help                Show this help message" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "OPTIONS:" -ForegroundColor Blue
    Write-Host "  -ResourceGroup      Specify custom resource group name" -ForegroundColor Gray
    Write-Host "  -Location           Specify Azure region (default: eastus)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "EXAMPLES:" -ForegroundColor Blue
    Write-Host "  .\new-deploy.ps1 deploy" -ForegroundColor Cyan
    Write-Host "  .\new-deploy.ps1 deploy -ResourceGroup 'rg-myapp-prod'" -ForegroundColor Cyan
    Write-Host "  .\new-deploy.ps1 update" -ForegroundColor Cyan
    Write-Host "  .\new-deploy.ps1 status" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "REQUIREMENTS:" -ForegroundColor Blue
    Write-Host "  • Azure CLI installed and authenticated" -ForegroundColor Gray
    Write-Host "  • .env file with required environment variables" -ForegroundColor Gray
    Write-Host "  • Run from repository root directory" -ForegroundColor Gray
}

function Invoke-Deploy {
    Write-Header "Starting Ship360 Chat API Deployment"
    
    # Pre-flight checks
    Write-Step "Performing pre-flight checks..."
    
    if (!(Test-AzureCLI)) {
        Write-Error "Azure CLI is not installed or not in PATH"
        Write-Info "Install with: winget install Microsoft.AzureCLI"
        exit 1
    }
    Write-SubStep "Azure CLI: Available"
    
    if (!(Test-EnvFile)) {
        Write-Warning "No .env file found - using default configuration"
    }
    Load-EnvFile
    
    if (!(Test-AzureLogin)) {
        Write-Step "Logging into Azure..."
        az login
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Azure login failed"
            exit 1
        }
    }
    
    Write-Success "Pre-flight checks completed"
    
    # Display configuration
    Write-Header "Deployment Configuration"
    Write-Info "Resource Group: $RESOURCE_GROUP"
    Write-Info "Location: $LOCATION"
    Write-Info "ACR Name: $ACR_NAME"
    Write-Info "Container App Environment: $CONTAINER_APP_ENV"
    Write-Info "Container App Name: $CONTAINER_APP_NAME"
    Write-Info "Random Suffix: $RandomSuffix"
    
    # Register providers
    Write-Step "Registering Azure resource providers..."
    az provider register --namespace Microsoft.ContainerRegistry --wait
    az provider register --namespace Microsoft.App --wait
    az provider register --namespace Microsoft.OperationalInsights --wait
    Write-Success "Resource providers registered"
    
    # Create resource group
    Write-Step "Creating resource group..."
    az group create --name $RESOURCE_GROUP --location $LOCATION --output none
    Write-Success "Resource group '$RESOURCE_GROUP' created"
    
    # Create ACR
    Write-Step "Creating Azure Container Registry..."
    az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true --output none
    Write-Success "Container Registry '$ACR_NAME' created"
    
    # Create Container App Environment
    Write-Step "Creating Container App Environment..."
    az containerapp env create --name $CONTAINER_APP_ENV --resource-group $RESOURCE_GROUP --location $LOCATION --output none
    Write-Success "Container App Environment '$CONTAINER_APP_ENV' created"
    
    # Build and push image
    Write-Step "Building and pushing container image..."
    Write-SubStep "Building image: ${IMAGE_NAME}:${IMAGE_TAG}"
    Push-Location ship360-chat-api
    try {
        az acr build --registry $ACR_NAME --image "${IMAGE_NAME}:${IMAGE_TAG}" . --output none
        Write-Success "Container image built and pushed"
    }
    finally {
        Pop-Location
    }
    
    # Get ACR credentials
    Write-Step "Retrieving container registry credentials..."
    $ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --query loginServer --output tsv
    $ACR_USERNAME = az acr credential show --name $ACR_NAME --query username --output tsv
    $ACR_PASSWORD = az acr credential show --name $ACR_NAME --query "passwords[0].value" --output tsv
    Write-Success "Registry credentials retrieved"
    
    # Deploy Container App
    Write-Step "Deploying to Azure Container Apps..."
    az containerapp create `
        --name $CONTAINER_APP_NAME `
        --resource-group $RESOURCE_GROUP `
        --environment $CONTAINER_APP_ENV `
        --image "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" `
        --target-port 8000 `
        --ingress 'external' `
        --registry-server $ACR_LOGIN_SERVER `
        --registry-username $ACR_USERNAME `
        --registry-password $ACR_PASSWORD `
        --cpu 0.5 `
        --memory 1.0 `
        --min-replicas 1 `
        --max-replicas 3 `
        --system-assigned `
        --env-vars `
            PROJECT_NAME="Chat API" `
            API_PREFIX="/api" `
            DEBUG="false" `
            ENVIRONMENT="production" `
            LOG_LEVEL="$env:LOG_LEVEL" `
            AZURE_OPENAI_API_KEY="$env:AZURE_OPENAI_API_KEY" `
            AZURE_OPENAI_ENDPOINT="$env:AZURE_OPENAI_ENDPOINT" `
            AZURE_OPENAI_API_VERSION="$env:AZURE_OPENAI_API_VERSION" `
            AZURE_OPENAI_CHAT_DEPLOYMENT_NAME="$env:AZURE_OPENAI_CHAT_DEPLOYMENT_NAME" `
            MASTER_AGENT_DEPLOYMENT="$env:MASTER_AGENT_DEPLOYMENT" `
            INTENT_AGENT_DEPLOYMENT="$env:INTENT_AGENT_DEPLOYMENT" `
            RATE_AGENT_DEPLOYMENT="$env:RATE_AGENT_DEPLOYMENT" `
            LABEL_AGENT_DEPLOYMENT="$env:LABEL_AGENT_DEPLOYMENT" `
            TRACKING_AGENT_DEPLOYMENT="$env:TRACKING_AGENT_DEPLOYMENT" `
            SP360_TOKEN_URL="$env:SP360_TOKEN_URL" `
            SP360_TOKEN_USERNAME="$env:SP360_TOKEN_USERNAME" `
            SP360_TOKEN_PASSWORD="$env:SP360_TOKEN_PASSWORD" `
            SP360_RATE_SHOP_URL="$env:SP360_RATE_SHOP_URL" `
            SP360_SHIPMENTS_URL="$env:SP360_SHIPMENTS_URL" `
            SP360_TRACKING_URL="$env:SP360_TRACKING_URL" `
        --output none
    
    Write-Success "Container App deployed successfully"
    
    # Show deployment summary
    Show-DeploymentSummary -ResourceGroup $RESOURCE_GROUP -ContainerAppName $CONTAINER_APP_NAME
    
    Write-Header "Deployment Complete! 🎉"
}

function Invoke-Update {
    Write-Header "Updating Ship360 Chat API Deployment"
    
    # Pre-flight checks
    Write-Step "Performing pre-flight checks..."
    
    if (!(Test-AzureCLI)) {
        Write-Error "Azure CLI is not installed or not in PATH"
        exit 1
    }
    
    Load-EnvFile
    
    if (!(Test-AzureLogin)) {
        Write-Step "Logging into Azure..."
        az login
    }
    
    Write-Success "Pre-flight checks completed"
    
    # Build and push new image
    Write-Step "Building and pushing updated container image..."
    Push-Location ship360-chat-api
    try {
        az acr build --registry $ACR_NAME --image "${IMAGE_NAME}:${IMAGE_TAG}" . --output none
        Write-Success "Updated container image built and pushed"
    }
    finally {
        Pop-Location
    }
    
    # Update Container App
    Write-Step "Updating Container App deployment..."
    $ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --query loginServer --output tsv
    az containerapp update `
        --name $CONTAINER_APP_NAME `
        --resource-group $RESOURCE_GROUP `
        --image "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" `
        --output none
    
    Write-Success "Container App updated successfully"
    
    # Show deployment summary
    Show-DeploymentSummary -ResourceGroup $RESOURCE_GROUP -ContainerAppName $CONTAINER_APP_NAME
    
    Write-Header "Update Complete! 🎉"
}

function Show-Status {
    Write-Header "Ship360 Chat API Deployment Status"
    
    Load-EnvFile
    
    if (!(Test-AzureLogin)) {
        Write-Step "Logging into Azure..."
        az login
    }
    
    Write-Step "Checking resource status..."
    
    # Check resource group
    $rgExists = az group exists --name $RESOURCE_GROUP
    if ($rgExists -eq "true") {
        Write-Success "Resource Group: $RESOURCE_GROUP (Exists)"
    } else {
        Write-Error "Resource Group: $RESOURCE_GROUP (Not Found)"
        return
    }
    
    # Check Container App
    try {
        $appStatus = az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --query "properties.provisioningState" --output tsv 2>$null
        if ($appStatus) {
            Write-Success "Container App: $CONTAINER_APP_NAME ($appStatus)"
            
            # Get app URL
            $fqdn = az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --query properties.configuration.ingress.fqdn --output tsv
            if ($fqdn) {
                Write-Info "Application URL: https://$fqdn"
                
                # Test health endpoint
                try {
                    $response = Invoke-WebRequest -Uri "https://$fqdn/" -TimeoutSec 10 -UseBasicParsing
                    if ($response.StatusCode -eq 200) {
                        Write-Success "Health Check: API is responding"
                    }
                }
                catch {
                    Write-Warning "Health Check: API may be starting up"
                }
            }
        } else {
            Write-Error "Container App: $CONTAINER_APP_NAME (Not Found)"
        }
    }
    catch {
        Write-Error "Container App: $CONTAINER_APP_NAME (Not Found)"
    }
    
    # Check ACR
    try {
        $acrStatus = az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "provisioningState" --output tsv 2>$null
        if ($acrStatus) {
            Write-Success "Container Registry: $ACR_NAME ($acrStatus)"
        } else {
            Write-Error "Container Registry: $ACR_NAME (Not Found)"
        }
    }
    catch {
        Write-Error "Container Registry: $ACR_NAME (Not Found)"
    }
}
#endregion

#region Main Execution
switch ($Command) {
    "help" {
        Show-Help
    }
    
    "deploy" {
        Invoke-Deploy
    }
    
    "update" {
        Invoke-Update
    }
    
    "status" {
        Show-Status
    }
    
    default {
        Write-Error "Unknown command: $Command"
        Show-Help
        exit 1
    }
}
#endregion