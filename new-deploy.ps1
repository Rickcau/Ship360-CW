# 5/20/2025 - RDC this is working as of 5/20/2025

# Resource group
az group create --name ship360-rg --location centralus

# App Service Plan
az appservice plan create --name ship360-plan --resource-group ship360-rg --sku B1 --is-linux

# Web App
az webapp create --name ship360-fastapi-app --resource-group ship360-rg --plan ship360-plan --runtime "PYTHON:3.12"

# zip up the files

Compress-Archive -Path app,requirements.txt,startup.txt -DestinationPath app.zip

Compress-Archive -Path app,requirements.txt,startup.txt,.env_sample,README.md,startup.sh -DestinationPath app.zip

# Deploy the zip
az webapp deployment source config-zip --resource-group ship360-rg --name ship360-fastapi-app --src app.zip