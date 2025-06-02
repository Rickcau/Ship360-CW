# Ship360 Chat API - New Deployment Script

This directory contains the new simplified deployment script (`new-deploy.ps1`) created to address issue #22.

## Overview

The `new-deploy.ps1` script combines working deployment logic with professional output handling to provide a streamlined deployment experience for the Ship360 Chat API to Azure Container Apps.

## Features

- **Professional Output**: Clean, formatted output with color-coded messages, emojis, and structured headers
- **Working Logic**: Simplified, reliable deployment process based on proven patterns
- **Multiple Commands**: Support for deploy, update, status, and help commands
- **Environment Configuration**: Automatic loading of environment variables from .env files
- **Error Handling**: Comprehensive error checking and user-friendly error messages
- **Pre-flight Checks**: Validates prerequisites before attempting deployment

## Usage

### Prerequisites

1. **Azure CLI**: Must be installed and accessible in PATH
   ```bash
   winget install Microsoft.AzureCLI
   ```

2. **Environment Variables**: Create a `.env` file in the repository root or in the `ship360-chat-api` directory with required Azure OpenAI and Ship360 API configuration.

3. **Azure Authentication**: Must be logged into Azure CLI
   ```bash
   az login
   ```

### Commands

Run the script from the repository root directory:

```powershell
# Show help and usage information
.\infrastructure\scripts\new-deploy.ps1 help

# Deploy new instance
.\infrastructure\scripts\new-deploy.ps1 deploy

# Deploy with custom resource group
.\infrastructure\scripts\new-deploy.ps1 deploy -ResourceGroup "rg-myapp-prod"

# Deploy to different Azure region  
.\infrastructure\scripts\new-deploy.ps1 deploy -Location "westus2"

# Update existing deployment
.\infrastructure\scripts\new-deploy.ps1 update

# Check deployment status
.\infrastructure\scripts\new-deploy.ps1 status
```

### Environment Variables

The script supports the following environment variables (with auto-generated defaults):

- `AZURE_RESOURCE_GROUP` - Resource group name
- `AZURE_LOCATION` - Azure region  
- `AZURE_ACR_NAME` - Container registry name
- `AZURE_CONTAINER_APP_ENV` - Container app environment name
- `AZURE_CONTAINER_APP_NAME` - Container app name
- `LOG_LEVEL` - Application log level
- `AZURE_OPENAI_API_KEY` - Azure OpenAI API key
- `AZURE_OPENAI_ENDPOINT` - Azure OpenAI endpoint
- `AZURE_OPENAI_API_VERSION` - Azure OpenAI API version
- `AZURE_OPENAI_CHAT_DEPLOYMENT_NAME` - Chat model deployment name
- `MASTER_AGENT_DEPLOYMENT` - Master agent deployment name
- `INTENT_AGENT_DEPLOYMENT` - Intent agent deployment name  
- `RATE_AGENT_DEPLOYMENT` - Rate agent deployment name
- `LABEL_AGENT_DEPLOYMENT` - Label agent deployment name
- `TRACKING_AGENT_DEPLOYMENT` - Tracking agent deployment name
- `SP360_TOKEN_URL` - Ship360 token URL
- `SP360_TOKEN_USERNAME` - Ship360 username
- `SP360_TOKEN_PASSWORD` - Ship360 password
- `SP360_RATE_SHOP_URL` - Ship360 rate shopping URL
- `SP360_SHIPMENTS_URL` - Ship360 shipments URL
- `SP360_TRACKING_URL` - Ship360 tracking URL

## Output Examples

### Help Command
```
============================================================
 Ship360 Chat API - New Deployment Script
============================================================

DESCRIPTION:
  Simplified deployment script with professional output handling
  Combines working logic with clean, formatted output

COMMANDS:
  deploy              Deploy new Ship360 Chat API to Azure Container Apps
  update              Update existing deployment with latest code
  status              Check status of deployed resources
  help                Show this help message
```

### Deploy Command
```
============================================================
 Starting Ship360 Chat API Deployment
============================================================

⚡ Performing pre-flight checks...
   └─ Azure CLI: Available
✅ Environment variables loaded from .env
✅ Already logged into Azure: user@example.com
✅ Pre-flight checks completed

============================================================
 Deployment Configuration
============================================================

ℹ️  Resource Group: rg-ship360-chat-api-abc
ℹ️  Location: eastus
ℹ️  ACR Name: acrship360chatabc
ℹ️  Container App Environment: ship360-chat-env-abc
ℹ️  Container App Name: ship360-chat-api-abc
ℹ️  Random Suffix: abc

⚡ Registering Azure resource providers...
✅ Resource providers registered

⚡ Creating resource group...
✅ Resource group 'rg-ship360-chat-api-abc' created
```

## Design Principles

1. **Simplicity**: Streamlined logic that focuses on core deployment functionality
2. **Professional Output**: Clear, structured output with consistent formatting
3. **Reliability**: Comprehensive error checking and graceful failure handling
4. **Flexibility**: Support for custom resource names and locations
5. **Usability**: Intuitive command structure and helpful documentation

## Related Files

- Original deployment script: `ship360-chat-api/deploy.ps1` (in features/bjake-deployment branch)
- APIM setup script: `ship360-chat-api/complete-apim-setup.ps1` (in features/bjake-deployment branch)