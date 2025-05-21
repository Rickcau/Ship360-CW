# Deploying Ship360-CW Chat API to Azure

This guide provides step-by-step instructions for deploying the Ship360-CW Chat API to Azure App Service.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed
- [Azure account](https://azure.microsoft.com/en-us/free/) with an active subscription
- Python 3.8+ installed locally
- Git installed

## Step 1: Prepare Your Application

### 1.1. Verify Application Structure

Ensure your application structure matches the expected FastAPI application structure:
- `app/` directory with `__init__.py`
- `main.py` at the root of the project
- `requirements.txt` with all dependencies

### 1.2. Create a Production-Ready Requirements File

Create a `requirements.txt` file in the `ship360-chat-api` directory if it doesn't exist already.

```
fastapi==0.103.1
uvicorn==0.23.2
python-dotenv==1.0.0
aiohttp==3.8.5
semantic-kernel==0.4.3.dev0
azure-search-documents==11.4.0
```

### 1.3. Create a Startup Command File

Create a new file called `startup.sh` in the `ship360-chat-api` directory:

```bash
#!/bin/bash
cd /home/site/wwwroot
gunicorn app.main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

Make it executable:
```bash
chmod +x startup.sh
```

### 1.4. Create an Azure App Service Configuration File

Create a file named `.azure/config.json` at the root of your project:

```json
{
  "appService.defaultWebAppToDeploy": "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP/providers/Microsoft.Web/sites/YOUR_APP_NAME",
  "appService.deploySubpath": "ship360-chat-api"
}
```

## Step 2: Log in to Azure and Set Up Resources

### 2.1. Log in to Azure

```bash
az login
```

### 2.2. Set Your Subscription

```bash
az account set --subscription "<your-subscription-name-or-id>"
```

### 2.3. Create a Resource Group

```bash
az group create --name ship360-rg --location centralus
```

### 2.4. Create an App Service Plan

```bash
az appservice plan create --name ship360-plan --resource-group ship360-rg --sku B1 --is-linux
```

> **Note:** If you encounter quota limitations, you can use a Free tier instead:
> ```bash
> az appservice plan create --name ship360-plan --resource-group ship360-rg --sku F1 --is-linux
> ```

### 2.5. Create a Web App

```bash
az webapp create --name ship360-chat-api --resource-group ship360-rg --plan ship360-plan --runtime "PYTHON:3.12"
```

## Step 3: Configure Application Settings

### 3.1. Set Environment Variables

Set all necessary environment variables from your `.env` file:

```bash
az webapp config appsettings set --name ship360-chat-api --resource-group ship360-rg --settings \
AZURE_OPENAI_ENDPOINT="<your-azure-openai-endpoint>" \
AZURE_OPENAI_API_KEY="<your-azure-openai-api-key>" \
AZURE_OPENAI_CHAT_DEPLOYMENT_NAME="gpt-4o" \
AZURE_OPENAI_API_VERSION="2024-12-01-preview" \
SP360_TOKEN_URL="<your-sp360-token-url>" \
SP360_TOKEN_USERNAME="<your-sp360-token-username>" \
SP360_TOKEN_PASSWORD="<your-sp360-token-password>" \
SP360_RATE_SHOP_URL="<your-sp360-rate-shop-url>" \
SP360_SHIPMENTS_URL="<your-sp360-shipments-url>" \
SP360_TRACKING_URL="<your-sp360-tracking-url>" \
SP360_PARTNER_ID="<your-sp360-partner-id>"
```

### 3.2. Configure Startup Command

```bash
az webapp config set --name ship360-chat-api --resource-group ship360-rg --startup-file "startup.sh"
```

## Step 4: Deploy Your Application

### 4.1. Deploy Using Local Git

First, configure local Git deployment:

```bash
az webapp deployment user set --user-name <username> --password <password>
```

Get the Git endpoint:

```bash
az webapp deployment source config-local-git --name ship360-chat-api --resource-group ship360-rg
```

Add the remote and push:

```bash
git remote add azure <git-endpoint-from-previous-command>
git add .
git commit -m "Initial deployment to Azure"
git push azure main
```

### 4.2. Alternative: Deploy Using ZIP Deployment

Package your application:

```bash
cd ship360-chat-api
zip -r ../ship360-deploy.zip .
```

Deploy the ZIP file:

```bash
az webapp deployment source config-zip --name ship360-chat-api --resource-group ship360-rg --src ../ship360-deploy.zip
```

## Step 5: Verify Your Deployment

### 5.1. Check Deployment Status

```bash
az webapp log tail --name ship360-chat-api --resource-group ship360-rg
```

### 5.2. Test Your API Endpoint

Your API will be available at:
```
https://ship360-chat-api.azurewebsites.net/api/chat/sync
```

## Step 6: Set Up Continuous Integration/Continuous Deployment (Optional)

### 6.1. Connect to GitHub

1. Go to your App Service in the Azure Portal.
2. Select "Deployment Center" from the left menu.
3. Select "GitHub" as the source.
4. Authenticate with GitHub and select your repository.
5. Configure build and deployment settings.
6. Save the configuration.

## Troubleshooting

### Application Not Starting

Check the application logs:

```bash
az webapp log tail --name ship360-chat-api --resource-group ship360-rg
```

### Missing Dependencies

If you encounter missing dependencies, update your requirements.txt and redeploy.

### Environment Variables

Verify all environment variables are set correctly:

```bash
az webapp config appsettings list --name ship360-chat-api --resource-group ship360-rg
```

### Scale Up If Needed

If your application needs more resources:

```bash
az appservice plan update --name ship360-plan --resource-group ship360-rg --sku S1
```

## Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/en-us/azure/app-service/)
- [Deploying FastAPI to Azure App Service](https://fastapi.tiangolo.com/deployment/azure-app-service/)
- [Managing App Service Plans](https://docs.microsoft.com/en-us/azure/app-service/app-service-plan-manage)
