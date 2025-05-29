# Ship360 Chat API Deployment Guide

This guide provides comprehensive instructions for deploying the Ship360 Chat API to Azure using the provided deployment scripts.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Methods](#deployment-methods)
- [Detailed Deployment Steps](#detailed-deployment-steps)
- [Configuration Options](#configuration-options)
- [Post-Deployment](#post-deployment)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

## Prerequisites

Before deploying, ensure you have the following:

### 1. **Required Tools**
- **Azure CLI** (version 2.0 or higher)
  ```bash
  # Install Azure CLI
  # Windows
  winget install Microsoft.AzureCLI
  
  # macOS
  brew install azure-cli
  
  # Linux
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  ```

- **PowerShell** (for Windows deployment) or **Make** (for cross-platform)
- **Docker** (optional, for local testing)

### 2. **Azure Account**
- Active Azure subscription
- Appropriate permissions to create resources:
  - Resource Groups
  - Container Registries
  - Container Apps
  - API Management (if using APIM)

### 3. **Environment Configuration**
1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Configure all required environment variables in `.env`:
   ```env
   # Azure OpenAI Configuration
   AZURE_OPENAI_API_BASE=https://your-openai.openai.azure.com
   AZURE_OPENAI_API_KEY=your-api-key
   AZURE_OPENAI_DEPLOYMENT_NAME=your-deployment-name
   AZURE_OPENAI_API_VERSION=2024-02-15-preview
   AZURE_OPENAI_MODEL_NAME=gpt-4
   
   # Azure OpenAI Deployment Names
   AZURE_OPENAI_CHAT_DEPLOYMENT_NAME=gpt-4
   AZURE_OPENAI_35_DEPLOYMENT_NAME=gpt-35-turbo
   
   # Ship360 Configuration
   SHIP_360_CLIENT_ID=your-client-id
   SHIP_360_CLIENT_SECRET=your-client-secret
   SHIP_360_SUBSCRIPTION_KEY=your-subscription-key
   SHIP_360_BASE_URL=https://api.ship360.com
   
   # Azure AI Search (Optional)
   AZURE_AI_SEARCH_ENDPOINT=https://your-search.search.windows.net
   AZURE_AI_SEARCH_KEY=your-search-key
   AZURE_AI_SEARCH_INDEX_NAME=your-index-name
   ```

## Quick Start

### Option 1: Deploy Container App Only (Fastest)
```bash
# Using Make
make deploy-containerapp

# Using PowerShell
.\deploy.ps1 deploy-containerapp
```

### Option 2: Deploy with API Management (Production)
```bash
# Using Make
make deploy-with-apim

# Using PowerShell
.\deploy.ps1 deploy-with-apim
```

## Deployment Methods

### 1. **Using Make (Recommended for Linux/macOS)**

The Makefile provides a simple interface for all deployment operations:

```bash
# Full deployment with APIM
make deploy-with-apim

# Container Apps only
make deploy-containerapp

# Update existing deployment
make update-containerapp
```

### 2. **Using PowerShell (Recommended for Windows)**

PowerShell scripts provide detailed logging and error handling:

```powershell
# Full deployment with APIM
.\deploy.ps1 deploy-with-apim

# Container Apps only
.\deploy.ps1 deploy-containerapp

# Update existing deployment
.\deploy.ps1 update-containerapp
```

## Detailed Deployment Steps

### Step 1: Azure Login
```bash
# Login to Azure
az login

# Set subscription (if multiple)
az account set --subscription "Your-Subscription-Name"

# Verify correct subscription
az account show
```

### Step 2: Deploy Container App

#### Basic Deployment
```bash
make deploy-containerapp
```

This will:
1. Create a resource group with random suffix (e.g., `ship360-chat-rg-abc123`)
2. Create Azure Container Registry
3. Build and push Docker image
4. Create Container Apps environment
5. Deploy the application with auto-scaling (1-3 replicas)

#### Custom Resource Names
```bash
# Specify custom names
make deploy-containerapp RESOURCE_GROUP=my-custom-rg LOCATION=westus2

# Or with PowerShell
.\deploy.ps1 deploy-containerapp -ResourceGroup my-custom-rg -Location westus2
```

### Step 3: Deploy with API Management (Optional)

**Note:** API Management takes 30-45 minutes to provision.

```bash
# Start deployment
make deploy-with-apim

# Monitor status (in another terminal)
.\check-apim-status.ps1
```

#### Post-APIM Deployment Steps

Once APIM is provisioned, complete the setup:

```powershell
# Run full setup (imports API, configures restrictions)
.\complete-apim-setup.ps1 -FullSetup

# Or step by step:
.\complete-apim-setup.ps1 -ImportAPI
.\complete-apim-setup.ps1 -RestrictIPs
.\complete-apim-setup.ps1 -GetInfo
```

### Step 4: Verify Deployment

#### Get Application URLs
```bash
# Container App URL
make azure-url

# APIM URLs (if deployed)
make apim-url
```

#### Test the API
```bash
# Test Container App directly
make test-azure

# Test via APIM (requires subscription key)
curl -X POST "https://<apim-name>.azure-api.net/ship360-chat/api/chat" \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: <your-subscription-key>" \
  -d '{"message": "Hello", "thread_id": "test-thread"}'
```

## Configuration Options

### Scaling Configuration
```bash
# Scale replicas
make azure-scale MIN=2 MAX=10

# View current scale settings
az containerapp show --name <app-name> --resource-group <rg-name> --query "properties.template.scale"
```

### Environment Variables
Update environment variables without redeploying:
```bash
# Update single variable
az containerapp update --name <app-name> --resource-group <rg-name> \
  --set-env-vars "NEW_VAR=value"

# Update from .env file
make update-containerapp
```

### IP Restrictions
Restrict Container App to only accept traffic from APIM:
```bash
# Apply restrictions
make containerapp-restrict-ips

# Remove restrictions
az containerapp ingress access-restriction remove --name <app-name> \
  --resource-group <rg-name> --rule-name "AllowAPIMOnly"
```

## Post-Deployment

### 1. Monitor Application
```bash
# View logs
make azure-logs

# Stream logs
az containerapp logs show --name <app-name> --resource-group <rg-name> --follow

# Check metrics
az monitor metrics list --resource <container-app-id> \
  --metric "Requests" --interval PT1M
```

### 2. Get Deployment Information
```bash
# All deployment info
make azure-status

# APIM specific info
.\complete-apim-setup.ps1 -GetInfo
```

### 3. Update Application
```bash
# Rebuild and redeploy
make update-containerapp

# Just update environment variables
az containerapp update --name <app-name> --resource-group <rg-name> \
  --replace-env-vars
```

## Troubleshooting

### Common Issues

#### 1. **Deployment Fails**
```bash
# Check detailed logs
az containerapp logs show --name <app-name> --resource-group <rg-name> --tail 100

# Check revision status
az containerapp revision list --name <app-name> --resource-group <rg-name>
```

#### 2. **Environment Variables Not Loading**
- Verify `.env` file exists and is properly formatted
- Check for spaces around `=` in `.env` file
- Ensure no quotes in `.env` unless part of value

#### 3. **APIM Import Fails**
- Ensure `openapi.json` exists and is valid
- Verify APIM is fully provisioned (check with `.\check-apim-status.ps1`)
- Check APIM diagnostic logs

#### 4. **Container App Not Accessible**
- Verify ingress is enabled: `az containerapp ingress show`
- Check IP restrictions aren't blocking access
- Ensure correct port (8000) is configured

### Debug Commands
```bash
# Check Container App health
curl https://<app-name>.<region>.azurecontainerapps.io/health

# View environment configuration
az containerapp show --name <app-name> --resource-group <rg-name> \
  --query "properties.configuration.secrets"

# Check ACR image
az acr repository show-tags --name <registry-name> --repository ship360-chat-api
```

## Cleanup

### Remove All Resources
```bash
# With confirmation prompt
make azure-delete

# Force delete (no prompt)
az group delete --name <resource-group> --yes --no-wait
```

### Partial Cleanup
```bash
# Remove only Container App
az containerapp delete --name <app-name> --resource-group <rg-name> --yes

# Remove only APIM
az apim delete --name <apim-name> --resource-group <rg-name>
```

## Security Best Practices

1. **Never commit `.env` files** to version control
2. **Use Azure Key Vault** for production secrets
3. **Enable IP restrictions** when using APIM
4. **Regular security updates** for base images
5. **Monitor access logs** for suspicious activity