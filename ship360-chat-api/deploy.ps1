# Ship360 Chat API - PowerShell Deployment Script
# This script provides automated deployment commands for Azure Container Apps

param(
    [Parameter(Position=0)]
    [ValidateSet("help", "deploy-containerapp", "deploy-with-apim", "update-containerapp")]
    [string]$Command = "help",
    
    [Parameter()]
    [string]$ResourceGroup
)

# Generate a random 3-character suffix for uniqueness
$RandomSuffix = -join ((97..122) | Get-Random -Count 3 | ForEach-Object {[char]$_})

# Azure Configuration - Load from environment variables with defaults
# Command line parameter takes precedence over environment variable
$RESOURCE_GROUP = if ($ResourceGroup) { $ResourceGroup } elseif ($env:AZURE_RESOURCE_GROUP) { $env:AZURE_RESOURCE_GROUP } else { "rg-ship360-chat-api-$RandomSuffix" }
$LOCATION = if ($env:AZURE_LOCATION) { $env:AZURE_LOCATION } else { "eastus" }
$ACR_NAME = if ($env:AZURE_ACR_NAME) { $env:AZURE_ACR_NAME } else { "acrship360chat$RandomSuffix" }
$CONTAINER_APP_ENV = if ($env:AZURE_CONTAINER_APP_ENV) { $env:AZURE_CONTAINER_APP_ENV } else { "ship360-chat-env-$RandomSuffix" }
$CONTAINER_APP_NAME = if ($env:AZURE_CONTAINER_APP_NAME) { $env:AZURE_CONTAINER_APP_NAME } else { "ship360-chat-api-$RandomSuffix" }
$IMAGE_NAME = "ship360-chat-api"
$IMAGE_TAG = "latest"

# APIM Configuration - Load from environment variables with defaults
$APIM_NAME = if ($env:AZURE_APIM_NAME) { $env:AZURE_APIM_NAME } else { "apim-ship360-chat-$RandomSuffix" }
$APIM_SKU = if ($env:AZURE_APIM_SKU) { $env:AZURE_APIM_SKU } else { "Standard" }
$APIM_PUBLISHER_NAME = if ($env:AZURE_APIM_PUBLISHER_NAME) { $env:AZURE_APIM_PUBLISHER_NAME } else { "Ship360" }
$APIM_PUBLISHER_EMAIL = if ($env:AZURE_APIM_PUBLISHER_EMAIL) { $env:AZURE_APIM_PUBLISHER_EMAIL } else { "admin@ship360.com" }
$APIM_API_NAME = if ($env:AZURE_APIM_API_NAME) { $env:AZURE_APIM_API_NAME } else { "ship360-chat-api" }
$APIM_API_PATH = if ($env:AZURE_APIM_API_PATH) { $env:AZURE_APIM_API_PATH } else { "ship360-chat" }

# Colors for output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    switch ($Color) {
        "Green" { Write-Host $Message -ForegroundColor Green }
        "Yellow" { Write-Host $Message -ForegroundColor Yellow }
        "Red" { Write-Host $Message -ForegroundColor Red }
        "Cyan" { Write-Host $Message -ForegroundColor Cyan }
        "Gray" { Write-Host $Message -ForegroundColor Gray }
        default { Write-Host $Message }
    }
}


# Function to check if Azure CLI is installed
function Test-AzureCLI {
    try {
        az --version | Out-Null 2>&1
        return $true
    }
    catch {
        return $false
    }
}

# Function to load environment variables from .env file
function Load-EnvFile {
    if (Test-Path .env) {
        Get-Content .env | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                # Remove quotes if present
                $value = $value -replace '^["'']|["'']$', ''
                [Environment]::SetEnvironmentVariable($name, $value, "Process")
            }
        }
        Write-ColorOutput "Environment variables loaded from .env file" "Green"
    } else {
        Write-ColorOutput "Warning: .env file not found!" "Yellow"
    }
}

# Function to check if .env file exists
function Test-EnvFile {
    if (!(Test-Path .env)) {
        Write-ColorOutput "Error: .env file not found!" "Red"
        Write-ColorOutput "Please copy .env.example to .env and fill in your values:" "Yellow"
        Write-ColorOutput "Copy-Item .env.example .env" "Gray"
        return $false
    }
    Write-ColorOutput ".env file found" "Green"
    return $true
}


# Show help
function Show-Help {
    Write-ColorOutput "Ship360 Chat API - Deployment Commands:" "Cyan"
    Write-Host ""
    Write-ColorOutput "Main Commands:" "Yellow"
    Write-ColorOutput "  deploy-containerapp    Deploy solution with Container Apps only" "Gray"
    Write-ColorOutput "  deploy-with-apim      Deploy solution with Container Apps and API Management" "Gray"
    Write-ColorOutput "  update-containerapp   Update existing Container App deployment" "Gray"
    Write-ColorOutput "  help                  Show this help message" "Gray"
    Write-Host ""
    Write-ColorOutput "Options:" "Yellow"
    Write-ColorOutput "  -ResourceGroup        Specify custom resource group name" "Gray"
    Write-Host ""
    Write-ColorOutput "Examples:" "Yellow"
    Write-ColorOutput "  .\deploy.ps1 deploy-containerapp" "Gray"
    Write-ColorOutput "  .\deploy.ps1 deploy-with-apim" "Gray"
    Write-ColorOutput "  .\deploy.ps1 update-containerapp" "Gray"
    Write-ColorOutput "  .\deploy.ps1 deploy-containerapp -ResourceGroup 'rg-myapp-prod'" "Gray"
}

# Execute commands
switch ($Command) {
    "help" {
        Show-Help
    }
    
    "deploy-containerapp" {
        if (!(Test-EnvFile)) { exit 1 }
        Load-EnvFile
        
        if (!(Test-AzureCLI)) {
            Write-ColorOutput "Azure CLI is not installed. Please install it first:" "Red"
            Write-ColorOutput "winget install Microsoft.AzureCLI" "Cyan"
            exit 1
        }
        
        Write-ColorOutput "Starting Container Apps deployment..." "Green"
        Write-ColorOutput "Using resource names with suffix: $RandomSuffix" "Yellow"
        Write-ColorOutput "  Resource Group: $RESOURCE_GROUP" "Gray"
        Write-ColorOutput "  ACR Name: $ACR_NAME" "Gray"
        Write-ColorOutput "  Container App: $CONTAINER_APP_NAME" "Gray"
        
        # Login to Azure
        Write-ColorOutput "Logging into Azure..." "Yellow"
        az login
        
        # Register required providers
        Write-ColorOutput "Registering required Azure resource providers..." "Yellow"
        az provider register --namespace Microsoft.ContainerRegistry --wait
        az provider register --namespace Microsoft.App --wait
        az provider register --namespace Microsoft.OperationalInsights --wait
        
        # Create resources
        Write-ColorOutput "Creating Azure resources..." "Yellow"
        az group create --name $RESOURCE_GROUP --location $LOCATION
        az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true
        az containerapp env create --name $CONTAINER_APP_ENV --resource-group $RESOURCE_GROUP --location $LOCATION
        
        # Build and push image
        Write-ColorOutput "Building and pushing image to ACR..." "Yellow"
        az acr build --registry $ACR_NAME --image "${IMAGE_NAME}:${IMAGE_TAG}" .
        
        # Get ACR credentials
        $ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --query loginServer --output tsv
        $ACR_USERNAME = az acr credential show --name $ACR_NAME --query username --output tsv
        $ACR_PASSWORD = az acr credential show --name $ACR_NAME --query "passwords[0].value" --output tsv
        
        # Deploy Container App
        Write-ColorOutput "Deploying to Azure Container Apps..." "Green"
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
                SP360_TRACKING_URL="$env:SP360_TRACKING_URL"
        
        # Show URL
        Write-ColorOutput "Deployment complete!" "Green"
        Write-ColorOutput "Container App URL:" "Green"
        $fqdn = az containerapp show `
            --name $CONTAINER_APP_NAME `
            --resource-group $RESOURCE_GROUP `
            --query properties.configuration.ingress.fqdn `
            --output tsv
        Write-ColorOutput "https://$fqdn" "Cyan"
    }
    
    "deploy-with-apim" {
        if (!(Test-EnvFile)) { exit 1 }
        Load-EnvFile
        
        if (!(Test-AzureCLI)) {
            Write-ColorOutput "Azure CLI is not installed. Please install it first:" "Red"
            Write-ColorOutput "winget install Microsoft.AzureCLI" "Cyan"
            exit 1
        }
        
        Write-ColorOutput "Starting deployment with Container Apps and API Management..." "Green"
        
        # First deploy Container App
        & $PSCommandPath deploy-containerapp
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        
        # Create APIM instance
        Write-ColorOutput "Creating API Management instance..." "Yellow"
        Write-ColorOutput "This may take 30-45 minutes to complete." "Yellow"
        
        # Register API Management resource provider
        az provider register --namespace Microsoft.ApiManagement --wait
        
        # Create APIM instance
        az apim create `
            --name $APIM_NAME `
            --resource-group $RESOURCE_GROUP `
            --location $LOCATION `
            --sku-name $APIM_SKU `
            --sku-capacity 1 `
            --publisher-name $APIM_PUBLISHER_NAME `
            --publisher-email $APIM_PUBLISHER_EMAIL `
            --no-wait
        
        Write-ColorOutput "APIM creation initiated. Waiting for provisioning..." "Yellow"
        do {
            Start-Sleep 120
            $provisioningState = az apim show --name $APIM_NAME --resource-group $RESOURCE_GROUP --query provisioningState --output tsv 2>$null
            Write-ColorOutput "APIM provisioning state: $provisioningState" "Cyan"
        } while ($provisioningState -eq "InProgress")
        
        if ($provisioningState -ne "Succeeded") {
            Write-ColorOutput "APIM provisioning failed with state: $provisioningState" "Red"
            exit 1
        }
        
        # Import API
        Write-ColorOutput "Importing Container App API into APIM..." "Yellow"
        $CONTAINER_APP_URL = az containerapp show `
            --name $CONTAINER_APP_NAME `
            --resource-group $RESOURCE_GROUP `
            --query properties.configuration.ingress.fqdn `
            --output tsv
        
        $OPENAPI_URL = "https://$CONTAINER_APP_URL/openapi.json"
        
        az apim api import `
            --resource-group $RESOURCE_GROUP `
            --service-name $APIM_NAME `
            --api-id $APIM_API_NAME `
            --path $APIM_API_PATH `
            --display-name "Ship360 Chat API" `
            --description "Ship360 Chat API powered by Azure OpenAI" `
            --specification-url $OPENAPI_URL `
            --specification-format OpenApi `
            --service-url "https://$CONTAINER_APP_URL"
        
        # Create product and subscription
        az apim product create `
            --resource-group $RESOURCE_GROUP `
            --service-name $APIM_NAME `
            --product-id "ship360-chat-product" `
            --product-name "Ship360 Chat API" `
            --description "Ship360 Chat API Product" `
            --subscription-required true `
            --approval-required false `
            --state published
        
        az apim product api add `
            --resource-group $RESOURCE_GROUP `
            --service-name $APIM_NAME `
            --product-id "ship360-chat-product" `
            --api-id $APIM_API_NAME
        
        az apim product subscription create `
            --resource-group $RESOURCE_GROUP `
            --service-name $APIM_NAME `
            --product-id "ship360-chat-product" `
            --subscription-id "ship360-chat-subscription" `
            --name "Ship360 Chat API Subscription" `
            --state active
        
        # Show results
        Write-ColorOutput "Deployment with APIM complete!" "Green"
        $gatewayUrl = az apim show `
            --name $APIM_NAME `
            --resource-group $RESOURCE_GROUP `
            --query gatewayUrl `
            --output tsv
        
        Write-ColorOutput "APIM Gateway URL: $gatewayUrl" "Cyan"
        Write-ColorOutput "API URL: $gatewayUrl/$APIM_API_PATH" "Cyan"
        
        # Get subscription key
        $subscriptionKey = az apim product subscription show `
            --resource-group $RESOURCE_GROUP `
            --service-name $APIM_NAME `
            --product-id "ship360-chat-product" `
            --subscription-id "ship360-chat-subscription" `
            --query primaryKey `
            --output tsv
        
        Write-ColorOutput "Subscription Key: $subscriptionKey" "Green"
        Write-ColorOutput "Use this key in the 'Ocp-Apim-Subscription-Key' header for API calls." "Yellow"
    }
    
    "update-containerapp" {
        if (!(Test-EnvFile)) { exit 1 }
        Load-EnvFile
        
        if (!(Test-AzureCLI)) {
            Write-ColorOutput "Azure CLI is not installed. Please install it first:" "Red"
            Write-ColorOutput "winget install Microsoft.AzureCLI" "Cyan"
            exit 1
        }
        
        Write-ColorOutput "Logging into Azure..." "Yellow"
        az login
        
        # Build and push new image
        Write-ColorOutput "Building and pushing image to ACR..." "Yellow"
        az acr build --registry $ACR_NAME --image "${IMAGE_NAME}:${IMAGE_TAG}" .
        
        # Update Container App
        Write-ColorOutput "Updating Container App..." "Green"
        $ACR_LOGIN_SERVER = az acr show --name $ACR_NAME --query loginServer --output tsv
        az containerapp update `
            --name $CONTAINER_APP_NAME `
            --resource-group $RESOURCE_GROUP `
            --image "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
        
        Write-ColorOutput "Update complete!" "Green"
        $fqdn = az containerapp show `
            --name $CONTAINER_APP_NAME `
            --resource-group $RESOURCE_GROUP `
            --query properties.configuration.ingress.fqdn `
            --output tsv
        Write-ColorOutput "Container App URL: https://$fqdn" "Cyan"
    }
    
    default {
        Write-ColorOutput "Unknown command: $Command" "Red"
        Show-Help
        exit 1
    }
}
