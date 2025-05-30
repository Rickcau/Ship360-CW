# Ship360 Chat API - Azure Deployment

This directory contains scripts for deploying the Ship360 Chat API to Azure App Service.

## Overview

The `Deploy-Ship360ChatAPI.ps1` script automates the process of deploying the FastAPI application to Azure App Service. It handles resource creation, environment configuration, and application deployment in a single command.

## Prerequisites

Before using this script, ensure you have:

1. **Azure CLI** installed and configured
   ```
   # Windows (PowerShell Admin)
   winget install Microsoft.AzureCLI
   
   # macOS
   brew install azure-cli
   
   # Ubuntu/Debian
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

2. **PowerShell Core** (pwsh) 7.0 or higher
   ```
   # Windows (PowerShell Admin)
   winget install Microsoft.PowerShell
   
   # macOS
   brew install --cask powershell
   
   # Ubuntu/Debian
   sudo apt-get install -y wget apt-transport-https software-properties-common
   wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
   sudo dpkg -i packages-microsoft-prod.deb
   sudo apt-get update
   sudo apt-get install -y powershell
   ```

3. **Azure Account** with appropriate permissions:
   - Contributor role on the subscription or
   - Owner role on the resource group (if it already exists)
   - Ability to create/manage:
     - Resource Groups
     - App Service Plans
     - App Services
     - App Settings

4. **Environment Variables** configured in a `.env` file (see `ship360-sample.env`)

## Required Permissions

To successfully deploy using this script, you need the following Azure permissions:

| Resource Type | Permission Level | Azure RBAC Role |
|---------------|------------------|-----------------|
| Subscription | Read | Reader |
| Resource Group | Create/Manage | Contributor or Owner |
| App Service Plan | Create/Manage | Contributor or Owner |
| App Service | Create/Manage/Deploy | Contributor or Owner |
| App Settings | Create/Manage | Contributor or Owner |

The simplest approach is to have **Contributor** access to the subscription or resource group.

## Usage

### Basic Deployment

```powershell
# Login to Azure (if not already logged in)
az login

# Deploy with minimal parameters
./Deploy-Ship360ChatAPI.ps1 -ResourceGroupName "rg-ship360-dev" -AppServiceName "app-ship360-chat-dev" -EnvironmentFile "./ship360-sample.env"
```

### Advanced Options

```powershell
# Deploy to a specific Azure region with custom tier
./Deploy-Ship360ChatAPI.ps1 -ResourceGroupName "rg-ship360-prod" `
                           -AppServiceName "app-ship360-chat-prod" `
                           -Location "westus2" `
                           -PricingTier "P1v2" `
                           -EnvironmentFile "./ship360-prod.env"

# Skip resource creation (deploy to existing resources only)
./Deploy-Ship360ChatAPI.ps1 -ResourceGroupName "rg-ship360-dev" `
                           -AppServiceName "app-ship360-chat-dev" `
                           -EnvironmentFile "./ship360-sample.env" `
                           -SkipResourceCreation

# Enable debug mode for troubleshooting
./Deploy-Ship360ChatAPI.ps1 -ResourceGroupName "rg-ship360-dev" `
                           -AppServiceName "app-ship360-chat-dev" `
                           -EnvironmentFile "./ship360-sample.env" `
                           -DebugMode
```

### For Bash Users

A bash wrapper script is provided for Linux/macOS users:

```bash
# Make the script executable
chmod +x ./deploy-ship360.sh

# Deploy with default parameters
./deploy-ship360.sh --resource-group "rg-ship360-dev" --name "app-ship360-chat-dev" 

# Show help
./deploy-ship360.sh --help
```

## Testing the Script

Before deploying to Azure, you can test the script to ensure it's working correctly:

```powershell
# Run the test script
./Test-DeploymentScript.ps1
```

This will:
- Validate the PowerShell syntax
- Check for required dependencies
- Verify environment file structure
- Run a mock deployment test without creating actual resources

## Environment Variables

The following environment variables should be configured in your `.env` file:

| Variable | Description | Required |
|----------|-------------|----------|
| PROJECT_NAME | Name of the FastAPI application | Yes |
| API_PREFIX | Prefix for API routes | No |
| DEBUG | Enable debug mode (true/false) | No |
| ENVIRONMENT | Deployment environment (production/development) | No |
| LOG_LEVEL | Logging level (debug/info/warning/error) | No |
| AZURE_OPENAI_API_KEY | Azure OpenAI API key | Yes |
| AZURE_OPENAI_ENDPOINT | Azure OpenAI service endpoint | Yes |
| AZURE_OPENAI_API_VERSION | Azure OpenAI API version | Yes |
| AZURE_OPENAI_CHAT_DEPLOYMENT_NAME | OpenAI model deployment name | Yes |
| Other Agent Deployments | Various agent deployment names | Yes |
| SP360_* | Ship360 API connection details | Yes |

See `ship360-sample.env` for a complete template.

## Troubleshooting

### Common Issues

1. **Deployment Timeouts**
   - Large Python packages can cause timeouts during deployment
   - The application may still deploy successfully despite the timeout
   - Wait 5-10 minutes and check the application URL

2. **Authorization Errors**
   - Ensure you're logged into Azure with sufficient permissions
   - Check your Azure role assignments

3. **Missing Dependencies**
   - Ensure both Azure CLI and PowerShell Core are installed
   - Run `az --version` and `pwsh --version` to verify

4. **App Startup Failures**
   - Check application logs in Azure Portal
   - Use the `-DebugMode` flag to get detailed startup information
   - Verify all required environment variables are set

### Getting Help

If you encounter issues:

1. Check Azure App Service logs in the Azure Portal
2. Examine the deployment logs in the Azure Portal
3. Try running with `-DebugMode` for more detailed output
4. Consult the [FastAPI Azure deployment documentation](https://fastapi.tiangolo.com/deployment/azure-app-service/)

## File Structure

- `Deploy-Ship360ChatAPI.ps1` - Main PowerShell deployment script
- `ship360-sample.env` - Template for environment variables
- `deploy-ship360.sh` - Bash wrapper for the PowerShell script
- `Test-DeploymentScript.ps1` - Script to validate deployment without creating resources
- `deploy_considerations.md` - Additional deployment information and best practices