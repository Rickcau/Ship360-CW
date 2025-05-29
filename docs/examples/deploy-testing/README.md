# Ship360 Chat API - Azure Deployment Guide

This directory contains scripts and documentation for deploying the Ship360 Chat API (FastAPI application) to Azure App Service.

## Overview

The deployment script automates the process of deploying the Ship360 Chat API to Azure App Service, including:

- Creating Azure resources (Resource Group, App Service Plan, Web App)
- Configuring the Python runtime environment
- Setting up environment variables
- Deploying the FastAPI application
- Testing the deployment

## Testing the Deployment Script

Before deploying to Azure, you can validate the deployment script and check prerequisites:

### PowerShell Validation

```powershell
.\Test-DeploymentScript.ps1
```

This script will:
- Check PowerShell version compatibility
- Validate script syntax
- Verify required files exist
- Test environment file format
- Check for Azure CLI availability

### Expected Output

```
🧪 Testing Ship360 Chat API Deployment Script...
=================================================
✓ PowerShell version is sufficient
✓ Azure CLI available: 2.x.x
✓ All required files found
✓ All required environment variables found
✓ PowerShell syntax validation passed
✓ Required parameters properly defined
=================================================
🎉 All tests passed! Deployment script is ready.
```

## Files in This Directory

| File | Description |
|------|-------------|
| `Deploy-Ship360ChatAPI.ps1` | Main PowerShell deployment script |
| `deploy-ship360.sh` | Bash wrapper script for Linux/macOS users |
| `Test-DeploymentScript.ps1` | Validation script to test deployment script |
| `ship360-sample.env` | Sample environment variables file |
| `environment-schema.json` | JSON schema for validating environment variables |
| `README.md` | This documentation file |

## Prerequisites

### Software Requirements

1. **Azure CLI** - Version 2.0 or later
   ```bash
   # Install Azure CLI (Windows)
   winget install -e --id Microsoft.AzureCLI
   
   # Or download from: https://aka.ms/installazurecliwindows
   ```

2. **PowerShell** - Version 5.1 or later (PowerShell Core 7+ recommended)
   ```bash
   # Check PowerShell version
   $PSVersionTable.PSVersion
   ```

3. **Azure Subscription** - Active Azure subscription with appropriate permissions

### Azure Permissions Required

Your Azure account must have the following permissions in the target subscription:

- **Resource Group**: `Contributor` or `Owner` role
- **App Service**: `Contributor` or `Owner` role  
- **App Service Plan**: `Contributor` or `Owner` role

**Minimum required Azure roles:**
- `Contributor` role on the subscription, OR
- `Contributor` role on the target resource group (if it already exists)

### Azure Resource Requirements

The script will create the following Azure resources:

1. **Resource Group** (if it doesn't exist)
2. **App Service Plan** with Linux OS
3. **App Service (Web App)** with Python 3.11 runtime

## Setup Instructions

### 1. Clone and Navigate

```bash
# Navigate to the deployment directory
cd docs/examples/deploy-testing
```

### 2. Azure Login

```bash
# Login to Azure
az login

# Verify your subscription
az account show

# Set specific subscription (if needed)
az account set --subscription "your-subscription-id"
```

### 3. Prepare Environment Variables

Create an environment file (`.env`) with all required variables for the Ship360 Chat API:

```bash
# Copy the sample environment file
cp ../../../ship360-chat-api/.env_sample ./ship360.env
```

Edit the `ship360.env` file with your actual values:

```env
# Azure OpenAI configuration
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
AZURE_OPENAI_API_KEY=your_openai_api_key
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME=gpt-4o
AZURE_OPENAI_API_VERSION=2023-05-15

# Shipping 360 API configuration
SP360_TOKEN_URL=https://your-sp360-token-url
SP360_TOKEN_USERNAME=your_username
SP360_TOKEN_PASSWORD=your_password
SP360_RATE_SHOP_URL=https://your-rate-shop-url
SP360_SHIPMENTS_URL=https://your-shipments-url
SP360_TRACKING_URL=https://your-tracking-url
```

**⚠️ Security Note:** Never commit this file to version control. It contains sensitive credentials.

## Usage

### PowerShell Script (Windows/Linux/macOS)

#### Basic Deployment

```powershell
.\Deploy-Ship360ChatAPI.ps1 `
    -ResourceGroupName "rg-ship360-dev" `
    -AppServiceName "app-ship360-chat-dev" `
    -EnvironmentFile ".\ship360.env"
```

#### Advanced Deployment with Custom Settings

```powershell
.\Deploy-Ship360ChatAPI.ps1 `
    -ResourceGroupName "rg-ship360-prod" `
    -AppServiceName "app-ship360-chat-prod" `
    -Location "westus2" `
    -PricingTier "P1v2" `
    -EnvironmentFile ".\ship360-prod.env" `
    -SubscriptionId "your-subscription-id"
```

#### Deploy to Existing Resources

If you already have the Azure resources created:

```powershell
.\Deploy-Ship360ChatAPI.ps1 `
    -ResourceGroupName "existing-rg" `
    -AppServiceName "existing-app-service" `
    -EnvironmentFile ".\ship360.env" `
    -SkipResourceCreation
```

### Bash Wrapper Script (Linux/macOS/WSL)

For users who prefer bash, we provide a wrapper script:

#### Basic Deployment

```bash
./deploy-ship360.sh -g "rg-ship360-dev" -n "app-ship360-chat-dev" -e "./ship360.env"
```

#### Advanced Deployment

```bash
./deploy-ship360.sh \
    -g "rg-ship360-prod" \
    -n "app-ship360-chat-prod" \
    -e "./ship360-prod.env" \
    -l "westus2" \
    -t "P1v2" \
    -s "your-subscription-id"
```

#### Deploy to Existing Resources

```bash
./deploy-ship360.sh -g "existing-rg" -n "existing-app-service" -e "./ship360.env" --skip-resources
```

## Script Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `ResourceGroupName` | Yes | - | Name of the Azure Resource Group |
| `AppServiceName` | Yes | - | Name of the Azure App Service |
| `Location` | No | `eastus` | Azure region for resources |
| `AppServicePlanName` | No | `{AppServiceName}-plan` | Name of the App Service Plan |
| `PricingTier` | No | `B1` | App Service Plan pricing tier |
| `SubscriptionId` | No | Current | Azure subscription ID |
| `EnvironmentFile` | Yes | - | Path to environment variables file |
| `SourcePath` | No | `../../../ship360-chat-api` | Path to source code |
| `SkipResourceCreation` | No | `false` | Skip creating Azure resources |

## Pricing Tier Options

Choose the appropriate pricing tier based on your needs:

| Tier | CPU | RAM | Features | Recommended For |
|------|-----|-----|----------|----------------|
| `B1` | 1 core | 1.75 GB | Basic | Development/Testing |
| `B2` | 2 cores | 3.5 GB | Basic | Development/Testing |
| `S1` | 1 core | 1.75 GB | Standard, Auto-scale | Small Production |
| `S2` | 2 cores | 3.5 GB | Standard, Auto-scale | Medium Production |
| `P1v2` | 1 core | 3.5 GB | Premium, Slots | Production |
| `P2v2` | 2 cores | 7 GB | Premium, Slots | High-Load Production |

## Verification Steps

After deployment, verify your application:

### 1. Health Check
```bash
curl https://your-app-name.azurewebsites.net/
```

Expected response:
```json
{
  "status": "ok", 
  "message": "Service is running"
}
```

### 2. API Documentation
Visit: `https://your-app-name.azurewebsites.net/docs`

This should display the FastAPI Swagger UI documentation.

### 3. Test API Endpoint
```bash
curl -X POST "https://your-app-name.azurewebsites.net/api/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test@example.com",
    "sessionId": "test-session",
    "chatName": "Test Chat",
    "user_prompt": "Hello, what can you do?"
  }'
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   ```bash
   # Re-login to Azure
   az login
   az account set --subscription "your-subscription-id"
   ```

2. **App Service Name Already Taken**
   - App Service names must be globally unique
   - Try a different name or add a suffix (e.g., `-dev`, `-prod`, timestamp)

3. **Missing Environment Variables**
   - Verify all required variables are in your `.env` file
   - Check for typos in variable names
   - Ensure no empty values

4. **Application Not Starting**
   ```bash
   # Check application logs
   az webapp log tail --name your-app-name --resource-group your-rg
   
   # Download logs
   az webapp log download --name your-app-name --resource-group your-rg
   ```

5. **Timeout Issues**
   - Large deployments may take time
   - Check the Azure portal for deployment status
   - Increase timeout in script if needed

### Debugging Commands

```bash
# Check app service status
az webapp show --name your-app-name --resource-group your-rg --query "state"

# View app settings
az webapp config appsettings list --name your-app-name --resource-group your-rg

# Stream application logs
az webapp log tail --name your-app-name --resource-group your-rg

# Restart the app service
az webapp restart --name your-app-name --resource-group your-rg
```

## Security Considerations

1. **Environment Variables**
   - Store sensitive data in Azure Key Vault for production
   - Use managed identities when possible
   - Never commit `.env` files to version control

2. **Network Security**
   - Consider using Private Endpoints for production
   - Implement IP restrictions if needed
   - Use Azure Application Gateway for additional security

3. **Authentication**
   - Enable Azure AD authentication for production
   - Implement API key authentication
   - Use HTTPS only (enforced by default)

## Cost Optimization

1. **Development/Testing**
   - Use `B1` tier for development
   - Stop app service when not in use
   - Use shared App Service Plans for multiple apps

2. **Production**
   - Monitor usage and scale accordingly
   - Use auto-scaling rules
   - Consider Reserved Instances for predictable workloads

## Maintenance

### Regular Tasks

1. **Monitor Application**
   - Set up Application Insights
   - Monitor performance metrics
   - Set up alerts for errors

2. **Updates**
   - Keep dependencies updated
   - Monitor security advisories
   - Test updates in development first

3. **Backup**
   - Enable automatic backups
   - Test restore procedures
   - Keep environment configuration backed up

## Support

### Azure Resources
- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)
- [Python on App Service](https://docs.microsoft.com/en-us/azure/app-service/quickstart-python)

### FastAPI Resources
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Deploying FastAPI to Azure](https://fastapi.tiangolo.com/deployment/azure/)

### Getting Help
1. Check Azure Service Health
2. Review application logs
3. Search Azure documentation
4. Contact Azure Support for infrastructure issues

## Sample Environment Files

### Development Environment (`ship360-dev.env`)
```env
# Azure OpenAI configuration
AZURE_OPENAI_ENDPOINT=https://your-dev-openai.openai.azure.com/
AZURE_OPENAI_API_KEY=dev_api_key_here
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME=gpt-4o
AZURE_OPENAI_API_VERSION=2023-05-15

# Ship360 API configuration (dev endpoints)
SP360_TOKEN_URL=https://dev-api.ship360.com/token
SP360_TOKEN_USERNAME=dev_username
SP360_TOKEN_PASSWORD=dev_password
SP360_RATE_SHOP_URL=https://dev-api.ship360.com/rates
SP360_SHIPMENTS_URL=https://dev-api.ship360.com/shipments
SP360_TRACKING_URL=https://dev-api.ship360.com/tracking
```

### Production Environment (`ship360-prod.env`)
```env
# Azure OpenAI configuration
AZURE_OPENAI_ENDPOINT=https://your-prod-openai.openai.azure.com/
AZURE_OPENAI_API_KEY=prod_api_key_here
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME=gpt-4o
AZURE_OPENAI_API_VERSION=2023-05-15

# Ship360 API configuration (prod endpoints)
SP360_TOKEN_URL=https://api.ship360.com/token
SP360_TOKEN_USERNAME=prod_username
SP360_TOKEN_PASSWORD=prod_password
SP360_RATE_SHOP_URL=https://api.ship360.com/rates
SP360_SHIPMENTS_URL=https://api.ship360.com/shipments
SP360_TRACKING_URL=https://api.ship360.com/tracking
```

## License

This deployment script is provided as-is for the Ship360 project. See the main project license for terms and conditions.